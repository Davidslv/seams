# Design system — components

A component is a strict-locals ERB partial under `app/views/ui/_<name>.html.erb`
with a companion preview under `app/views/ui/previews/_<name>.html.erb`. The
preview is what makes the component **public**: the auto-wire derives the
`ui_<name>` helper from it, and the living gallery lists it.

## The `ui_*` API

Every component is callable as a flat helper anywhere — the host's views and
every other engine's views — because the engine is non-isolated.

```erb
<%= ui_button(variant: :primary) { "Save" } %>
<%= ui_tag(label: "Built", status: :ready) %>
<%= ui_card do %>
  <h3 class="h3">Output formats</h3>
  <p class="small muted">Files are generated on every change.</p>
<% end %>
```

Strict locals mean each partial declares its contract (`<%# locals: (...) %>`);
calling it with the wrong locals raises, so the contract cannot silently drift.
A contract test renders every component from its preview in CI.

## The catalogue

| Group | Components |
|-------|-----------|
| Actions & status | `button`, `tag`, `banner`, `toast`, `note` |
| Data display | `card`, `data_table`, `chapter_row`, `build_row`, `counter`, `meter`, `kbd` |
| Navigation | `breadcrumb`, `pagination`, `menu`, `segmented`, `stepper`, `toolbar`, `outline` |
| Overlays | `dialog`, `drawer`, `popover`, `savestate` |
| Primitives & icons | `icon`, `icon_sprite`, `panel`, `diff`, `empty` |
| Forms | `field`, `checkbox`, `radio`, `switch`, `input_group` (see [Forms](DESIGN_SYSTEM_FORMS.md)) |

## The living gallery (`/design/guide`)

A dev/test-only page that renders **every** component from its real preview, so
the docs cannot drift from the code. It is guarded twice — drawn inside an
`if Rails.env.local?` block in the host routes, and `head :not_found` outside
`Rails.env.local?` in the controller — so it never reaches production.

## Add a component

```bash
rails g design:component badge
```

This writes:

- `app/views/ui/_badge.html.erb` — a strict-locals partial stub.
- `app/views/ui/previews/_badge.html.erb` — a preview calling `ui_badge`.

The preview registers the component: `ui_badge` becomes callable and `/design/guide`
lists it on the next reload. No registration step, no restart.

## Icons

Icons are a sprite (`ui/icon_sprite`, rendered once near the top of `<body>`)
plus `ui_icon(:name)`, which references a symbol by fragment — no external
request. The sprite ships a line-icon set on a 20px grid (`search`, `settings`,
`bell`, `plus`, `trash`, chevrons, `check`, `close`, `warning`, `info`,
`upload`, `download`, `edit`, `eye`).
