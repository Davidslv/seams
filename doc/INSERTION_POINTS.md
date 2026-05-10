# Insertion points — format spec

Wave 10 introduces **insertion points**: structured ASCII comment
markers in generated files that follow-up generators target by stable
name to splice new code in, idempotently, without re-templating the
whole file.

This document is the contract between three roles:

- **Engine generators** (Phase 2A retrofit) place markers exactly once
  in the templates they emit.
- **Follow-up generators** (Phase 2C and onward) splice content
  after — never instead of — those markers, via the
  `Seams::Generators::Splicer` module.
- **Hosts** read the markers (and the catalogue) to know which
  extension points are public contract and which lines are framework
  internals.

The catalogue of every marker the canonical engines ship lives in
[`INSERTION_POINTS_CATALOGUE.md`](INSERTION_POINTS_CATALOGUE.md). This
document specifies the *format* the catalogue draws from.

## Marker format

A marker is a single Ruby comment on its own line:

```ruby
# seams:insertion-point <engine>.<area>.<scope>
```

Three fixed parts, separated by single dots:

| Part | Examples | Rule |
|---|---|---|
| `<engine>` | `auth`, `accounts`, `notifications` | The engine that owns this file. Always lowercase, never the camelcase module name. |
| `<area>` | `engine`, `routes`, `configuration`, `notifiable` | The file or concept the marker lives in. Most files map onto a single area; a few (e.g. routes with multiple resource sections) carry several. |
| `<scope>` | `events`, `before_session`, `oauth_providers` | What follow-up generators add at this point. |

The whole marker name is lowercase, underscored, dot-separated, and
matches the file's domain. Any deviation from this shape is a bug in
the engine template, not a feature.

The marker is a Ruby comment so it round-trips through every linter
and parser the host uses — including RuboCop, Rubymine, Sorbet,
Solargraph, and editor LSPs. **No emoji**, no Unicode bytes, no
multi-character markers like `<<` or `=>`. (A previous review of a
sibling framework flagged emoji markers as a misfeature: pretty in
the editor, broken in `grep` and patch tools.)

## End markers

There are no end markers. Insertion is always **after** the marker
line (or, optionally, **before** it via the Splicer's `before:`
flag). The single-line marker is the entire contract; the splicer
inserts the content directly below or above and writes the file.

This keeps the contract minimal and prevents a class of "what if the
end marker is missing?" failure modes seen in similar systems.

## Discovery contract

Follow-up generators look up a marker **by name**, never by line
number. Three guarantees follow:

1. A host can add unrelated lines above or below a marker; the marker
   keeps working.
2. A host can move blocks around the file; the marker keeps working
   as long as the comment line itself isn't deleted.
3. Two different engine generators can't share a marker name — the
   `<engine>` prefix segment makes every marker name globally unique.

The Splicer is **idempotent on rerun**. Re-splicing the exact same
content under the same marker is a no-op: the splicer reads the 50
lines after the marker and skips the write if the snippet is already
there. This makes follow-up generators safe to re-run during
development without manual cleanup.

When the marker isn't found the splicer returns
`Splicer::Result(ok?: false, error: "marker '<name>' not found in <path>")`
and writes nothing. The base class
`Seams::Generators::FollowUpGenerator#assert_marker_exists!` upgrades
that into a clear error message with a recovery hint.

## What NOT to insert into

Insertion points are a **public contract**. Every marker an engine
ships becomes a stable surface a follow-up generator can target. That
discipline limits where markers are appropriate.

**Place markers in:**

- `lib/<engine>/engine.rb` — inside the `register_events` initializer,
  inside an `after_initialize` block that wires subscribers, etc.
- `config/routes.rb` — before/after stable resource declarations.
- `lib/<engine>/configuration.rb` — inside a hash-or-array literal
  declaration the host extends (e.g. `oauth_providers = {}`).
- A small number of **registry-style constants** — for example
  `Notifications::Notifiable::STRATEGY_CLASSES`. The marker sits inside
  the literal, not adjacent to the literal.

**Do NOT place markers in:**

