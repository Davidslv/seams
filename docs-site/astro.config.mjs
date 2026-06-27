// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// Project site on GitHub Pages: https://davidslv.github.io/seams/
export default defineConfig({
  site: "https://davidslv.github.io",
  base: "/seams",
  integrations: [
    starlight({
      title: "Seams",
      description: "A CLI framework that generates modular Rails engines.",
      social: [
        { icon: "github", label: "GitHub", href: "https://github.com/Davidslv/seams" },
      ],
      // Content is synced from ../doc and ../README.md by
      // scripts/sync-content.mjs (npm run sync). Sidebar is grouped by
      // Diátaxis quadrant, mirroring doc/README.md.
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
