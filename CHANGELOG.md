# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Engine generator: ApplicationController now requires authentication by default. Opt out via `skip_before_action :authenticate_identity!` in controllers serving public flows. [BREAKING for hosts that explicitly relied on engines being unauthenticated by default.]
- Notifications generator: preferences controller now uses an explicit
  permit list from the channel/type registry rather than `permit!`.
  Eliminates the brakeman mass-assignment warning shipped with generated
  engines. Hosts that have already ejected
  `app/controllers/notifications/preferences_controller.rb` will not
  re-generate it (per the `template_unless_ejected` contract); to pick
  up the new behaviour, replace
  `params.require(:preferences).permit!` in the ejected copy with
  `params.require(:preferences).permit(*Notifications::Preferences.allowed_keys)`
  and require `notifications/preferences` from
  `lib/notifications.rb`.

## [0.1.0] — 2026-05-10

First public release on rubygems.org. The cumulative changelog from
Wave 1 through Wave 11A follows. Subsequent releases will track
per-version changes only.

### Wave 11A — Admin engine (Administrate-backed)

Ships `bin/rails generate seams:admin` as an opt-in canonical engine.
Hosts that have the canonical six in place (core, auth, accounts,
notifications, billing, teams) can mount an Administrate-backed admin
surface at `/admin` covering all twelve canonical seams models with a
single command. Dashboards, two-mode authorization, audit-log
auto-write, and the four config knobs all ship out of the box. See
[`doc/ARCHITECTURE_WAVE_11.md`](doc/ARCHITECTURE_WAVE_11.md) for the
new architecture material; the framework selection rationale lives in
[`proposals/admin_engine_administrate.md`](proposals/admin_engine_administrate.md).

#### Added

