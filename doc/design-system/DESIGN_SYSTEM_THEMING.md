# Design system — theming

Retheming the whole design system is a **token override** and nothing more. No
component, markup, or helper changes. This page documents the token surface, the
override path, the worked example, and how to author your own theme.

## Why a token override is enough

The token layer has three tiers (see [Foundations](DESIGN_SYSTEM_FOUNDATIONS.md)):

```
@theme  ──▶  :root aliases  ──▶  @layer components
(source)     (--ink, --accent…)   (.btn, .card… read ONLY the aliases)
```

No component rule names a literal colour or font — every one reads an alias, and
every alias resolves to an `@theme` value. So overriding `@theme` cascades
through the aliases into every component. That is the entire mechanism.

## The token surface you can override

All in the `@theme` block of `app/assets/tailwind/application.css`:

| Tokens | Controls |
|--------|----------|
| `--color-paper`, `--color-paper-raised`, `--color-card` | surfaces |
| `--color-ink`, `--color-ink-2`, `--color-muted`, `--color-faint` | text |
| `--color-line`, `--color-line-2` | borders / separators |
| `--color-accent`, `--color-accent-deep` | the single accent |
| `--color-ready`/`-bg`/`-line`, `--color-progress`/…, `--color-alert`/… | states |
| `--font-display`, `--font-sans`, `--font-mono` | the type pairing |

You can also override an individual `:root` alias for finer control — e.g. the
quire theme pins the focus ring to ink with `--focus: var(--color-ink);` rather
than the accent.

> Keep your overrides WCAG-AA. A CI spec checks the *default* tokens; your own
> palette is yours to verify (the contrast method in the design generator spec
> is a good reference).

## The worked example — the quire theme

The generator ships the **quire** theme (warm paper / garnet / Spectral + IBM
Plex) at `app/assets/tailwind/themes/_quire.css`. It overrides only the `@theme`
tokens (garnet replaces the indigo accent; Spectral + IBM Plex replace the type
pairing) and one alias (the focus ring). It is the proof that retheme =
override.

Apply it with **one line** in `application.css`, after the `seams:design tokens`
block (so it wins):

```css
@import "themes/quire";
```

Rebuild Tailwind (`bin/rails tailwindcss:build`) and the whole app — every
`ui_*` component, the form fields, the `--shell` layout — reskins to garnet +
Spectral. Delete the line to return to the neutral default.

> The quire theme names Spectral / IBM Plex but does not self-host them. Add the
> faces to your bundle (or load them in the layout `<head>`); the token is the
> single switch.

## Author your own theme

1. Copy `themes/_quire.css` to `themes/_yourbrand.css`.
2. Override the `@theme` tokens (and any `:root` alias you want to pin).
3. `@import "themes/yourbrand";` in `application.css`, after the default tokens.
4. `bin/rails tailwindcss:build`.

That is the whole job. No component touches a literal value, so there is nothing
else to change.
