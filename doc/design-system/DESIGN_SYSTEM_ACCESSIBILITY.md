# Design system — accessibility

Accessibility is a baseline baked into the components and tokens, not a layer a
host adds afterwards.

## Contrast (WCAG-AA)

Every text token clears WCAG-AA on the surfaces it sits on:

- `--color-ink`, `--color-ink-2`, `--color-muted` clear **AA (4.5:1)** on
  `paper`, `paper-raised`, and `card`.
- `--color-faint` is decorative-only (IDs, separators, placeholder hints) and is
  held to **AA-large (3:1)**.
- Each state foreground (`ready`, `progress`, `alert`) clears AA on its own
  tinted background; the accent reads both as text on paper and as the label of
  an accent fill.

A spec parses the shipped token file and computes contrast, so a future palette
edit that breaks AA fails CI.

## Roles and ARIA, per component

The components carry their semantics so the host does not have to remember them:

- **Navigation:** `breadcrumb` is a `nav[aria-label]` trail with
  `aria-current="page"`; `pagination` mirrors it; `menu` is `role="menu"` of
  `role="menuitem"`; `segmented` is a group of `aria-pressed` toggles; `stepper`
  is an ordered list with `aria-current="step"`; `outline` is a `nav` with
  `aria-current`.
- **Overlays:** `dialog` is a native `<dialog aria-labelledby>` with a labelled
  close button; `drawer` is an `<aside aria-label>` landmark; `savestate` is a
  `role="status"` live region.
- **Feedback:** `banner` / `toast` announce via `role="status"` (or `alert` for
  the alert tone); the `--shell` flash banners use `status` for notices and
  `alert` for alerts.
- **Forms:** label association, `aria-invalid`, `aria-describedby` — see
  [Forms](DESIGN_SYSTEM_FORMS.md).
- **Icons:** decorative icons are `aria-hidden`; glyph-only meaning (e.g. the
  diff `+`/`-`) is given an `aria-label` so the glyph alone is not load-bearing.

## Focus and keyboard

- A visible focus ring on every interactive element via a `:focus-visible`
  outline in the base layer, tuned by `--focus`.
- A skip link (`.skip`) to `#main`, shipped in the `--shell` layout.
- Animations honour `prefers-reduced-motion` where components animate.

## The gallery as a check

`/design/guide` renders every component from its real preview, so it doubles as
a manual accessibility surface — run an axe pass or a screen reader over it to
exercise the whole library at once.
