# Insertion-points catalogue — canonical engines

This catalogue enumerates every insertion-point marker the six
canonical engines ship after the Wave 10 Phase 2A retrofit. Every
marker on this list is a **public contract**: a follow-up generator
may target it, a host may rely on it, and the Phase 2A retrofit must
place each marker exactly once at the location described.

The format is documented in [`INSERTION_POINTS.md`](INSERTION_POINTS.md).
This file is the canonical list; the catalogue is what Phase 2A
(retrofit), Phase 2B (eject CLI), and Phase 2C (showcase follow-up
generator) **all** consume.

Marker count summary:

| Engine | Markers | Concentration |
|---|---|---|
| core | 2 (+1 deferred) | engine.rb (configuration.rb deferred to Wave 12) |
| auth | 7 | engine.rb, routes.rb, configuration.rb |
| accounts | 4 | engine.rb, configuration.rb |
| teams | 5 | engine.rb, routes.rb, configuration.rb |
| notifications | 7 | engine.rb, configuration.rb, notifiable.rb, type registry |
| billing | 7 | engine.rb, routes.rb, configuration.rb, webhook router |
| admin | 5 | engine.rb, routes.rb, configuration.rb |

Post-Wave-11A: 37 markers shipping in templates; 1 deferred
(`core.configuration.attributes`) pending Wave 12. Phase 2A
(Wave 10) shipped 32 markers across the canonical six engines;
Wave 11A added 5 more on the new admin engine.

Every marker biases toward one of three high-leverage areas: **events**
(register one more), **routes** (add one more endpoint), or
**registry-style configuration** (add one more entry to a hash, array,
or class-name list). Anything that doesn't fit those three shapes is
deliberately omitted — the eject CLI handles non-extensible needs.

---

## core engine

### core.engine.events

- **File:** `engines/core/lib/core/engine.rb`
- **Inside:** the `initializer "core.register_events"` block, after the
  `record.audited.core` registration.
- **Purpose:** follow-up generators that emit new core events
  (e.g. `record.soft_deleted.core`, `record.restored.core`) register
  them here.

### core.engine.initializers

- **File:** `engines/core/lib/core/engine.rb`
- **Inside:** the engine class body, after the `append_migrations`
  initializer, before the closing `end`.
- **Purpose:** follow-up generators that need to add their own
  `initializer "..." do ... end` blocks (e.g. wire a new audit
  subscriber, register a new validator) declare them here so the
  engine boot order is auditable in one place.

### core.configuration.attributes

- **Status:** TODO — deferred to Wave 12 (polish pass adds opinionated
  config initializers across engines). Phase 2A skipped this marker
  because shipping a Configuration class core doesn't currently use
  just to host a marker would push framework code into the engine
  ahead of a real consumer. When Wave 12 lands the Configuration
  class with at least one knob, place this marker inside the class
  body.
- **File:** `engines/core/lib/core/configuration.rb` (planned —
  Wave 12; core currently has no Configuration class).
- **Inside:** the `Configuration` class body.
- **Purpose:** follow-up generators that add new configuration knobs
  (e.g. `audit_actor_resolver = ->(record) { ... }`) splice their
  `attr_accessor` here.

---

## auth engine

### auth.engine.events

- **File:** `engines/auth/lib/auth/engine.rb`
- **Inside:** the `initializer "auth.register_events"` block, after the
  `api_token.revoked.auth` registration.
- **Purpose:** follow-up generators that emit new auth events register
  them here. Examples: `seams:auth:add_passkeys` registers
  `identity.passkey_added.auth`; `seams:auth:add_magic_links` registers
  `identity.magic_link_sent.auth`.

### auth.engine.initializers

- **File:** `engines/auth/lib/auth/engine.rb`
- **Inside:** the engine class body, after the `append_migrations`
  initializer.
- **Purpose:** follow-up generators that need their own initializer
  block (e.g. attaching a subscriber on an existing auth event)
  declare it here.

### auth.routes.before_session

- **File:** `engines/auth/config/routes.rb`
- **Inside:** the `Auth::Engine.routes.draw` block, before the
  `resource :session` declaration.
- **Purpose:** follow-up generators that ship sign-in alternatives
  (passkeys, magic links, SSO redirects) splice their `resource` /
  `get` / `post` declarations here. Spliced *before* the session
  resource so the new flows take routing precedence over the canonical
  password sign-in.

