// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import { visit } from "unist-util-visit";

// Live at https://davidslv.uk/seams/ (custom domain on GitHub Pages).
// `site` drives canonical URLs, og:url, and the sitemap, so it must be
// the real serving origin — not the github.io fallback.
const SITE = "https://davidslv.uk";
const BASE = "/seams";
const ORIGIN = `${SITE}${BASE}`;
const OG_IMAGE = `${ORIGIN}/og.png`;
// >= 100 chars: short descriptions trip the LinkedIn Post Inspector
// warning and make a weak meta description / og:description.
const DESCRIPTION =
  "Seams generates modular Rails engines you own — clear boundaries, independent " +
  "tests, and team autonomy, without the operational cost of microservices. " +
  "One Rails app, clear seams.";

// Render ```mermaid fenced code blocks. Convert them to <pre class="mermaid">
// before Expressive Code sees them; the client script (in `head`) loads
// mermaid and renders them in the browser. HTML-escape the source so the
// raw markup survives, then mermaid reads it back via textContent.
function remarkMermaid() {
  return (tree) => {
    visit(tree, "code", (node) => {
      if (node.lang !== "mermaid") return;
      const escaped = node.value
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
      node.type = "html";
      node.value = `<pre class="mermaid not-content">${escaped}</pre>`;
    });
  };
}

const mermaidClientScript = `
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
const theme = document.documentElement.dataset.theme === "light" ? "default" : "dark";
mermaid.initialize({ startOnLoad: false, theme, securityLevel: "strict" });
const render = () => { try { mermaid.run({ querySelector: "pre.mermaid:not([data-processed])" }); } catch (e) { console.error(e); } };
if (document.readyState !== "loading") render();
else document.addEventListener("DOMContentLoaded", render);
document.addEventListener("astro:after-swap", render);
`;

const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Person",
      "@id": `${SITE}/#person`,
      name: "David Silva",
      url: `${SITE}/`,
      sameAs: ["https://github.com/Davidslv"],
    },
    {
      "@type": "WebSite",
      "@id": `${ORIGIN}/#website`,
      url: `${ORIGIN}/`,
      name: "Seams",
      description: DESCRIPTION,
      publisher: { "@id": `${SITE}/#person` },
      inLanguage: "en",
    },
    {
      "@type": "SoftwareSourceCode",
      "@id": `${ORIGIN}/#software`,
      name: "Seams",
      description: DESCRIPTION,
      url: `${ORIGIN}/`,
      codeRepository: "https://github.com/Davidslv/seams",
      programmingLanguage: "Ruby",
      runtimePlatform: "Ruby on Rails",
      author: { "@id": `${SITE}/#person` },
      image: OG_IMAGE,
      license: "https://opensource.org/licenses/MIT",
    },
  ],
};

export default defineConfig({
  site: SITE,
  base: BASE,
  trailingSlash: "always",
  markdown: {
    remarkPlugins: [remarkMermaid],
  },
  integrations: [
    starlight({
      title: "Seams",
      description: DESCRIPTION,
      customCss: ["./src/styles/terminal.css"],
      social: [
        { icon: "github", label: "GitHub", href: "https://github.com/Davidslv/seams" },
      ],
      // Per-page og:image / twitter:image are set by the custom Head
      // component (it points at the generated card for each page); the
      // global head only carries what's the same on every page.
      components: {
        Head: "./src/components/Head.astro",
      },
      head: [
        { tag: "meta", attrs: { property: "og:locale", content: "en_GB" } },
        { tag: "link", attrs: { rel: "apple-touch-icon", href: `${BASE}/apple-touch-icon.png` } },
        { tag: "meta", attrs: { name: "theme-color", content: "#0b0d10" } },
        { tag: "script", attrs: { type: "application/ld+json" }, content: JSON.stringify(jsonLd) },
        { tag: "script", attrs: { type: "module" }, content: mermaidClientScript },
      ],
      sidebar: [
        {
          label: "Tutorials",
          items: [
            { label: "First engine in 10 minutes", slug: "tutorial" },
            { label: "Getting started", slug: "getting_started" },
          ],
        },
        {
          label: "How-to guides",
          items: [
            { label: "Add an engine", slug: "adding_an_engine" },
            { label: "Remove an engine", slug: "removing_an_engine" },
            { label: "Write an adapter", slug: "writing_an_adapter" },
            { label: "Write a follow-up generator", slug: "writing_follow_up_generators" },
            { label: "Deploy", slug: "deploying" },
            { label: "Upgrade from Wave 8", slug: "upgrading_from_wave_8" },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "API reference (rubydoc.info)", link: "https://rubydoc.info/gems/seams", attrs: { target: "_blank" } },
            { label: "Engine catalogue", slug: "engine_catalogue" },
            { label: "Current attributes", slug: "current_attributes" },
            { label: "Permissions", slug: "permissions" },
            { label: "Insertion points", slug: "insertion_points" },
            { label: "Insertion points catalogue", slug: "insertion_points_catalogue" },
            { label: "Observability", slug: "observability" },
            { label: "Testing", slug: "testing" },
          ],
        },
        {
          label: "Design system",
          items: [
            { label: "Overview", slug: "design_system" },
            { label: "Foundations", slug: "design_system_foundations" },
            { label: "Components", slug: "design_system_components" },
            { label: "Forms", slug: "design_system_forms" },
            { label: "Theming", slug: "design_system_theming" },
            { label: "Accessibility", slug: "design_system_accessibility" },
          ],
        },
        {
          label: "Explanation",
          items: [
            { label: "Architecture overview", slug: "architecture" },
            { label: "Architecture (Wave 9)", slug: "architecture_wave_9" },
            { label: "Architecture (Wave 10)", slug: "architecture_wave_10" },
            { label: "Architecture (Wave 11 — admin)", slug: "architecture_wave_11" },
            { label: "PII & GDPR (Wave 11)", slug: "wave_11_pii_gdpr" },
          ],
        },
        {
          label: "Decisions (ADRs)",
          items: [{ autogenerate: { directory: "adr" } }],
        },
      ],
    }),
  ],
});
