# Engine Catalogue

The six canonical engines that ship with seams. Each one is a
generator, not a runtime gem — your host application owns the
generated code, can edit it, and never has to wait for an upstream
release to fix a bug.

Wave 9 reworked the identity / account / team boundaries: the old
`Auth::User` (which conflated credential state and tenant
membership) is gone; in its place sit `Auth::Identity` (the human),
`Accounts::Account` (the tenant), and `Teams::Team` (the optional
collaborative grouping). The six engines below assume Wave 9
shape.

## Core

```bash
bin/seams core
```

| | |
| --- | --- |
| Models | `Core::AuditLog` (polymorphic actor + record reference) |
| Concerns (exposed) | `Core::Auditable`, `Core::SoftDeletable`, `Core::Sluggable`, `Core::TenantScoped`, `Core::HasCurrentAttributes` |
| Services | `Core::EventPublisher` (wraps `Seams::Events::Publisher.publish` with actor/team/request-id), `Core::EmailFormatValidator` |
| Migrations | `core_audit_logs` |
| Per-request | `Core::Current.user` (the actor — defaults to `Auth::Current.identity` post-Wave-9), `Core::Current.team`, `Core::Current.request_id` |
| Events emitted | `record.audited.core` (when `Core::Auditable` records a CRUD entry) |

Core ships shared primitives every other engine can build on. It
has no controllers — its job is concerns and services. The audit
table is the only model. Mount in `config/routes.rb` for
completeness; the engine has no route entries to expose.

## Auth

```bash
bin/seams auth
```

| | |
| --- | --- |
| Models | `Auth::Identity`, `Auth::Session`, plus optional `Auth::Adapter` rows for OAuth/passkey/magic-link/api-token providers |
| Concerns (exposed) | `Auth::Authenticatable` (optional, mix into a host User if present), `Auth::Authentication` (`current_identity`, `signed_in?`, `authenticate_identity!`) |
| Controllers | `SessionsController`, `RegistrationsController`, plus generated controllers per chosen adapter |
| Views | `sessions/new`, `registrations/new`, `passwords/new` |
| Migrations | `auth_identities`, `auth_sessions`, `auth_oauth_accounts`, `auth_passkey_credentials`, `auth_magic_link_grants`, `auth_api_tokens` |
| Per-request | `Auth::Current.identity` (an `ActiveSupport::CurrentAttributes`) |
| Events emitted | `identity.signed_up.auth`, `identity.signed_in.auth`, `identity.signed_out.auth`, `session.expired.auth` |
| Configuration | `session_ttl`, `cookie_name`, `after_sign_in_url`, `after_sign_out_url`, `password_min_length`, per-adapter scopes/keys |

`Auth::Authentication` is the concern your `ApplicationController`
mixes in — it exposes `current_identity`, `signed_in?`, and
`authenticate_identity!`. Post-Wave-9 the canonical host has no
domain User: hosts that maintain one mix `Auth::Authenticatable`
into it themselves.

## Accounts

```bash
bin/seams accounts
```

| | |
| --- | --- |
| Models | `Accounts::Account` (UUID PK, the tenant boundary), `Accounts::Membership` (Identity ↔ Account, role enum: owner/admin/member/system) |
| Concerns (exposed) | `Accounts::AccountScoped` (default-scope to `Accounts::Current.account`), `Accounts::Authorization` (`ensure_account_access`, `ensure_admin`, `ensure_staff`) |
| Controllers | none in Wave 9 — hosts drive their own account-creation flows; this engine is the model + concern layer |
| Migrations | `accounts`, `accounts_memberships` |
| Per-request | `Accounts::Current.account`, `Accounts::Current.membership` (auto-derived from the current Identity) |
| Events emitted | `account.created.accounts`, `account.cancelled.accounts`, `membership.created.accounts`, `membership.role_changed.accounts`, `membership.removed.accounts` |
| Configuration | `incineration_grace_period`, `system_membership_role` |

Each Account auto-creates a `system` Membership with `identity_id:
nil` so audit-log writes from background jobs always have a valid
membership to point at.

## Notifications

```bash
bin/seams notifications
```

| | |
| --- | --- |
| Adapters | `Notifications::Adapters::Abstract`, `Adapters::ActionMailer` (default), `Adapters::NullSms` (default) |
| Concern (exposed) | `Notifications::Notifiable` (`notify_email`, `notify_sms`) — mix into the recipient model (Identity, host User, etc.) |
| Models | `Notifications::Notification`, `Notifications::NotificationPreference` |
| Jobs | `DeliverEmailJob`, `DeliverSmsJob`, `CreateNotificationJob` |
| Subscribers | `AuthSubscriber` consumes `identity.signed_up.auth` and sends a welcome email; `BillingSubscriber` consumes `subscription.created.billing` / `invoice.paid.billing` and writes per-account notifications |
| Controllers | `NotificationsController` (in-app inbox + bell), `PreferencesController` (per-channel opt-in) |
| Migrations | `notifications`, `notification_preferences`, `notification_deliveries` (audit trail) |
| Events emitted | `notification.queued.notifications`, `notification.delivered.notifications`, `notification.failed.notifications` |
| Configuration | `email_adapter`, `sms_adapter`, `default_from`, `welcome_subscriber_owner_class_name` |

Notifications are addressed to a polymorphic `owner` — the canonical
demo points it at `Auth::Identity`, but a host can configure the
`BillingSubscriber.owner_class_name` (default `Accounts::Account`)
or the `AuthSubscriber.owner_class_name` (default `Auth::Identity`)
to whichever model the host wants to receive the notification.

