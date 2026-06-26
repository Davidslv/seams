# Design system — foundations (the token layer)

The foundations are a single CSS file: the `@theme` token block the generator
writes into the host's `app/assets/tailwind/application.css`. It is the **single
source** every component reads. Retheme the whole system by overriding it;
nothing else changes (see [Theming](DESIGN_SYSTEM_THEMING.md)).

## The three layers

```css
@theme { … }   /* 1. The source: palette + type tokens. Also generates Tailwind
                     utilities (bg-paper, text-accent, font-display, …). */
:root  { … }   /* 2. Short aliases (--ink, --accent, --s-4 …) the component
                     layer reads, plus the scale tokens (type, space, radius,
                     shadow, motion, layout, z-index, breakpoints). */
@layer base       { … }  /* 3a. Selection, focus ring, skip link. */
@layer components { … }  /* 3b. The .btn / .card / .field / … rules every ui_*
                               component renders. Reads ONLY the aliases — no
                               literal colour or font — so a token override
                               reskins every component. */
```

A component never names a literal colour or font; it reads `var(--ink)`,
`var(--accent)`, `var(--s-4)`. The aliases resolve to `@theme` values. Override
`@theme`, the aliases follow, every component follows.

## Colour

Neutral default: refined paper/ink surfaces, a single restrained indigo accent,
and the state colours. Each text token clears **WCAG-AA** on the surfaces it sits
on (a CI test parses the token file and computes contrast).

| Group | Tokens |
|-------|--------|
| Surfaces | `--color-paper`, `--color-paper-raised`, `--color-card` |
| Text | `--color-ink`, `--color-ink-2`, `--color-muted`, `--color-faint` (faint is decorative / AA-large) |
| Lines | `--color-line`, `--color-line-2` |
| Accent | `--color-accent`, `--color-accent-deep` |
| States | `--color-ready` / `-bg` / `-line`, `--color-progress` / …, `--color-alert` / … |

## Type

| Token | Role |
|-------|------|
| `--font-display` | Headings / display |
| `--font-sans` | UI / body |
| `--font-mono` | Data / code / IDs |

The neutral default names Inter first but does **not** self-host it — it
degrades to the system sans stack, so the default boots with zero web-font
requests. Host a face (or a pairing) and it takes over; the token is the switch.

Type scale tokens: `--t-display-xl`, `--t-display`, `--t-h1`…`--t-h3`,
`--t-body`, `--t-sm`, `--t-cap`. The type-role helper classes (`.display`,
`.h1`, `.lede`, `.small`, `.muted`, `.mono`) live in the component layer.

## Space, radius, shadow, motion, layout

- **Space:** `--s-1` (4px) … `--s-9` (96px). Layout helpers: `.shell`, `.stack`,
  `.row`, `.grid` / `.grid-2` / `.grid-3` / `.grid-auto`, `.section`.
- **Radius:** `--r-sm`, `--r`, `--r-lg`, `--r-pill`.
- **Shadow:** `--shadow-sm`, `--shadow`, `--shadow-pop`.
- **Motion:** `--ease`, `--fast` (120ms), `--med` (190ms). Components honour
  `prefers-reduced-motion` where they animate.
- **Layout:** `--measure` (text measure), `--shell-max` (content max width),
  the `--z-*` stack, the `--bp-*` breakpoints.
