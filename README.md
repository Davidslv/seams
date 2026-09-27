# Seams

[![Gem Version](https://img.shields.io/gem/v/seams.svg)](https://rubygems.org/gems/seams)
[![CI](https://github.com/Davidslv/seams/actions/workflows/ci.yml/badge.svg)](https://github.com/Davidslv/seams/actions/workflows/ci.yml)
[![Docs site](https://img.shields.io/badge/docs-davidslv.github.io%2Fseams-blue.svg)](https://davidslv.github.io/seams/)
[![API docs](https://img.shields.io/badge/api-rubydoc.info-blue.svg)](https://rubydoc.info/gems/seams)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Seams generates modular Rails engines inside your Rails app.

You ship one Rails app. Inside it, each feature (auth, accounts, billing, teams, and so on) lives in its own engine under `engines/`. Each engine has its own models, tests, and boundaries. Engines talk to each other through events, not by reaching into each other's code. Custom RuboCop cops enforce that.

Every generated file is plain Rails code in your repo. You can read it, change it, or delete it. Nothing is hidden behind the gem.

> [!NOTE]
> Seams is the executable companion to the book **[Modular Rails: Architecture for the Long Game](https://davidslv.uk/modular-rails/)**. The full guides live on the **[documentation site](https://davidslv.github.io/seams/)**. [seams-example](https://github.com/Davidslv/seams-example) is a reference host with every engine wired up.

## Requirements

| | Supported | Tested in CI |
| --- | --- | --- |
| Ruby | 3.3 or newer | 3.3, 3.4, 4.0.7 |
| Rails | 7.1 or newer (below 9) | 8.1.4 |
| Database | PostgreSQL | PostgreSQL 18 |

> [!IMPORTANT]
> **PostgreSQL is required.** The generated engines use `jsonb` columns, and each engine's test suite runs against Postgres. SQLite and MySQL are not supported.

## Installation

> [!WARNING]
> **Install from GitHub for now.** The only release on RubyGems is `0.1.0` (May 2026). It requires Ruby 4.0 or newer and predates many fixes, including the admin engine working at all and Ruby 3.3 support. Until a new version is released, point your Gemfile at the repository:
>
> ```ruby
> # Gemfile
> gem "seams", github: "Davidslv/seams"
> ```
>
> Once a newer version is on RubyGems, use `gem "seams"` instead.

Then install the framework:

```bash
bundle install
bin/rails generate seams:install
```

`seams:install` adds the framework files, a CI workflow, and a `bin/seams` command. Every step after this uses `bin/seams`.

## Quick start

Generate the engines you need. The order matters, because later engines build on earlier ones:

```bash
bin/seams core            # shared building blocks (always first)
bin/seams auth            # sign-in, sessions, OAuth, API tokens
bin/seams accounts        # the tenant (Account) and its members
bin/seams notifications   # in-app, email, and SMS notifications
bin/seams billing         # Stripe subscriptions
bin/seams teams           # optional teams inside an account
bin/seams design --shell  # UI components and an app layout

bundle install
bin/rails db:migrate
bin/seams list            # show engines, their events, and subscribers
```

> [!TIP]
> New to Seams? Follow **[Getting Started](doc/tutorials/GETTING_STARTED.md)**. It goes step by step from `bundle install` to a running app.

## What you get

### The engines

| Command | What it generates |
| --- | --- |
| `bin/seams core` | Shared basics: per-request `Current` attributes, an audit log, tenant scoping, an email validator. |
| `bin/seams auth` | `Identity` (the person signing in), sessions, OAuth providers, API tokens. Personal data is encrypted at rest. |
| `bin/seams accounts` | `Account` (the tenant), memberships with roles, account scoping. |
| `bin/seams notifications` | Notifications over in-app, email, and SMS. Choose channels with `--channels in_app,email,sms` (default: all). |
| `bin/seams billing` | Stripe subscriptions using the official `stripe` gem (19.x), a webhook router with 13 handlers, and lifetime deals. |
| `bin/seams teams` | Teams, team memberships, and invitations. Choose features with `--with invitations,roles` (default: all). |
| `bin/seams admin` | An admin area built on Administrate and Pundit. Optional. See [Admin engine](#admin-engine) below. |
| `bin/seams design` | A design system: 33 `ui_*` components, Tailwind v4 theme tokens, a form builder, and a `/design/guide` gallery. `--shell` also adds an app layout and a starter dashboard. |
| `bin/seams permissions` | An editable map of which roles can do what, in `config/initializers/seams_permissions.rb`. See [Permissions](doc/reference/PERMISSIONS.md). |

### Framework and tools

| Command | What it does |
| --- | --- |
| `bin/rails generate seams:install` | Installs the framework, the CI workflow, and `bin/seams`. |
| `bin/seams engine <name>` | Generates an empty engine for your own feature. |
| `bin/seams remove <name>` | Removes an engine, cleans up references to it, and adds a migration that drops its tables. |
| `bin/seams list` | Lists engines, the events they publish, and who subscribes to them. |
| `bin/seams test <engine>` | Runs one engine's tests. |
| `bin/seams quality <engine>` | Runs RuboCop on one engine. |
| `bin/seams resolve --eject <engine>/<file>` | Marks a generated file as yours, so future runs of the generator leave it alone. Also `--list-markers <engine>` and `--list-ejected`. |
| `bin/rails generate seams:auth:add_oauth_provider <name>` | Adds an OAuth provider to the auth engine. |

You also get:

- **Four custom RuboCop cops.** Two fail the build when one engine reaches into another's code or models. The other two check background job queue names and migration comments.
- **A GitHub Actions workflow** that runs each engine's tests in parallel.
- **A quality toolchain** set up by `seams:install`:
  - strong_migrations and lefthook git hooks are on by default. Turn them off with `--no-strong-migrations` or `--no-lefthook`.
  - herb (ERB lint) is off by default. Turn it on with `--herb`.
- **A Dockerfile and a Kamal `deploy.yml`**, written only if your app doesn't already have them. Rails 8 apps ship their own Dockerfile, which Seams leaves in place.

## Admin engine

`bin/seams admin` adds an admin area at `/admin`. It needs the `auth` engine. It adds the `administrate` and `pundit` gems to your Gemfile.

> [!IMPORTANT]
> **Only staff can open the admin area by default.** Set `staff: true` on an `Auth::Identity` to let that person in:
>
> ```ruby
> Auth::Identity.find_by(email: "you@example.com").update!(staff: true)
> ```
>
> Signed-out visitors are sent to the sign-in page. Signed-in identities that aren't staff get a 403.

<details>
<summary><strong>Tenant mode: let each customer's admins manage their own account</strong></summary>

By default the admin area runs in **platform** mode: staff see every account. In **tenant** mode, an account's admins see only their own account's data.

Tenant mode needs three settings. Without the last two, tenant admins get a 403.

```ruby
# config/initializers/seams_admin.rb
Seams::Admin.configure do |c|
  c.tenancy_scope = :tenant

  # Let any signed-in identity past the gate. The tenant policies then
  # decide what each role may do.
  c.authenticator = ->(ctrl) { ctrl.current_identity.present? }

  # Tell the admin area which membership the request belongs to.
  # This example takes the identity's first active membership. Use
  # however your app picks the current account (subdomain, session, a switcher).
  c.current_membership_resolver = lambda do |ctrl|
    identity = ctrl.current_identity
    identity && Accounts::Membership.find_by(identity_id: identity.id, active: true)
  end
end
```

With these set:
- An `admin` or `owner` of an account sees only that account's rows.
- Requests for another account's records return 404.
- A `member` gets a 403.

The generated `engines/admin/README.md` has the full reference.

</details>

## Upgrading an existing Seams app

Seams writes code into your app. So updating the gem does not change engines you already generated. Read the [CHANGELOG](CHANGELOG.md) before you update, and apply the changes that affect you.

> [!NOTE]
> If you generated engines before the September 2026 changes, check these:
> - **solid_cable 4.1 or newer:** each engine's test app needs `engines/*/spec/dummy/config/cable.yml`, containing `test:` with `adapter: test`. Without it, the engine's tests fail to load.
> - **Billing:** the generated code now targets `stripe ~> 19.0`. The generated services now raise `Billing::GatewayError` instead of `Stripe::*` errors. Set your Stripe webhook endpoint to the same API version as the gem.
> - **Admin:** regenerate the admin engine, or copy the fixes listed in the CHANGELOG. Earlier versions could not boot or serve any admin page.
>
> If you adopted Seams before Wave 9, start with the [Wave 8 upgrade guide](doc/how-to/UPGRADING_FROM_WAVE_8.md).

## Documentation

The **[documentation site](https://davidslv.github.io/seams/)** has every guide below, with search. The API reference is on **[rubydoc.info](https://rubydoc.info/gems/seams)**.

<details>
<summary><strong>Start here</strong></summary>

- [Getting Started](doc/tutorials/GETTING_STARTED.md): install, first engine, running app
- [Engine catalogue](doc/reference/ENGINE_CATALOGUE.md): every engine in detail
- [Architecture overview](doc/explanation/ARCHITECTURE.md): why Seams is built this way

</details>

<details>
<summary><strong>Building and extending</strong></summary>

- [Adding an engine](doc/how-to/ADDING_AN_ENGINE.md)
- [Removing an engine](doc/how-to/REMOVING_AN_ENGINE.md)
- [Writing an adapter](doc/how-to/WRITING_AN_ADAPTER.md): swap in Mailgun, Twilio, Paddle, and others
- [Writing follow-up generators](doc/how-to/WRITING_FOLLOW_UP_GENERATORS.md)
- [Insertion points](doc/reference/INSERTION_POINTS.md) and the [catalogue of markers](doc/reference/INSERTION_POINTS_CATALOGUE.md)
- [Deploying](doc/how-to/DEPLOYING.md)

</details>

<details>
<summary><strong>Reference</strong></summary>

- [Current attributes](doc/reference/CURRENT_ATTRIBUTES.md): `Auth::Current`, `Accounts::Current`, `Teams::Current`, `Core::Current`
- [Permissions](doc/reference/PERMISSIONS.md): ability codes, roles, the grant map
- [Observability](doc/reference/OBSERVABILITY.md): logging, tracing, metrics
- [Testing](doc/reference/TESTING.md)

</details>

<details>
<summary><strong>Design system</strong></summary>

- [Design system overview](doc/design-system/DESIGN_SYSTEM.md) (start here)
- [Foundations](doc/design-system/DESIGN_SYSTEM_FOUNDATIONS.md): tokens and scales
- [Components](doc/design-system/DESIGN_SYSTEM_COMPONENTS.md): the 33 `ui_*` components
- [Forms](doc/design-system/DESIGN_SYSTEM_FORMS.md): `Design::FormBuilder`
- [Theming](doc/design-system/DESIGN_SYSTEM_THEMING.md)
- [Accessibility](doc/design-system/DESIGN_SYSTEM_ACCESSIBILITY.md)

</details>

<details>
<summary><strong>Architecture history</strong></summary>

- [Wave 9](doc/explanation/ARCHITECTURE_WAVE_9.md): the full system walk-through, including the identity / account / team split
- [Wave 10](doc/explanation/ARCHITECTURE_WAVE_10.md): insertion points, follow-up generators, the eject command
- [Wave 11](doc/explanation/ARCHITECTURE_WAVE_11.md): the admin engine
- [Personal data and GDPR](doc/explanation/WAVE_11_PII_GDPR.md)
- [Architecture Decision Records](doc/adr/)

</details>

## How Seams compares

| Instead of | Seams gives you |
| --- | --- |
| Bullet Train or Jumpstart Pro | The code lives in your repo, not behind a gem. Seams also enforces engine boundaries with RuboCop cops. |
| `rails plugin new --mountable` | Engines come wired with events, registries, observability, boundary checks, and CI. |
| Microservices | One process and one deploy. No HTTP between services. Engines talk through synchronous events with explicit subscribers. |

## Project status

> [!NOTE]
> Seams is in active development and has not reached 1.0. Breaking changes are listed in the [CHANGELOG](CHANGELOG.md). Open work is tracked in [issue #5](https://github.com/Davidslv/seams/issues/5).

Each change is checked in CI:
- RuboCop, Brakeman, and bundle-audit
- the gem's own tests, on Ruby 3.3, 3.4, and 4.0.7
- an end-to-end run that creates a new Rails app with `rails new`, generates every engine, runs each engine's tests, and boots the app against Postgres

## Contributing

- **How to contribute:** [CONTRIBUTING.md](CONTRIBUTING.md) covers setup, the checks, and the pull request workflow. Run `bin/audit` before you push.
- **Security issues:** [SECURITY.md](SECURITY.md)
- **Getting help:** [SUPPORT.md](SUPPORT.md)
- **How the project is run:** [GOVERNANCE.md](GOVERNANCE.md) and [MAINTAINERS.md](MAINTAINERS.md)
- **Community expectations:** [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- **AI coding agents:** [AGENTS.md](AGENTS.md) and [llms.txt](llms.txt)
- **Citing Seams:** [CITATION.cff](CITATION.cff)

## License

MIT. See [LICENSE](LICENSE).
