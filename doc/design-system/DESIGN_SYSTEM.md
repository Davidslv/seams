# The seams design system (`bin/seams design`)

A canonical, opt-out seams engine that ships a complete, themeable design
system into a host: a Tailwind v4 `@theme` token layer, ~31 strict-locals
`ui_*` components with auto-wired helpers, a `Design::FormBuilder`, a living
gallery, and an opt-in app shell. A host generated from seams looks like a
product on first boot instead of bare markup.

This is a faithful extraction of quire-saas's proven "Compositor". See
`proposals/design_system_engine.md` for the thinking and the decisions.

## Generate

```bash
bin/seams design            # the component system only
bin/seams design --shell    # + a default application layout + starter dashboard
```

After generating: `bundle install`, then `bin/rails tailwindcss:build`.

## The doc pages

| Page | Covers |
|------|--------|
| [Foundations](DESIGN_SYSTEM_FOUNDATIONS.md) | The token layer: colour, type, space, radius, shadow, motion, the single-source model |
| [Components](DESIGN_SYSTEM_COMPONENTS.md) | The `ui_*` API, the component catalogue, the living gallery, the `design:component` generator |
| [Forms](DESIGN_SYSTEM_FORMS.md) | `Design::FormBuilder`, the field components, baked-in field accessibility |
| [Accessibility](DESIGN_SYSTEM_ACCESSIBILITY.md) | The baseline every component carries: roles, focus, contrast, the gallery as a check |
| [Theming](DESIGN_SYSTEM_THEMING.md) | The token surface, how to override it, the example quire theme, authoring a theme |

## The shape of the engine

- **Non-isolated by design** (D4). Unlike every other canonical seams engine,
  the design engine is *not* `isolate_namespace`d: its partials live in the
  host's view paths and `Design::UiHelper` is mixed into
  `ActionController::Base`, so a component renders anywhere — in the host's
  views and in every other engine's views — with no ceremony. Ruby constants
  live under `Design::`; the view + helper surface is `ui`.
- **Tailwind v4 is a hard dependency** (D2). The token layer is Tailwind-native
  `@theme`. The generator injects `tailwindcss-rails` and writes the tokens into
  the host's `app/assets/tailwind/application.css`.
- **Partials + auto-wire, not ViewComponent** (D3). Each component is a
  strict-locals ERB partial with a companion preview; the preview is what makes
  the `ui_<name>` helper and the gallery entry exist.

## Extend, override, retheme

- **Extend:** `rails g design:component <name>` — adds a partial + preview; the
  helper and gallery entry appear automatically.
- **Override:** `bin/seams resolve --eject design/<path>` — the host owns the
  file and the generator skips it on regenerate.
- **Retheme:** override the `@theme` tokens. The whole app reskins; nothing else
  changes. The example **quire** theme ships as the worked proof.