- Models, controllers, services, mailers, jobs, views, or partials.
  These are owned by the engine; hosts override behaviour through
  composition (concerns, configuration, the eject CLI), not through
  splice-and-pray.
- Migration files. Every host runs migrations on its own timetable;
  splicing into a migration that's already been run is a footgun.
- Fixture files, factory files, spec files. Tests are owned by the
  caller (engine or follow-up generator), not by an open extension
  point.
- Anywhere a comment isn't a syntactically valid expression — inside
  string literals, between method arguments on the same line, etc.

A useful guardrail when reviewing a proposed new marker: if the
follow-up generator's natural splice is "register one more thing" or
"add one more route", a marker is appropriate. If it's "rewrite this
class's behaviour", the eject CLI is the right tool, not a marker.

## Examples

### Inside an engine's event-registration initializer

```ruby
# engines/auth/lib/auth/engine.rb
initializer "auth.register_events" do
  Seams::EventRegistry.register("identity.signed_up.auth",   emitted_by: "Auth")
  Seams::EventRegistry.register("identity.signed_in.auth",   emitted_by: "Auth")
  Seams::EventRegistry.register("identity.signed_out.auth",  emitted_by: "Auth")
  # seams:insertion-point auth.engine.events
end
```

A follow-up generator splices a `register("identity.passkey_added.auth", ...)`
line directly after the marker.

### Before a routes resource

```ruby
# engines/auth/config/routes.rb
Auth::Engine.routes.draw do
  # seams:insertion-point auth.routes.before_session
  resource :session, only: %i[new create destroy], controller: :sessions
end
```

The follow-up generator that adds passkey routes splices its
`resource :passkey_session, ...` block before the marker (using the
Splicer's `before:` flag) so the new resource lands above the existing
one, in the order operators expect.

### Inside a hash literal

```ruby
# engines/auth/lib/auth/configuration.rb
@oauth_providers = {
  # seams:insertion-point auth.configuration.oauth_providers
}
```

A follow-up generator that adds a LinkedIn provider splices a
`linkedin: { adapter: "Auth::OAuth::LinkedIn", ... },` line after the
marker.

### Inside a registry constant

```ruby
# engines/notifications/lib/notifications/concerns/notifiable.rb
STRATEGY_CLASSES = {
  email:  "Notifications::Strategies::Email",
  sms:    "Notifications::Strategies::Sms",
  in_app: "Notifications::Strategies::InApp"
  # seams:insertion-point notifications.notifiable.strategies
}.freeze
```

## Non-examples

The following are **not** insertion points; they're either places
where an explicit override is the right pattern, or places where a
marker would create a broken contract.

```ruby
# WRONG: inside a method body the framework owns
def authenticate!
  # seams:insertion-point auth.authentication.authenticate
  # ...
end
```
Hosts override `authenticate!` by including a host-defined module or
overriding the method outright; a marker here would imply "you can
extend this method" without specifying how.

```ruby
# WRONG: inside a migration
class CreateAuthIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :auth_identities do |t|
      t.text :email, null: false
      # seams:insertion-point auth.migrations.identities_columns
      t.timestamps
    end
  end
end
```
Migrations run once. A follow-up generator should ship a NEW migration,
not splice into an existing one.

```ruby
# WRONG: marker name uses camelcase
# seams:insertion-point Auth.Engine.Events
```
Marker names are lowercase, underscored, dot-separated. The names map
onto file paths and event names, both of which are lowercase.

```ruby
# WRONG: marker name has no engine prefix
# seams:insertion-point events
```
Without an engine prefix, two engines can't both ship a `.events`
marker. The catalogue is the public contract; collisions are bugs.

## Naming rules summary

- `<engine>.<area>.<scope>`, three segments, separated by dots.
- Lowercase. Underscores between words within a segment.
- Engine name matches the directory under `engines/` (e.g. `auth`,
  not `Auth`).
- Area name matches the file's purpose (e.g. `engine`, `routes`,
  `configuration`).
- Scope name describes what follow-up generators add (e.g. `events`,
  `before_session`, `oauth_providers`).
- One marker per logical extension point. If a follow-up generator
  has to splice into two places to do its job, declare two markers.
