// Sync the repository's Markdown docs into the Starlight content
// collection at build time. The docs are NOT moved or duplicated in
// git — this script copies them into src/content/docs/ (gitignored)
// just before `astro build`, injecting the frontmatter Starlight needs
// and rewriting the few links that point outside doc/.
//
// Run automatically by `npm run dev` / `npm run build` (see the
// pre* scripts in package.json).

import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..", "..");
const docDir = path.join(repoRoot, "doc");
const outDir = path.join(__dirname, "..", "src", "content", "docs");

// Internal/working docs that don't belong on the public site.
const EXCLUDE = new Set([
  "SEAMS-NEW-HANDOFF.md",
  "REVIEW_2026_05_08.md",
]);

// Root-level files that live outside doc/ — link to them on GitHub.
const GH_BLOB = "https://github.com/Davidslv/seams/blob/main";
const ROOT_FILES = [
  "CONTRIBUTING.md",
  "SECURITY.md",
  "CODE_OF_CONDUCT.md",
  "CHANGELOG.md",
  "RELEASING.md",
  "LICENSE",
];

function titleFrom(markdown, fallback) {
  const m = markdown.match(/^#\s+(.+?)\s*$/m);
  return (m ? m[1] : fallback).replace(/[`*_]/g, "");
}

// Strip the first H1 (Starlight renders the frontmatter title as the
// page heading; keeping the body H1 would duplicate it).
function stripFirstH1(markdown) {
  return markdown.replace(/^#\s+.+?\r?\n+/m, "");
}

function yamlEscape(s) {
  return s.replace(/"/g, '\\"');
}

function frontmatter(title) {
  return `---\ntitle: "${yamlEscape(title)}"\n---\n\n`;
}

// Rewrite links that would 404 on the site:
//  - ../FOO or FOO at repo root (LICENSE, CONTRIBUTING, ...) -> GitHub blob URL
//  - doc/FOO.md (used by README) -> ./FOO.md
//  - bare relative FOO.md -> ./FOO.md so Astro resolves it to the page URL
//    (Astro only auto-resolves Markdown links that start with ./ or ../).
function rewriteLinks(markdown) {
  let out = markdown;
  for (const f of ROOT_FILES) {
    out = out.replaceAll(`](../${f})`, `](${GH_BLOB}/${f})`);
    out = out.replaceAll(`](${f})`, `](${GH_BLOB}/${f})`);
  }
  // README points into doc/; on the site those pages are siblings.
  out = out.replaceAll("](doc/", "](./");
  // Prefix bare relative .md links (no scheme, not already ./ ../ / #) so
  // Astro rewrites them to the built page URL and they stop 404-ing.
  out = out.replace(
    /\]\((?!https?:|\/|\.\/|\.\.\/|#|mailto:)([^)\s]+\.md)(#[^)]*)?\)/g,
    "](./$1$2)",
  );
  return out;
}

async function emit(srcPath, destName, fallbackTitle) {
  const raw = await fs.readFile(srcPath, "utf8");
  const title = titleFrom(raw, fallbackTitle);
  const body = rewriteLinks(stripFirstH1(raw));
  const dest = path.join(outDir, destName);
  await fs.mkdir(path.dirname(dest), { recursive: true });
  await fs.writeFile(dest, frontmatter(title) + body);
}

async function run() {
  await fs.rm(outDir, { recursive: true, force: true });
  await fs.mkdir(outDir, { recursive: true });

  // The home page is an authored Starlight splash (hero + cards), copied
  // verbatim — it already carries its own frontmatter and MDX components.
  // (The README stays GitHub-facing; it is no longer the site home page.)
  await fs.copyFile(
    path.join(__dirname, "..", "home.mdx"),
    path.join(outDir, "index.mdx"),
  );

  // Every top-level doc, preserving filename case so relative .md links
  // between docs keep resolving.
  for (const entry of await fs.readdir(docDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    if (EXCLUDE.has(entry.name)) continue;
    await emit(path.join(docDir, entry.name), entry.name, entry.name.replace(/\.md$/, ""));
  }

  // The ADR log (doc/adr/*.md) under an adr/ subdir, if present.
  const adrDir = path.join(docDir, "adr");
  const adrEntries = await fs.readdir(adrDir, { withFileTypes: true }).catch(() => []);
  for (const entry of adrEntries) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    await emit(path.join(adrDir, entry.name), path.join("adr", entry.name), entry.name.replace(/\.md$/, ""));
  }

  console.log("sync-content: docs written to src/content/docs/");
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