## Billing

```bash
bin/seams billing
```

| | |
| --- | --- |
| Models | `Billing::Subscription`, `Billing::Invoice`, `Billing::WebhookEvent`, `Billing::Plan`, `Billing::Payment` |
| Gateways | `Billing::Gateways::Abstract`, `Gateways::Stripe` (default — uses the official `stripe` gem) |
| Concern (exposed) | `Billing::Billable` — auto-included into `Billing.configuration.billable_class` (default `Accounts::Account`) at boot |
| Jobs | `StartSubscriptionJob`, `CancelSubscriptionJob`, plus `Webhooks::*` handlers |
| Controllers | `WebhooksController` (POST `/billing/webhooks/stripe` with signature verification + idempotent dedupe), `CheckoutController`, `PortalController`, `SubscriptionsController`, `InvoicesController` |
| Migrations | `billing_subscriptions`, `billing_invoices`, `billing_webhook_events` (unique on `(gateway, gateway_event_id)`), `billing_plans`, `billing_payments` |
| Events emitted | `subscription.created.billing`, `subscription.updated.billing`, `subscription.canceled.billing`, `invoice.paid.billing`, `invoice.failed.billing`, `lifetime.purchased.billing` |
| Configuration | `gateway`, `api_key`, `webhook_secret`, `default_currency`, `billable_class` |

`Billing.configuration.billable_class` is a string (`"Accounts::Account"`
by default). The engine constantizes it lazily — hosts can change
the binding at runtime in development without rebooting. The
billable_class must respond to `stripe_customer_ref!(email:)`; the
`Billing::Billable` concern provides the canonical implementation.

The Stripe gateway uses these documented APIs (URLs cited inline in
the source):

| Stripe call | Docs |
| --- | --- |
| `Stripe::Subscription.create` | https://docs.stripe.com/api/subscriptions/create |
| `Stripe::Subscription.cancel` | https://docs.stripe.com/api/subscriptions/cancel |
| `Stripe::Subscription.retrieve` | https://docs.stripe.com/api/subscriptions/retrieve |
| `Stripe::Webhook.construct_event` | https://docs.stripe.com/webhooks/signatures |

The webhook controller is idempotent: every Stripe event is recorded
in `billing_webhook_events` with a unique index on
`(gateway, gateway_event_id)` so retries hit the index and
short-circuit before re-publishing to subscribers.

## Teams

```bash
bin/seams teams
```

| | |
| --- | --- |
| Models | `Teams::Team` (auto-slug), `Teams::Membership` (joins Identity directly to Team; roles: owner/admin/member), `Teams::Invitation` (token + TTL) |
| Concerns (exposed) | `Teams::AccountScoped` (default-scope to `Teams::Current.team`), `Teams::Authorization` (`require_team_admin!`, `require_team_member!`) |
| Controllers | `TeamsController`, `MembershipsController`, `InvitationsController` |
| Migrations | `teams`, `team_memberships`, `team_invitations` |
| Per-request | `Teams::Current.team` |
| Events emitted | `team.created.teams`, `team.member_joined.teams`, `team.member_left.teams`, `invitation.sent.teams`, `invitation.accepted.teams` |
| Configuration | `invitation_ttl`, `max_members_per_team` |

Wave 9 model: Teams is a peer to Accounts (not nested). A
`Teams::Membership` joins `Auth::Identity` directly to a
`Teams::Team`. The host-User `Teamable` concern is gone — Wave 9
dropped the canonical demo's host User, so there's nowhere to mix
it into.

The accept route is top-level (`POST /invitations/accept/:token`) so
the email link doesn't leak the team_id and is short enough to
share. The accept action locks the invitation row and short-circuits
on already-accepted, so a double-clicked link redirects gracefully.

## Pulling them together

A real B2B SaaS using all six:

```ruby
# config/routes.rb
mount Core::Engine,           at: "/"            # no public routes — mount for completeness
mount Auth::Engine,           at: "/auth"
mount Accounts::Engine,       at: "/accounts"
mount Notifications::Engine,  at: "/notifications"
mount Billing::Engine,        at: "/billing"
mount Teams::Engine,          at: "/teams"
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Auth::Authentication               # 1. sets Auth::Current.identity
  include Core::HasCurrentAttributes         # 2. reads Auth::Current.identity (depends on 1)
  include Accounts::Authorization            # 3. reads Auth::Current.identity (depends on 1)
  before_action :authenticate_identity!
end
```

Order matters: `Auth::Authentication` must be included BEFORE
`Core::HasCurrentAttributes` and `Accounts::Authorization` so
`Auth::Current.identity` is bound before the other engines read it.
See [doc/CURRENT_ATTRIBUTES.md](CURRENT_ATTRIBUTES.md) for the full
cascade order.

Hosts that want a domain-specific User can keep one and mix the
optional concerns into it:

```ruby
# app/models/user.rb (optional, post-Wave-9 — only if your domain
# needs a User on top of Auth::Identity, e.g. for legacy data or
# for a custom display name / avatar)
class User < ApplicationRecord
  include Auth::Authenticatable        # adds the credentials shim
  include Notifications::Notifiable    # adds notify_email / notify_sms
  include Billing::Billable            # if billing is account-scoped
end
```

That's a Bullet-Train-class app surface in five `bin/seams`
commands. The code is yours; nothing is hidden behind a gem.