### auth.routes.after_oauth

- **File:** `engines/auth/config/routes.rb`
- **Inside:** the `Auth::Engine.routes.draw` block, after the
  `scope "/oauth/:provider"` block, before the closing `end`.
- **Purpose:** follow-up generators that add NEW route surfaces — API
  token management UI, social-link admin, etc. — splice their resource
  declarations here.

### auth.configuration.attributes

- **File:** `engines/auth/lib/auth/configuration.rb`
- **Inside:** the `Configuration` class body, immediately after the
  `attr_accessor` line.
- **Purpose:** follow-up generators that add new top-level
  configuration knobs (e.g. `passkey_rp_id`, `magic_link_ttl`) declare
  the `attr_accessor` here.

### auth.configuration.defaults

- **File:** `engines/auth/lib/auth/configuration.rb`
- **Inside:** the `initialize` method body, after the
  `@oauth_providers = {}` assignment, before the closing `end`.
- **Purpose:** the matching half of `auth.configuration.attributes`.
  Splices `@new_knob = sensible_default` so the host doesn't have to
  set it explicitly.

### auth.configuration.oauth_providers

- **File:** `engines/auth/lib/auth/configuration.rb`
- **Inside:** the `@oauth_providers = {}` literal — Phase 2A converts
  the literal to multi-line so the marker can sit inside the hash.
