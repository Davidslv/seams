# Seams docs site

An [Astro Starlight](https://starlight.astro.build/) site that publishes
the Seams documentation to GitHub Pages.

**The docs are not stored here.** `scripts/sync-content.mjs` copies
`../doc/*.md`, `../doc/adr/*.md`, and `../README.md` into
`src/content/docs/` (gitignored) at build time, injecting the
frontmatter Starlight needs and rewriting the few links that point
outside `doc/`. Edit the real files under `doc/`; this site rebuilds
from them.

## Local development

```bash
cd docs-site
npm install
npm run dev      # runs the sync, then serves at http://localhost:4321/seams
```

`npm run build` produces a static site in `dist/`. CI additionally
generates the YARD API reference into `dist/api` and deploys the lot to
Pages (see `.github/workflows/docs-site.yml`).

## Why a `base` of `/seams`

The site is served from `https://davidslv.github.io/seams/` (a project
Pages site), so `astro.config.mjs` sets `base: "/seams"`.
