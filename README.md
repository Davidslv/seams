# Seams

[![Gem Version](https://img.shields.io/gem/v/seams.svg)](https://rubygems.org/gems/seams)
[![CI](https://github.com/Davidslv/seams/actions/workflows/ci.yml/badge.svg)](https://github.com/Davidslv/seams/actions/workflows/ci.yml)
[![Docs site](https://img.shields.io/badge/docs-davidslv.github.io%2Fseams-blue.svg)](https://davidslv.github.io/seams/)
[![API docs](https://img.shields.io/badge/api-rubydoc.info-blue.svg)](https://rubydoc.info/gems/seams)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> 📖 **Documentation site: [davidslv.github.io/seams](https://davidslv.github.io/seams/)**
> — the guides below, searchable and grouped by Diátaxis, with the
> [API reference](https://davidslv.github.io/seams/api/) alongside.

> A CLI framework that generates modular Rails engines.

Seams gives you the architectural benefits of microservices — clear
boundaries, independent testing, team autonomy — without the
operational cost. You ship a single Rails app. You think in
independent engines.

> Seams materialises the patterns David Silva teaches in **[Modular
> Rails: Architecture for the Long Game](https://davidslv.uk/modular-rails/)**.
> The book is the artefact; this gem is the executable shorthand. See
> [seams-example](https://github.com/Davidslv/seams-example) for a
> reference host that wires every canonical engine end-to-end.

## Quick start

```ruby
# Gemfile
gem "seams"
```

```bash
bundle install
bin/rails generate seams:install
bin/seams core
bin/seams auth
bin/seams accounts
bin/seams notifications
bin/seams billing
bin/seams teams
bin/seams design --shell
bin/seams list
```

That's shared primitives, auth, the tenant boundary, transactional
email/SMS, Stripe subscriptions, multi-tenant teams, and a themeable
design system generated as real Rails engines under `engines/`. Every
file is yours to edit. Nothing is hidden behind the gem.

New to Seams? Start with **[doc/GETTING_STARTED.md](doc/GETTING_STARTED.md)**
— a step-by-step walkthrough from `bundle install` to a booting host.

## What you get

### Framework

- `bin/seams install` — adds the framework + CI workflow + `bin/seams` wrapper. Opt-out quality toolchain via `--no-strong-migrations` / `--no-lefthook`; **opt-in** herb (ERB lint) via `--herb`.
- `bin/seams engine <name>` — generic engine scaffold
- `bin/seams remove <name>` — clean removal + sibling cleanup + drop-table migration

### Canonical engines

- `bin/seams core` — Core engine (Current attributes, AuditLog, TenantScoped, EmailFormatValidator)
- `bin/seams auth` — Auth engine (Identity, Session, OAuth, API tokens, GDPR-encrypted PII)
- `bin/seams accounts` — Accounts engine (Account tenant, Membership, AccountScoped, system actor)
- `bin/seams notifications` — Notifications engine (STI strategies, ActionCable bell, TypeRegistry). `--channels in_app,email,sms` (default: all)
- `bin/seams billing` — Billing engine (official Stripe gem, 13-handler webhook router, Lifetime Deals). `--gateway stripe` (default)
- `bin/seams teams` — Teams engine (Team, Membership, Invitation, AccountScoped). `--with invitations,roles` (default: all)
- `bin/seams admin` — Admin engine (Administrate dashboards, Pundit `Platform`/`Tenant` policy split, admin audit trail) — opt-in, see [Wave 11A](doc/ARCHITECTURE_WAVE_11.md)
- `bin/seams design` — Design-system engine (33 `ui_*` components, Tailwind v4 `@theme` tokens, `Design::FormBuilder`, `/design/guide` gallery). `--shell` also generates an app layout + starter dashboard
- `bin/seams permissions` — host-editable role → ability grant map (`config/initializers/seams_permissions.rb`), see [doc/PERMISSIONS.md](doc/PERMISSIONS.md)

### Diagnostics & escape hatch

- `bin/seams list` — engines, the events they emit, and what they subscribe to
- `bin/seams test <engine>` — run one engine's specs (`bin/rails seams:test[engine]`)
- `bin/seams quality <engine>` — run rubocop on one engine
- `bin/seams resolve --eject <engine>/<file>` — mark a host file as host-owned (skipped on regenerate); also `--list-markers <engine>` and `--list-ejected`

### Follow-up generators

- `bin/rails generate seams:auth:add_oauth_provider <name>` — add an OAuth provider adapter to an installed Auth engine. Write your own: [doc/WRITING_FOLLOW_UP_GENERATORS.md](doc/WRITING_FOLLOW_UP_GENERATORS.md)

### Plus

- Four custom RuboCop cops that enforce cross-engine boundaries
- A GitHub Actions CI workflow that runs every engine's specs in parallel

## Documentation

**API reference** is published per release at
**[rubydoc.info/gems/seams](https://rubydoc.info/gems/seams)** (generated
from YARD comments on the public Ruby API — the event bus, registries,
adapters, and configuration).

Guides and explanation live under [`doc/`](doc/):

### Start here

- [doc/GETTING_STARTED.md](doc/GETTING_STARTED.md) — install → first engine → booting host
- [doc/ENGINE_CATALOGUE.md](doc/ENGINE_CATALOGUE.md) — every canonical engine in detail
- [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) — short overview of why Seams is built this way

### Architecture (by wave)

- [doc/ARCHITECTURE_WAVE_9.md](doc/ARCHITECTURE_WAVE_9.md) — full system walk-through (post-Wave-9)
- [doc/ARCHITECTURE_WAVE_10.md](doc/ARCHITECTURE_WAVE_10.md) — insertion points, follow-up generators, eject CLI
- [doc/ARCHITECTURE_WAVE_11.md](doc/ARCHITECTURE_WAVE_11.md) — the admin engine (Administrate, Pundit policy split, admin audit)
- [doc/WAVE_11_PII_GDPR.md](doc/WAVE_11_PII_GDPR.md) — PII encryption & GDPR handling
- [doc/adr/](doc/adr/) — Architecture Decision Records (MADR): the *why* behind hard-to-reverse calls

### Building & extending

- [doc/ADDING_AN_ENGINE.md](doc/ADDING_AN_ENGINE.md)
- [doc/REMOVING_AN_ENGINE.md](doc/REMOVING_AN_ENGINE.md)
- [doc/WRITING_AN_ADAPTER.md](doc/WRITING_AN_ADAPTER.md) — swap in Mailgun, Twilio, Paddle, etc.
- [doc/WRITING_FOLLOW_UP_GENERATORS.md](doc/WRITING_FOLLOW_UP_GENERATORS.md)
- [doc/INSERTION_POINTS.md](doc/INSERTION_POINTS.md) — marker format spec
- [doc/INSERTION_POINTS_CATALOGUE.md](doc/INSERTION_POINTS_CATALOGUE.md) — the canonical 33 markers

### Reference

- [doc/CURRENT_ATTRIBUTES.md](doc/CURRENT_ATTRIBUTES.md) — per-request namespaces (Auth::Current, Accounts::Current, Teams::Current, Core::Current)
- [doc/PERMISSIONS.md](doc/PERMISSIONS.md) — ability codes, role hierarchy, the grant map, `authorize_permission!`
- [doc/OBSERVABILITY.md](doc/OBSERVABILITY.md) — logging, tracing, metrics integration
- [doc/TESTING.md](doc/TESTING.md)
- [doc/DEPLOYING.md](doc/DEPLOYING.md)

### Design system

- [doc/DESIGN_SYSTEM.md](doc/DESIGN_SYSTEM.md) — components, tokens, theming, FormBuilder (start here)
- [doc/DESIGN_SYSTEM_FOUNDATIONS.md](doc/DESIGN_SYSTEM_FOUNDATIONS.md) — tokens & scales
- [doc/DESIGN_SYSTEM_COMPONENTS.md](doc/DESIGN_SYSTEM_COMPONENTS.md) — the 33 `ui_*` components
- [doc/DESIGN_SYSTEM_FORMS.md](doc/DESIGN_SYSTEM_FORMS.md) — `Design::FormBuilder`
- [doc/DESIGN_SYSTEM_THEMING.md](doc/DESIGN_SYSTEM_THEMING.md) — retheme via token override
- [doc/DESIGN_SYSTEM_ACCESSIBILITY.md](doc/DESIGN_SYSTEM_ACCESSIBILITY.md)

### Migrating & releasing

- [doc/UPGRADING_FROM_WAVE_8.md](doc/UPGRADING_FROM_WAVE_8.md) — if you adopted seams pre-Wave-9
- [RELEASING.md](RELEASING.md) — for maintainers: how to cut a new gem release

## Why Seams instead of...

| ... | Seams gives you |
| --- | --- |
| Bullet Train | The substrate, not a starter kit. Code is in your repo, not behind a gem. |
| Jumpstart Pro | Same. Plus the boundary cops. |
| `rails plugin new --mountable` | Engines come pre-wired with events, registry, observability, boundary enforcement, CI. |
| Hand-rolled microservices | One process. No HTTP between services. Synchronous events with explicit subscribers. |

## Status

Active development, pre-1.0. The canonical engine set is built out
through **Wave 11**:

- **Waves 1–8** — foundation, auth (OAuth, API tokens, GDPR-encrypted PII), notifications (TypeRegistry, ActionCable bell, multipart mailers), billing (official Stripe gem, 13-handler webhook router, Lifetime Deals), teams (team scoping, role-based authz).
- **Wave 9** — added the `accounts` engine and reworked the identity/account/team boundary: `Auth::Identity` (the human), `Accounts::Account` (the tenant), `Teams::Team` (the optional grouping) are now three peer engines with one responsibility each. ([CHANGELOG](CHANGELOG.md#wave-9--identity--account--team-rework-breaking) · [upgrade guide](doc/UPGRADING_FROM_WAVE_8.md))
- **Wave 10** — insertion points, follow-up generators, and the eject CLI (`bin/seams resolve`).
- **Wave 11A** — the opt-in `admin` engine.
- **Wave 11B** — the `permissions` grant map.
- **Design system** — the `design` engine (`bin/seams design --shell`).

See [CHANGELOG.md](CHANGELOG.md) for the full history and
[issue #5](https://github.com/Davidslv/seams/issues/5) for the live
work tracker.

Suite: RuboCop clean, brakeman + bundle-audit clean. Run
`bin/audit` before any push.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the setup, the verification
gates, and the pull-request workflow. Security issues:
[SECURITY.md](SECURITY.md). Community expectations:
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

MIT — see [LICENSE](LICENSE).
