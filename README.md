# Seams

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
bin/seams auth
bin/seams accounts
bin/seams notifications
bin/seams billing
bin/seams teams
bin/seams list
```

That's auth, tenant boundary, transactional email/SMS, Stripe
subscriptions, and multi-tenant teams generated as five real Rails
engines under `engines/`. Every file is yours to edit. Nothing is
hidden behind the gem.

## What you get

- `bin/seams install`        — adds the framework + CI workflow + bin/seams wrapper
- `bin/seams engine <name>`  — generic engine scaffold
- `bin/seams core`           — canonical Core engine (Current attributes, AuditLog, TenantScoped, EmailFormatValidator)
- `bin/seams auth`           — canonical Auth engine (Identity, Session, OAuth, API tokens, GDPR-encrypted PII)
- `bin/seams accounts`       — canonical Accounts engine (Account tenant, Membership, AccountScoped, system actor)
- `bin/seams notifications`  — canonical Notifications engine (STI strategies, ActionCable bell, TypeRegistry, --channels flag)
- `bin/seams billing`        — canonical Billing engine (official Stripe gem, 13-handler webhook router, Lifetime Deals)
- `bin/seams teams`          — canonical Teams engine (Team, Membership, Invitation, AccountScoped, --with flag)
- `bin/seams remove <name>`  — clean removal + sibling cleanup + drop-table migration
- `bin/seams list`           — engines, the events they emit, and what they subscribe to
- `bin/seams resolve`        — eject host files / list insertion-point markers / list ejected files
- `bin/rails generate seams:auth:add_oauth_provider <name>` — first follow-up generator (adds an OAuth provider adapter to an installed Auth engine)
- Four custom RuboCop cops that enforce cross-engine boundaries
- A GitHub Actions CI workflow that runs every engine's specs in parallel

## Documentation

- [doc/GETTING_STARTED.md](doc/GETTING_STARTED.md)
- [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) — short overview
- [doc/ARCHITECTURE_WAVE_9.md](doc/ARCHITECTURE_WAVE_9.md) — full system walk-through (post-Wave-9)
- [doc/ARCHITECTURE_WAVE_10.md](doc/ARCHITECTURE_WAVE_10.md) — Wave 10 addendum: insertion points, follow-up generators, eject CLI
- [doc/ENGINE_CATALOGUE.md](doc/ENGINE_CATALOGUE.md)
- [doc/CURRENT_ATTRIBUTES.md](doc/CURRENT_ATTRIBUTES.md) — per-request namespaces (Auth::Current, Accounts::Current, Teams::Current, Core::Current)
- [doc/INSERTION_POINTS.md](doc/INSERTION_POINTS.md) — marker format spec
- [doc/INSERTION_POINTS_CATALOGUE.md](doc/INSERTION_POINTS_CATALOGUE.md) — the canonical 33 markers
- [doc/WRITING_FOLLOW_UP_GENERATORS.md](doc/WRITING_FOLLOW_UP_GENERATORS.md) — write your own follow-up generator
- [doc/ADDING_AN_ENGINE.md](doc/ADDING_AN_ENGINE.md)
- [doc/REMOVING_AN_ENGINE.md](doc/REMOVING_AN_ENGINE.md)
- [doc/WRITING_AN_ADAPTER.md](doc/WRITING_AN_ADAPTER.md)
- [doc/TESTING.md](doc/TESTING.md)
- [doc/UPGRADING_FROM_WAVE_8.md](doc/UPGRADING_FROM_WAVE_8.md) — if you adopted seams pre-Wave-9

## Why Seams instead of...

| ... | Seams gives you |
| --- | --- |
| Bullet Train | The substrate, not a starter kit. Code is in your repo, not behind a gem. |
| Jumpstart Pro | Same. Plus the boundary cops. |
| `rails plugin new --mountable` | Engines come pre-wired with events, registry, observability, boundary enforcement, CI. |
| Hand-rolled microservices | One process. No HTTP between services. Synchronous events with explicit subscribers. |

## Status

Waves 1–9 complete: foundation, auth (with OAuth, API tokens,
GDPR-encrypted PII), notifications (with TypeRegistry,
ActionCable bell, multipart mailers), billing (official Stripe
gem, 13-handler webhook router, Lifetime Deals), teams (with
team scoping, role-based authz). Wave 9 added the `accounts`
engine and reworked the identity/account/team boundary —
`Auth::Identity` (the human), `Accounts::Account` (the tenant),
`Teams::Team` (the optional grouping) are now three peer engines
with one clear responsibility each. See
[CHANGELOG.md](CHANGELOG.md#wave-9--identity--account--team-rework-breaking)
and [doc/UPGRADING_FROM_WAVE_8.md](doc/UPGRADING_FROM_WAVE_8.md).

See [issue #5](https://github.com/Davidslv/seams/issues/5) for the live
work tracker.

Suite: RuboCop clean, brakeman + bundle-audit clean. Run
`bin/audit` before any push.

## License

MIT — see [LICENSE](LICENSE).
