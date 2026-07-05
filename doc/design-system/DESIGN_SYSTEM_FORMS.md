# Design system — forms

The generator sets `Design::FormBuilder` as the host's default form builder, so
every `form_with` / `form_for` gets the `f.ui_*` field helpers with no
`builder:` argument. The builder only **adds** `ui_*` methods — the standard
`f.text_field` / `f.select` / `f.submit` are untouched — so it is safe as the
app-wide default.

```erb
<%= form_with model: @book do |f| %>
  <%= f.ui_text_field :title, label: "Book title", hint: "Shown on the cover" %>
  <%= f.ui_text_area  :notes, label: "Notes", hint: "Optional" %>
  <%= f.ui_select     :marketplace, %w[UK US], label: "Primary marketplace" %>
  <%= f.ui_submit "Create" %>
<% end %>
```

## The field helpers

| Helper | Renders |
|--------|---------|
| `f.ui_text_field` (+ `_email_`, `_url_`, `_tel_`, `_number_`, `_password_`) | the `ui/field` wrapper around a typed input |
| `f.ui_text_area` | a labelled textarea |
| `f.ui_select` | a labelled select |
| `f.ui_submit` | a primary button (`variant:` for others) |

Each helper wires the form object's name, value, and validation error into the
field markup, so the accessibility is baked in and cannot drift. Arbitrary HTML
options — including `data-*` for Stimulus — pass straight through, so Hotwire
keeps working.

## Baked-in field accessibility

The `ui/field` partial owns the wiring, not the builder:

- the `<label>` is associated with the control via `for` / `id`;
- on error, the control gets `aria-invalid="true"`;
- the hint / error text gets an id and the control gets `aria-describedby`
  pointing at it, so assistive tech announces the message with the field.

Because this lives in one partial, every field — built by the builder or by
hand — gets the same treatment.

## The form components

Beyond the field wrapper, the form set ships `checkbox`, `radio`, `switch`
(`role="switch"`), and `input_group` (an input with a prefix/suffix affix). Each
is a `ui_*` component with a preview, so it appears in `/design/guide`.
