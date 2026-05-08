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
- `bin/seams core`           — canonical Core engine (Current attributes, AuditLog, TenantScoped, EmailFormatValidator)
- `bin/seams auth`           — canonical Auth engine (User, Session, OAuth, API tokens, GDPR-encrypted PII)
- `bin/seams notifications`  — canonical Notifications engine (STI strategies, ActionCable bell, TypeRegistry, --channels flag)
- `bin/seams billing`        — canonical Billing engine (Faraday Stripe client, 13-handler webhook router, Lifetime Deals)
- `bin/seams teams`          — canonical Teams engine (Team, Membership, Invitation, AccountScoped, --with flag)
- `bin/seams remove <name>`  — clean removal + sibling cleanup + drop-table migration
- `bin/seams list`           — engines, the events they emit, and what they subscribe to
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

Phases 1–5 complete: foundation, auth (with OAuth, API tokens,
GDPR-encrypted PII), notifications (with TypeRegistry,
ActionCable bell, multipart mailers), billing (Faraday Stripe
client, 13-handler webhook router, Lifetime Deals), teams (with
account scoping, role-based authz). Phase 6 quality gates:
8/10 ticked; the two remaining items are manual operator
verifications (Stripe test-mode walkthrough + real `docker build`
with all engines). Phase 7 (launch + RubyGems publish) is open.

See [issue #5](https://github.com/Davidslv/seams/issues/5) for the live
work tracker.

Suite: 506 specs + 2 integration_full specs, RuboCop clean,
brakeman + bundle-audit clean.

## License

MIT — see [LICENSE](LICENSE).
