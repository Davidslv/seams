// Per-page Open Graph images (1200x630) with the page title baked in,
// generated at build time by astro-og-canvas. Served at /seams/og/<id>.png
// and referenced per page by src/components/Head.astro.

import { OGImageRoute } from "astro-og-canvas";
import { getCollection } from "astro:content";

const entries = await getCollection("docs");
// The home page's id is "" (the site root); give it a real filename so its
// card is /og/index.png rather than /og/.png.
const pages = Object.fromEntries(
  entries.map((entry) => [entry.id || "index", entry.data]),
);

export const { getStaticPaths, GET } = await OGImageRoute({
  param: "routes",
  pages,
  getImageOptions: (_id, page) => ({
    title: page.title,
    description:
      page.description ??
      "A CLI framework that generates modular Rails engines.",
    bgGradient: [
      [11, 13, 16],
      [15, 23, 42],
    ],
    border: { color: [125, 211, 252], width: 12, side: "inline-start" },
    padding: 64,
    logo: undefined,
  }),
});