- **`bin/seams admin` generator + canonical engine.** Writes an
  `engines/admin/` engine into the host with twelve Administrate
  dashboards covering `Auth::Identity`, `Accounts::Account`,
  `Accounts::Membership`, `Teams::Team`, `Teams::Membership`,
  `Teams::Invitation`, `Notifications::Notification`,
  `Notifications::NotificationPreference`, `Billing::Plan`,
  `Billing::Subscription`, `Billing::Invoice`, and
  `Billing::LifetimePass`. Each dashboard subclasses
  `Administrate::BaseDashboard`; each controller subclasses
  `Seams::Admin::ApplicationController` (NOT Administrate's directly)
  so it inherits the gate, the `pundit_user` hook, and the audit-log
  auto-write. Engine ships **no migrations** — read-only over existing
  tables.
- **Two-mode authorization via Pundit `policy_namespace`.** Twelve
  policies under `Admin::Platform::*` (gate: `Auth::Identity#staff?`,
  no tenant filter) and twelve under `Admin::Tenant::*` (gate:
  `Accounts::Membership#role == "admin"`, scope filtered by
  `account_id` from `Accounts::Current.membership`). Plus two base
  `ApplicationPolicy` classes — 26 policy files total.
  `Seams::Admin.config.tenancy_scope` (`:platform` default, `:tenant`
  alternative) selects the namespace at request time.
- **`Seams::Admin::Context` Struct.** Wraps the current Identity +
  Membership as the value `pundit_user` returns. Exposes nil-safe
  `staff?`, `role`, and `account_id` convenience methods so policies
  stay readable without each one fishing values out of the controller.
- **Audit-log auto-write via `Core::Auditable` integration.**
  `record_admin_audit` after_action on every successful
  create/update/destroy emits a `Core::AuditLog` row keyed on
  `Auth::Current.identity&.id`. Wrapped in `defined?(Core::AuditLog)`
  so the engine boots without core. Update payloads carry
  `record.saved_changes.transform_values(&:last)`; create/destroy
  payloads carry attributes minus timestamps.
- **Four configuration knobs** in `Seams::Admin.config`:
  `authenticator` (callable; default `staff?` on current Identity);
  `tenancy_scope` (`:platform` | `:tenant`); `theme_css_path`
  (host-supplied admin restyle path); `before_admin_action` (callable
  hook for 2FA, IP allow-list, etc.).
- **Five Wave-10 insertion-point markers** placed in the admin engine:
  `admin.engine.events`, `admin.routes.before_resources`,
  `admin.routes.after_resources`, `admin.configuration.attributes`,
  `admin.configuration.defaults`. Catalogue updated to 38 markers
  total across seven engines.
- **Showcase install path on top of `seams-example`.** The admin
  generator stub-loads `Auth::Current` and `Accounts::Current`
  CurrentAttributes objects in the dummy app, ships slim
  `ApplicationRecord` stubs for every dashboard's resource_class, and
  appends `administrate` + `pundit` to both the engine's standalone
  Gemfile and the host Gemfile.
- **Boot-time dependency assertion.** The engine raises a clear
  `[seams admin] missing required dependency: ...` at boot when
  `Auth::Identity`, `Administrate`, or `Pundit` is missing — fail
  loud at boot rather than NameError mid-request.
- **`bin/seams help` + post-install message** updated to list `admin`
  alongside the canonical generators (with the explicit "optional —
  generate after the canonical six" caveat).
- **AdminUser-on-separate-tables rule reinterpretation** documented
  inline in the engine README. Wave 9's credential-only
  `Auth::Identity` already satisfies the rule's intent (no
  customer-facing concerns on the admin authentication object); a
  boolean `staff?` flag is the right granularity. Hosts that need
  hard isolation override the authenticator.

### Wave 10 — Splicing tooling

Turns seams from a one-shot scaffolder into a long-lived framework.
Generated engines now expose stable, named extension points;
follow-up generators target those points to add features without
re-templating the whole engine; and `bin/seams resolve --eject`
marks any single host file as host-owned so subsequent
`bin/seams <engine>` runs leave it alone. See
[`doc/ARCHITECTURE_WAVE_10.md`](doc/ARCHITECTURE_WAVE_10.md) for the
addendum and [`doc/WRITING_FOLLOW_UP_GENERATORS.md`](doc/WRITING_FOLLOW_UP_GENERATORS.md)
for the author's guide.

#### Added

- **Insertion-point machinery.** `Seams::Generators::Splicer`
  (idempotent splice primitives — looks up markers by name, never by
  line number; auto-detects indentation off the marker line; fifty-line
  idempotency window) and `Seams::Generators::FollowUpGenerator`
  (Rails generator base class supplying `engine_path`, `splice`,
  `assert_marker_exists!`, and a `report_summary` template-method
  hook). Pure file I/O — no Rails dep on the Splicer itself, so
  `bin/seams resolve` can reuse it without booting Rails.
- **Insertion-point catalogue.** 33 markers placed across the six
  canonical engines (32 active + 1 deferred to Wave 12 pending the
  core Configuration class). Marker shape:
  `# seams:insertion-point <engine>.<area>.<scope>` — ASCII only,
  greppable, parses through every Ruby linter. Format spec in
  [`doc/INSERTION_POINTS.md`](doc/INSERTION_POINTS.md); canonical list
  in [`doc/INSERTION_POINTS_CATALOGUE.md`](doc/INSERTION_POINTS_CATALOGUE.md).
- **`bin/seams resolve` CLI.** Three modes:
  - `--eject <engine>/<file>` — prepends a
    `# seams:ejected from <engine>.<path>` header to the host file;
    refuses to eject framework-managed files (migrations, engine.rb,
    version.rb, Gemfile, .gemspec).
  - `--list-markers <engine>` — lists every insertion-point marker
    the engine ships, with file:line and the catalogue's "purpose"
    one-liner where present. Falls back to a "this engine may not
    have been retrofitted" hint when the engine has zero markers.
  - `--list-ejected` — surveys `engines/` for files carrying the
    eject header, prints them with their source marker.
- **`Seams::Generators::EjectAware` mixin** — wired into all six
  canonical engine generators (auth, accounts, billing, core,
  notifications, teams). Every `template` call now goes through
  `template_unless_ejected`, which detects the eject header in the
  destination's first 200 bytes and short-circuits with a yellow
  `skip` log line.
- **First showcase follow-up generator.**
  `bin/rails generate seams:auth:add_oauth_provider <name>` (e.g.
  `linkedin`, `apple`, `microsoft`) creates an
  `Auth::OAuth::<Provider>` adapter under
  `engines/auth/lib/auth/oauth/<name>.rb`, splices a configuration
  entry into `engines/auth/lib/auth/configuration.rb` at the
  `auth.configuration.oauth_providers` marker, and writes a matching
  spec. Idempotent on rerun.
- **Documentation.**
  [`doc/INSERTION_POINTS.md`](doc/INSERTION_POINTS.md) (format spec),
  [`doc/INSERTION_POINTS_CATALOGUE.md`](doc/INSERTION_POINTS_CATALOGUE.md)
  (canonical 33-marker list),
  [`doc/WRITING_FOLLOW_UP_GENERATORS.md`](doc/WRITING_FOLLOW_UP_GENERATORS.md)
  (author's guide), and
  [`doc/ARCHITECTURE_WAVE_10.md`](doc/ARCHITECTURE_WAVE_10.md)
  (architecture addendum with splice + eject sequence diagrams).
- **Host-facing surfaces updated.**
  `bin/seams help` and `bin/seams resolve --help` document the new
  resolve modes; the install generator's post-install message lists
  the resolve sub-commands and points at the showcase follow-up
  generator.

### Wave 9 — Identity / Account / Team rework (BREAKING)

Replaces the conflated `Auth::User` (which owned credentials AND
tenant-membership concepts) with three peer engines, each with one
clear responsibility. See `doc/UPGRADING_FROM_WAVE_8.md` for the
migration story.

#### Added

- New `accounts` engine. Owns `Accounts::Account` (the tenant) and
  `Accounts::Membership` (Identity ↔ Account, role enum:
  owner/admin/member/system). Provides `Accounts::Current.account`
  and `Accounts::Current.membership` (the matching membership
  auto-derived for the signed-in identity), `Accounts::AccountScoped`
  concern (default-scope to the current account), and an
  auto-created `system` Membership per Account so audit-log writes
  from background jobs always have a valid actor to point at.
- `Accounts::Authorization` controller concern with default-on
  `ensure_account_access`; opt out via `disallow_account_scope` or
  `require_access_without_membership`. Helpers `ensure_admin` and
  `ensure_staff` for admin-tooling guards.
- New `Auth::Current` per-request namespace (peer to
  `Accounts::Current`, `Teams::Current`, and `Core::Current`). The
  Auth engine sets `Auth::Current.identity` in its session lookup;
  the rest of the engines read it.
- New `Teams::Current` per-request namespace, peer to
  `Auth::Current` and `Accounts::Current`. `Teams::AccountScoped`
  reads `Teams::Current.team` to scope rows to the current team.
- New `bin/seams accounts` command and Accounts engine generator.

#### Changed (BREAKING)

- `Auth::User` renamed to `Auth::Identity`. The `auth_users` table
  becomes `auth_identities`. All credential state
  (`password_digest`, OAuth grants, sessions, passkeys, magic-link
  grants, API tokens) stays on `Auth::Identity` — the rename is
  about meaning, not about splitting state.
- `Auth::Authentication` controller concern renamed `current_user`
  to `current_identity` and `authenticate_user!` to
  `authenticate_identity!`. Hosts that maintain a domain User on
  top of `Auth::Identity` can re-expose `current_user` via their
  own concern.
- The Rails-8 `has_secure_password` `reset_token: false` workaround
  is dropped — the rename to `Auth::Identity` resolves the prior
  naming clash on `password_reset_token`.
- `Teams::Membership` joins `Auth::Identity` directly (column
  `identity_id`), not the host User. The `Teams::Teamable` concern
  is removed entirely (Wave 9 dropped the canonical demo's host
  User; nowhere to mix it into).
- `Team#member?` signature changed: previously took an
  `Auth::User`-like record; now takes an `identity_id` integer.
  Callers that passed a record need to pass `record.id` instead.
- Notifications subscribers re-target Identity/Account, not host
  User:
  - `Notifications::AuthSubscriber` reads `identity_id` from the
    `identity.signed_up.auth` event payload.
  - `Notifications::BillingSubscriber` resolves the owner by reading
    `Billing.configuration.billable_class` (default
    `Accounts::Account`) and looking up the row by `account_id`
    carried on the billing event payload.
- `Notifications::PreferencesController` reads/writes
  `notification_preferences.identity_id` (renamed from `user_id`).
- `Notifications::NotificationsController` and
  `Notifications::NotificationChannel` resolve the recipient via
  `Auth::Current.identity`, with a legacy `current_user` fallback
  for hosts that maintain a domain User.
- `Billing.configuration.billable_class` defaults to
  `"Accounts::Account"` (was `"User"`). The engine constantizes
  lazily so hosts can flip this at runtime.
- Auth engine event names renamed:
  - `user.signed_up.auth`     → `identity.signed_up.auth`
  - `user.signed_in.auth`     → `identity.signed_in.auth`
  - `user.signed_out.auth`    → `identity.signed_out.auth`
  Event payload keys renamed: `user_id:` → `identity_id:`.
- Teams engine event names renamed:
  - `team.member_added.teams`   → `team.member_joined.teams`
  - `team.member_removed.teams` → `team.member_left.teams`
- Drop host `User` model from the canonical demo. Hosts that want
  a domain-specific User keep their own; pure SaaS hosts don't need
  one.

#### Fixed

- `Seams/NoCrossEngineModelAccess` cop relaxed: every engine ships
  its own `<Engine>::Current` namespace, and these per-request
  state holders are intentionally readable from any engine. The
  cop now treats `Current` as a framework-level constant and
  exempts it from the boundary rule. Documented in
  `doc/CURRENT_ATTRIBUTES.md` and inline in the cop's docstring.
- `Teams::AccountScoped` now references `Teams::Current.team`
  (previously a bare `Current.team` that resolved to nothing
  inside `module Teams` — silently making the default_scope a
  no-op for every host that didn't define a top-level `Current`).
- `Teams::Authorization`, `TeamsController#current_identity_id`,
  and `InvitationsController#current_identity_id` now reference
  `Auth::Current.identity` (previously a bare `Current.identity`
  that resolved to nothing — silently 403-ing every team
  membership check).
- `Notifications::PreferencesController` queries
  `identity_id` (was `user_id`, which the migration never
  created — every GET / PATCH was raising
  `ActiveRecord::StatementInvalid`).
- `Core::HasCurrentAttributes#resolve_current_user` now reads
  `Auth::Current.identity` first (with a `current_identity` and
  `current_user` fallback chain for hosts that ship a domain
  User). Previously fell through to `current_user` only, which
  the canonical Wave-9 host doesn't expose, so
  `Core::Current.user` was always nil and `Core::Auditable` wrote
  `actor_id = nil` on every audit row.
- `Core::HasCurrentAttributes#resolve_current_team` no longer
  reaches into `Teams::Team` directly; reads `Teams::Current.team`
  instead. Inverts the dependency direction: teams may include
  core's concerns, but core must not know about teams' models.
  Hosts that want a different binding (e.g. URL `params[:team_id]`)
  override the method.
- `Accounts::AccountScoped` is now fail-closed: when
  `Accounts::Current.account` is unset, the default_scope returns
  no rows (was: returned every row across every tenant — the
  canonical multi-tenant data-leak bug). New `with_no_account_scope`
  class method as the documented opt-out for seed scripts and
  platform-admin tooling. Same treatment for `Teams::AccountScoped`.
- `accounts_memberships` migration: partial unique index over
  `(account_id) WHERE role = 'system'` enforces the documented
  invariant of EXACTLY ONE system actor per Account at the DB
  level. Postgres treats NULLs as distinct in unique indexes, so
  the existing `(account_id, identity_id)` compound index didn't
  prevent two `(account_id, NULL)` system rows.
- `Notifications::Notification#owner_id` is now a `string`
  column (was bigint). Holds both bigint Identity IDs and UUID
  Account IDs simultaneously — necessary now that the
  BillingSubscriber addresses notifications at the
  `Accounts::Account` (UUID PK).
- `Accounts::Engine` and `Teams::Engine` raise a clear
  `[seams ...] missing required cross-engine dependency` error
  at boot when their required peer (auth) isn't installed.
  Previously failed silently at first query.
- Notifications and Accounts dummy schemas align on the
  `auth_identities` shape (text email + password_digest + staff
  flag + partial staff index).
- Removed dead `User < ApplicationRecord` model from the core
  engine's dummy app — the auditable spec stubs its own `Article`
  via `stub_const`; nothing else referenced the User class.

### Pre-Wave-9 history

Waves 1–8 of the seams gem are summarised below. Detailed
per-commit history is in the git log; the published gem version
will be 0.9.0 covering Waves 1–9 cumulatively.

- **Wave 8** — Per-engine spec coverage harmonised; 4-agent audit
  fixes; `bin/audit` consolidated as the single pre-push verification
  command.
- **Wave 7** — End-to-end `spec/integration_full/` smoke probe
  exercising every public seams API against a real `rails new`
  host on Postgres.
- **Wave 6** — Replaced the in-house Faraday-based Stripe client
  with the official `stripe` Ruby gem (cuts ~600 lines of adapter
  code; Stripe gem now owns gateway evolution).
- **Wave 5** — Six-agent audit + risk-fix pass: 5 RISK-rated
  defects across publisher contract, generator templates,
  notifications adapter resolution, and CI YAML drift.
- **Wave 4** — Teams engine (Phases 4A.1 + 4A.2): Team /
  Membership / Invitation models, controllers, views, mailer,
  invitation accept flow with row-lock against double-clicks.
- **Wave 3** — Integration spec verifying billing + auth +
  notifications wired together end-to-end (post-rails-new host).
- **Wave 2** — Notifications engine: STI strategies, ActionCable
  bell, TypeRegistry, --channels flag.
- **Wave 1** — Auth engine + Billing engine + Core engine + the
  custom RuboCop cops + the engine generator scaffold.

## [0.0.1]

### Added

- Initial gem skeleton: `Seams.configure`, `Seams::Configuration`, version constant.
