# Seams

> A CLI framework that generates modular Rails engines.

Seams gives you the architectural benefits of microservices — clear
boundaries, independent testing, team autonomy — without the
operational cost. You ship a single Rails app. You think in
independent engines.

## Quick start

```ruby
# Gemfile
gem "seams"
```

```bash
bundle install
bin/rails generate seams:install
bin/seams auth
bin/seams notifications
bin/seams billing
bin/seams teams
bin/seams list
```

That's auth, transactional email/SMS, Stripe subscriptions, and
multi-tenant teams generated as four real Rails engines under
`engines/`. Every file is yours to edit. Nothing is hidden behind
the gem.

## What you get

- `bin/seams install`        — adds the framework + CI workflow + bin/seams wrapper
- `bin/seams engine <name>`  — generic engine scaffold
- `bin/seams auth`           — canonical Auth engine (User, Session, sign-in/out, current_user)
- `bin/seams notifications`  — canonical Notifications engine (jobs, ActionMailer adapter, AuthSubscriber)
- `bin/seams billing`        — canonical Billing engine (Subscription, Invoice, Stripe gateway, idempotent webhooks)
- `bin/seams teams`          — canonical Teams engine (Team, Membership, Invitation, Authorization concern)
- `bin/seams remove <name>`  — clean removal + sibling cleanup
- `bin/seams list`           — engines + their events
- Four custom RuboCop cops that enforce cross-engine boundaries
- A GitHub Actions CI workflow that runs every engine's specs in parallel

## Documentation

- [doc/GETTING_STARTED.md](doc/GETTING_STARTED.md)
- [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md)
- [doc/ENGINE_CATALOGUE.md](doc/ENGINE_CATALOGUE.md)
- [doc/ADDING_AN_ENGINE.md](doc/ADDING_AN_ENGINE.md)
- [doc/REMOVING_AN_ENGINE.md](doc/REMOVING_AN_ENGINE.md)
- [doc/WRITING_AN_ADAPTER.md](doc/WRITING_AN_ADAPTER.md)
- [doc/TESTING.md](doc/TESTING.md)

## Why Seams instead of...

| ... | Seams gives you |
| --- | --- |
| Bullet Train | The substrate, not a starter kit. Code is in your repo, not behind a gem. |
| Jumpstart Pro | Same. Plus the boundary cops. |
| `rails plugin new --mountable` | Engines come pre-wired with events, registry, observability, boundary enforcement, CI. |
| Hand-rolled microservices | One process. No HTTP between services. Synchronous events with explicit subscribers. |

## Status

Phase 1–4 complete: foundation, auth, notifications, billing
(Stripe), teams. CI workflow + bin/seams wrapper shipped in Phase 6.
Documentation in Phase 7.

Suite: 197 specs, 97% line coverage, RuboCop clean, brakeman + bundle-audit clean.

## License

MIT — see [LICENSE](LICENSE).
