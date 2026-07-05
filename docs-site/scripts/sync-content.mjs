// Sync the repository's Markdown docs into the Starlight content
// collection at build time. The docs are NOT moved or duplicated in
// git — this script copies them into src/content/docs/ (gitignored)
// just before `astro build`, injecting the frontmatter Starlight needs
// and rewriting links so they keep resolving.
//
// The repo organises doc/ into Diátaxis folders (tutorials/, how-to/,
// reference/, design-system/, explanation/); the site FLATTENS them so
// every published URL predates the folders and never changes. Links are
// resolved per source file, so cross-folder references land on the
// right flattened page.
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

// doc/ subdirectories that hold public pages (flattened on the site).
const CONTENT_DIRS = ["tutorials", "how-to", "reference", "design-system", "explanation"];

// Internal/working docs that don't belong on the public site.
// doc/internal/ is skipped wholesale; this covers strays at other levels.
const EXCLUDE = new Set(["REVIEW_2026_05_08.md"]);

// Anything living outside doc/ is linked on GitHub.
const GH_BLOB = "https://github.com/Davidslv/seams/blob/main";

// Must match `base` in astro.config.mjs. Starlight's page slug is the
// content filename lowercased (INSERTION_POINTS.md -> insertion_points).
const BASE = "/seams";

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

// Rewrite every relative link so it resolves on the flattened site:
//  - a link to another doc page (any doc/ subfolder) -> the final page
//    URL (/seams/<slug>/). Astro does NOT resolve `./FOO.md` links in
//    content — they used to ship raw and 404 — so emit real URLs.
//  - a link to an ADR -> /seams/adr/<slug>/ (adr keeps its subdirectory)
//  - a link that leaves doc/ (../../CHANGELOG.md, ../../lib/...) -> GitHub
// srcDirRel is the source file's directory relative to the repo root
// (e.g. "doc/reference").
function rewriteLinks(markdown, srcDirRel) {
  const LINK = /\]\((?!https?:|mailto:|#|\/)([^)\s]+?)(#[^)]*)?\)/g;
  return markdown.replace(LINK, (whole, target, frag = "") => {
    // A handful of docs use repo-root-style targets (doc/..., lib/...).
    const repoRel = target.startsWith("doc/") || target.startsWith("lib/") || target.startsWith("spec/")
      ? path.posix.normalize(target)
      : path.posix.normalize(path.posix.join(srcDirRel, target));
    if (repoRel.startsWith("..")) return whole; // escapes the repo; leave it
    if (!repoRel.startsWith("doc/") || !repoRel.endsWith(".md")) {
      return `](${GH_BLOB}/${repoRel}${frag})`;
    }
    const slug = path.posix.basename(repoRel, ".md").toLowerCase();
    const dir = repoRel.startsWith("doc/adr/") ? "adr/" : "";
    return `](${BASE}/${dir}${slug}/${frag})`;
  });
}

async function emit(srcPath, destName, fallbackTitle) {
  const raw = await fs.readFile(srcPath, "utf8");
  const title = titleFrom(raw, fallbackTitle);
  const srcDirRel = path
    .relative(repoRoot, path.dirname(srcPath))
    .split(path.sep)
    .join("/");
  const body = rewriteLinks(stripFirstH1(raw), srcDirRel);
  const dest = path.join(outDir, destName);
  await fs.mkdir(path.dirname(dest), { recursive: true });
  await fs.writeFile(dest, frontmatter(title) + body);
}

async function syncDir(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true }).catch(() => []);
  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    if (EXCLUDE.has(entry.name)) continue;
    // Flatten: the page keeps its filename (and therefore its URL),
    // whatever folder it lives in.
    await emit(path.join(dir, entry.name), entry.name, entry.name.replace(/\.md$/, ""));
  }
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

  // Top-level strays (doc/README.md, anything not yet folderised) plus
  // the Diátaxis content folders, all flattened to top-level pages.
  await syncDir(docDir);
  for (const sub of CONTENT_DIRS) {
    await syncDir(path.join(docDir, sub));
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
