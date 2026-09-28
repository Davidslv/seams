# Getting Started

This walks through installing Seams in a fresh Rails app and
generating your first canonical engine.

## Prerequisites

- Ruby 3.3+
- Rails 7.1+ (8.x recommended)
- PostgreSQL. The engines use `jsonb` columns, so SQLite and MySQL are
  not supported. For a new app: `rails new myapp --database=postgresql`.
- A new or existing Rails application

## 1. Install

```ruby
# Gemfile
gem "seams", "~> 0.2"
```

```bash
bundle install
bin/rails generate seams:install
bundle install   # install adds gems (rspec-rails, rubocop, brakeman, ...)
```

The install generator scaffolds:

- `config/initializers/seams.rb`
- `config/seams_engines.rb` — registers each engine on the host's load path; `require_relative "seams_engines"` is injected into `config/application.rb` so engines load before `Rails.application.initialize!`
- `engines/.keep`
- `lib/tasks/seams.rake`
- `.github/workflows/ci.yml` — lint + brakeman + per-engine test matrix
- `bin/seams` — short CLI wrapper
- `script/run_affected_tests.sh`, `script/collate_coverage.rb` — host-local helpers
- `doc/ARCHITECTURE.md` — per-host architecture template

## 2. Generate your first engines

`core` comes first. Every other engine builds on it.

```bash
bin/seams core
bin/seams auth
```

Look at what `auth` created:

```bash
$ ls engines/auth
app  auth.gemspec  config  db  Gemfile  lib  LICENSE  Rakefile  README.md  spec
$ ls engines/auth/app
controllers  jobs  mailers  models  services  views
```

## 3. What the generators wire up, and what you do

The generators edit your app for you:

- a `mount` line per engine in `config/routes.rb` (`/auth`, `/core`, ...)
- `include Auth::Authentication` in your `ApplicationController`
- `config/initializers/<engine>.rb` for each engine
- any gems the engine needs, in your Gemfile

You do three things:

1. **Install the gems they added:**

   ```bash
   bundle install
   ```

2. **Create encryption keys.** The auth engine encrypts personal data
   at rest with Active Record encryption. Without keys, sign-up fails
   with `Missing Active Record encryption credential`.

   ```bash
   bin/rails db:encryption:init   # prints an active_record_encryption: block
   bin/rails credentials:edit     # paste the block in and save
   ```

3. **Run the migrations:**

   ```bash
   bin/rails db:migrate
   ```

Sign-up is at `/auth/registration/new` and sign-in at `/auth/session/new`.

## 4. Generate more engines

```bash
bin/seams core                          # shared primitives (Current, AuditLog, concerns)
bin/seams accounts                      # tenant boundary + Membership + system actor
bin/seams notifications                 # outbound email/SMS, swappable adapters
bin/seams notifications --channels in_app,email   # or pick a subset (default: all)
bin/seams billing                       # Stripe subscriptions + webhooks
bin/seams teams                         # multi-tenant teams + invitations
bin/seams teams --with roles            # or pick a subset of team features (default: all)
bin/seams permissions                   # host-editable role → ability grant map
bin/seams admin                         # Administrate dashboards (opt-in; see ARCHITECTURE_WAVE_11.md)
bin/seams design --shell                # design system + app layout + starter dashboard
```

Every time you generate a new engine the existing engines'
`.rubocop.yml` files are auto-updated so the boundary cops cover
the new engine without manual edits.

Run `bundle install` and `bin/rails db:migrate` after generating. Several
engines add gems: billing adds `stripe`, admin adds `administrate` and
`pundit`, design adds `tailwindcss-rails`. After `bin/seams design`, also
run `bin/rails tailwindcss:build`, because the layout loads the compiled CSS.

The recommended order is `core → auth → accounts → notifications →
billing → teams`. Some engines depend on each other (accounts on
auth, billing on accounts) — see each engine's README for the
"Requires:" line. `permissions`, `admin`, and `design` are opt-in and
can be added at any time. Only staff can open the admin area: set
`staff: true` on an `Auth::Identity` to let someone in. Run `bin/seams design --shell` to also get a
ready-to-boot application layout and signed-in dashboard, which makes
the other engines visible in a real, styled UI.

## 5. Inspect what you have

```bash
bin/seams list
```

Lists every engine and the events it emits.

## 6. Run the boundary cops

```bash
bundle exec rubocop
```

Per-engine `.rubocop.yml` already loads `seams/cops`. CI runs the
same lint job in `.github/workflows/ci.yml`.

## 7. Run the engine specs

```bash
bin/seams test auth
```

Each engine has its own `spec/` directory. The CI workflow runs all
of them in parallel (one job per engine).

## Next steps

- [ADDING_AN_ENGINE.md](../how-to/ADDING_AN_ENGINE.md) — Build your own engine on top of the generic generator.
- [WRITING_AN_ADAPTER.md](../how-to/WRITING_AN_ADAPTER.md) — Swap in Mailgun, Twilio, Paddle, etc.
- [ENGINE_CATALOGUE.md](../reference/ENGINE_CATALOGUE.md) — The canonical engines in detail.
- [PERMISSIONS.md](../reference/PERMISSIONS.md) — Role → ability grant map and `authorize_permission!`.
- [DESIGN_SYSTEM.md](../design-system/DESIGN_SYSTEM.md) — The design engine: components, tokens, theming.
- [ARCHITECTURE_WAVE_11.md](../explanation/ARCHITECTURE_WAVE_11.md) — The admin engine.
- [CURRENT_ATTRIBUTES.md](../reference/CURRENT_ATTRIBUTES.md) — Per-request namespaces (Auth::Current, Accounts::Current, Teams::Current).
- [ARCHITECTURE.md](../explanation/ARCHITECTURE.md) — Why Seams is built this way.
- [UPGRADING_FROM_WAVE_8.md](../how-to/UPGRADING_FROM_WAVE_8.md) — If you adopted seams pre-Wave-9.