- **Purpose:** follow-up generators that ship pre-wired OAuth providers
  (`seams:auth:add_oauth_provider linkedin`, etc.) splice a
  `linkedin: { adapter: "Auth::OAuth::Linkedin", ... }` entry here.
  (Note: the showcase generator camel-cases via simple capitalize per
  word, matching `Github` and `Google` — not Zeitwerk's inflector.)

---

## accounts engine

### accounts.engine.events

- **File:** `engines/accounts/lib/accounts/engine.rb`
- **Inside:** the `initializer "accounts.register_events"` block,
  after the `membership.removed.accounts` registration.
- **Purpose:** follow-up generators that emit new accounts events
  (`account.upgraded.accounts`, `account.suspended.accounts`)
  register them here.

### accounts.engine.initializers

- **File:** `engines/accounts/lib/accounts/engine.rb`
- **Inside:** the engine class body, after the `append_migrations`
  initializer, before the `config.after_initialize` block.
- **Purpose:** follow-up generators that need their own initializer
  block declare it here, ahead of the cross-engine dependency check.

### accounts.configuration.attributes

- **File:** `engines/accounts/lib/accounts/configuration.rb`
- **Inside:** the `Configuration` class body, after the
  `attr_accessor` line.
- **Purpose:** follow-up generators add knobs (e.g.
  `account_owner_role`, `default_account_locale`) here.

### accounts.configuration.defaults

- **File:** `engines/accounts/lib/accounts/configuration.rb`
- **Inside:** the `initialize` method, after the
  `@after_account_create_url` assignment.
- **Purpose:** matches `accounts.configuration.attributes` — defaults
  for the new attributes go here.

---

## teams engine

### teams.engine.events

- **File:** `engines/teams/lib/teams/engine.rb`
- **Inside:** the `initializer "teams.register_events"` block, after
  the `invitation.accepted.teams` registration.
- **Purpose:** follow-up generators that emit new teams events
  (`team.archived.teams`, `team.transferred.teams`,
  `invitation.revoked.teams`) register them here.

### teams.engine.subscribers

- **File:** `engines/teams/lib/teams/engine.rb`
- **Inside:** the `config.after_initialize` block, after the
  `Teams::InvitationSubscriber.attach!` line.
- **Purpose:** follow-up generators that ship subscribers
  (`Teams::AccountSubscriber.attach!` for account-level invitations,
  etc.) splice their `attach!` calls here.

### teams.routes.before_teams

- **File:** `engines/teams/config/routes.rb`
- **Inside:** the `Teams::Engine.routes.draw` block, before the
  `resources :teams` declaration.
- **Purpose:** follow-up generators that add admin-only or token-only
  routes splice them here.

### teams.routes.after_invitations

- **File:** `engines/teams/config/routes.rb`
- **Inside:** the `Teams::Engine.routes.draw` block, after the
  `post "/invitations/accept/:token"` line, before the closing `end`.
- **Purpose:** follow-up generators that add new top-level team routes
  (transfer, archive, etc.) splice them here.

### teams.configuration.attributes

- **File:** `engines/teams/lib/teams/configuration.rb`
- **Inside:** the `Configuration` class body, after the existing
  `attr_writer` line.
- **Purpose:** follow-up generators add knobs (e.g.
  `slug_generator`, `archive_grace_period`) here.

---

## notifications engine

### notifications.engine.events

- **File:** `engines/notifications/lib/notifications/engine.rb`
- **Inside:** the `initializer "notifications.register_events"` block,
  after the `notification.failed.notifications` registration.
- **Purpose:** follow-up generators that ship new delivery semantics
  (`notification.bounced.notifications`,
  `notification.preferences_updated.notifications`) register them here.

### notifications.engine.subscribers

- **File:** `engines/notifications/lib/notifications/engine.rb`
- **Inside:** the `config.after_initialize` block, after the
  `Notifications::AuthSubscriber.attach!` line, before the
  `BillingSubscriber.attach! if defined?(...)` line.
- **Purpose:** follow-up generators that ship subscribers for new
  cross-engine events (e.g. `Notifications::TeamsSubscriber`) splice
  their `attach!` calls here.

### notifications.configuration.attributes

- **File:** `engines/notifications/lib/notifications/configuration.rb`
- **Inside:** the `Configuration` class body, after the existing
  `attr_accessor` line.
- **Purpose:** follow-up generators add knobs (push adapter,
  webhook adapter, in-app retention, etc.) here.

### notifications.configuration.defaults

- **File:** `engines/notifications/lib/notifications/configuration.rb`
- **Inside:** the `initialize` method body, after the `@default_from`
  assignment.
- **Purpose:** matches `notifications.configuration.attributes` —
  defaults for the new attributes.

### notifications.notifiable.strategies

- **File:** `engines/notifications/lib/notifications/concerns/notifiable.rb`
- **Inside:** the `STRATEGY_CLASSES` hash literal, before the closing
  `}.freeze`.
- **Purpose:** follow-up generators that ship new delivery strategies
  (`push:`, `webhook:`, `slack:`) splice their
  `strategy_key: "Notifications::Strategies::ClassName"` entry here.
  This is the canonical example of a registry-style insertion point —
  the marker sits inside the literal, not adjacent to it.

### notifications.type_registry.defaults

- **File:** `engines/notifications/lib/notifications.rb`
- **Inside:** the `seed_default_types!` method body, after the last
  `TypeRegistry.register("billing.lifetime_purchased", ...)` call.
- **Purpose:** follow-up generators that ship new cross-engine
  notification types (`teams.invitation_received`,
  `auth.password_reset`, etc.) splice their
  `TypeRegistry.register(...)` call here so the host gets sane
  default channels + display names.

### notifications.routes.after_preferences

- **File:** `engines/notifications/config/routes.rb`
- **Inside:** the `Notifications::Engine.routes.draw` block, after the
  `resource :preferences` line.
- **Purpose:** follow-up generators that add admin-side notification
  routes (digest scheduling, channel-specific opt-outs) splice their
  resources here.

---

## billing engine

### billing.engine.events

- **File:** `engines/billing/lib/billing/engine.rb`
- **Inside:** the `initializer "billing.register_events"` block, after
  the `lifetime.revoked.billing` registration.
- **Purpose:** follow-up generators that ship new billing events
  (`subscription.discount_applied.billing`,
  `dispute.created.billing`, etc.) register them here.

### billing.engine.initializers

- **File:** `engines/billing/lib/billing/engine.rb`
- **Inside:** the engine class body, after the `append_migrations`
  initializer, before the `config.to_prepare` block.
- **Purpose:** follow-up generators that need their own initializer
  block (custom Billable include logic, gateway feature-flag wiring)
  declare it here.

### billing.routes.before_webhook

- **File:** `engines/billing/config/routes.rb`
- **Inside:** the `Billing::Engine.routes.draw` block, before the
  `post "/webhooks/stripe"` line.
- **Purpose:** follow-up generators that add new gateway-flow routes
  (Adyen webhook, Paddle webhook, alternative checkout) splice their
  routes here, ahead of the existing Stripe webhook.

### billing.configuration.attributes

- **File:** `engines/billing/lib/billing/configuration.rb`
- **Inside:** the `Configuration` class body, after the existing
  `attr_accessor` lines, before the `initialize` method.
- **Purpose:** follow-up generators add knobs (proration mode, dunning
  retries, tax adapters) here.

### billing.configuration.defaults

- **File:** `engines/billing/lib/billing/configuration.rb`
- **Inside:** the `initialize` method body, after the
  `@billable_class = "Accounts::Account"` assignment.
- **Purpose:** matches `billing.configuration.attributes` — defaults
  for the new attributes go here.

### billing.event_router.handlers

- **File:** `engines/billing/app/services/billing/webhooks/event_router.rb`
- **Inside:** the `HANDLERS` hash literal, before the closing `}`.
- **Purpose:** follow-up generators that ship handlers for additional
  Stripe events (`customer.tax_id.created`,
  `payment_method.attached`) splice their
  `"event.type" => "Billing::Webhooks::Handlers::ClassName"` entry
  here.

### billing.gateways.adapters

- **File:** `engines/billing/lib/billing.rb`
- **Inside:** the top-of-file `require "billing/gateways/..."` cluster,
  after the existing `require "billing/gateways/stripe"` line.
- **Purpose:** follow-up generators that ship pre-wired gateway
  adapters (`seams:billing:add_gateway paddle`) splice their
  `require "billing/gateways/paddle"` line here so the gateway class
  is available for `Billing.configuration.gateway` to constantize.

---

---

## admin engine (Wave 11A)

### admin.engine.events

- **File:** `engines/admin/lib/admin/engine.rb`
- **Inside:** the `initializer "admin.register_events"` block.
- **Purpose:** Phase 1 ships no admin events; Phase 3 adds
  `admin.action.taken.admin` when the audit-log auto-write lands.
  Follow-up generators (`seams:admin:add_dashboard <model>`) that emit
  new admin events register them here.

### admin.routes.before_resources

- **File:** `engines/admin/config/routes.rb`
- **Inside:** the `Seams::Admin::Engine.routes.draw` block, before the
  Phase 2 dashboard `resources` declarations.
- **Purpose:** follow-up generators that ship admin sections needing
  routing precedence (impersonation entry points, bulk-action
  endpoints) splice their routes here.

### admin.routes.after_resources

- **File:** `engines/admin/config/routes.rb`
- **Inside:** the `Seams::Admin::Engine.routes.draw` block, after the
  Phase 2 dashboard resources, before the closing `end`.
- **Purpose:** follow-up generators that add NEW route surfaces (custom
  collection routes, JSON-only endpoints, status-page integrations)
  splice their routes here.

### admin.configuration.attributes

- **File:** `engines/admin/lib/admin/configuration.rb`
- **Inside:** the `Configuration` class body, after the
  `attr_accessor` line listing the four Phase 1 knobs.
- **Purpose:** follow-up generators that add knobs (impersonation
  audit logger, session timeout, custom theme paths, etc.) declare
  their `attr_accessor` here.

### admin.configuration.defaults

- **File:** `engines/admin/lib/admin/configuration.rb`
- **Inside:** the `initialize` method body, after the four Phase 1
  default assignments.
- **Purpose:** matches `admin.configuration.attributes` — defaults
  for the new attributes go here.

---

## Total: 38 markers across 7 engines

Distribution:

- **events:** 7 (one per engine)
- **initializers:** 4 (core, auth, accounts, billing)
- **subscribers:** 2 (teams, notifications)
- **routes:** 8 (auth × 2, teams × 2, notifications, billing, admin × 2)
- **configuration attributes:** 7 (one per engine that has Configuration)
- **configuration defaults:** 6
- **registry-style:** 4 (auth.configuration.oauth_providers,
  notifications.notifiable.strategies, notifications.type_registry.defaults,
  billing.event_router.handlers, billing.gateways.adapters)

Phase 2A's job is to place each marker exactly once at the documented
location, with no other template change. Phase 2C's job is to ship a
showcase follow-up generator that targets ONE of these markers
end-to-end. Phase 2B's eject CLI uses the marker list as its diagnostic
source: `bin/seams resolve --list-markers <engine>` reads this catalogue
to verify the engine is on a current Wave 10 retrofit.
