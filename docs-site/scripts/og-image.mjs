// Generate the static social-share card (1200x630) and the
// apple-touch-icon (180x180) into public/, from inline SVG, using sharp.
// Run via `npm run assets` (committed output, so CI doesn't need to
// regenerate). og:image must be an absolute 1200x630 PNG to render on
// Facebook / LinkedIn / X / Slack / iMessage.

import sharp from "sharp";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, "..", "public");

const BG = "#0b0d10";
const FG = "#f5f0e6";
const ACCENT = "#7dd3fc";

const ogSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="${BG}"/>
  <rect x="0" y="0" width="1200" height="8" fill="${ACCENT}"/>
  <g font-family="ui-sans-serif, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif">
    <text x="90" y="250" fill="${FG}" font-size="120" font-weight="800" letter-spacing="-3">Seams</text>
    <text x="92" y="330" fill="${ACCENT}" font-size="40" font-weight="600">A CLI framework that generates modular Rails engines.</text>
    <text x="92" y="470" fill="${FG}" font-size="30" opacity="0.75">Microservice boundaries. One Rails app. No HTTP between services.</text>
    <text x="92" y="560" fill="${FG}" font-size="26" opacity="0.55">davidslv.uk/seams</text>
  </g>
</svg>`;

// A simple square mark for the touch icon, opaque (iOS ignores transparency).
const iconSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180" viewBox="0 0 180 180">
  <rect width="180" height="180" rx="36" fill="${BG}"/>
  <text x="90" y="124" fill="${ACCENT}" font-size="110" font-weight="800" text-anchor="middle"
        font-family="ui-sans-serif, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif">S</text>
</svg>`;

async function run() {
  await sharp(Buffer.from(ogSvg)).png().toFile(path.join(publicDir, "og.png"));
  await sharp(Buffer.from(iconSvg)).png().toFile(path.join(publicDir, "apple-touch-icon.png"));
  console.log("og-image: wrote public/og.png (1200x630) and public/apple-touch-icon.png (180x180)");
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
