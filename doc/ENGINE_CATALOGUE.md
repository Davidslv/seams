# Engine Catalogue

The four canonical engines that ship with Seams Phase 1–4. Each one
is a generator, not a runtime gem — your host application owns the
generated code, can edit it, and never has to wait for an upstream
release to fix a bug.

## Auth

```bash
bin/seams auth
```

| | |
| --- | --- |
| Models | `Auth::User`, `Auth::Session` |
| Concerns (exposed) | `Auth::Authenticatable`, `Auth::Authentication` |
| Controllers | `SessionsController`, `RegistrationsController` |
| Views | `sessions/new`, `registrations/new` |
| Migrations | `auth_users`, `auth_sessions` |
| Events emitted | `user.signed_up.auth`, `user.signed_in.auth`, `user.signed_out.auth`, `session.expired.auth` |
| Configuration | `session_ttl`, `cookie_name`, `after_sign_in_url`, `after_sign_out_url`, `password_min_length` |

`Auth::Authentication` is the concern your `ApplicationController`
mixes in — `current_user`, `signed_in?`, `authenticate_user!`.

## Notifications

```bash
bin/seams notifications
```

| | |
| --- | --- |
| Adapters | `Notifications::Adapters::Abstract`, `Adapters::ActionMailer` (default), `Adapters::NullSms` (default) |
| Concern (exposed) | `Notifications::Notifiable` (`notify_email`, `notify_sms`) |
| Jobs | `DeliverEmailJob`, `DeliverSmsJob` |
| Subscriber | `AuthSubscriber` consumes `user.signed_up.auth` and sends a welcome email |
| Migration | `notification_deliveries` (audit trail) |
| Events emitted | `notification.queued.notifications`, `notification.delivered.notifications`, `notification.failed.notifications` |
| Configuration | `email_adapter`, `sms_adapter`, `default_from` |

The default ActionMailer adapter dispatches via a generated
`Notifications::TransactionalMailer`. Swap the adapter by setting
`config.email_adapter` to a Mailgun/SendGrid/etc adapter.

## Billing

```bash
bin/seams billing
```

| | |
| --- | --- |
| Models | `Billing::Subscription`, `Billing::Invoice`, `Billing::WebhookEvent` |
| Gateways | `Billing::Gateways::Abstract`, `Gateways::Stripe` (default) |
| Concern (exposed) | `Billing::Billable` (`start_subscription!`, `cancel_subscription!`) |
| Jobs | `StartSubscriptionJob`, `CancelSubscriptionJob` |
| Webhook controller | POST `/billing/webhooks/stripe` with signature verification + idempotent dedupe |
| Migrations | `billing_subscriptions`, `billing_invoices`, `billing_webhook_events` (unique on `(gateway, gateway_event_id)`) |
| Events emitted | `subscription.created.billing`, `subscription.updated.billing`, `subscription.canceled.billing`, `invoice.paid.billing`, `invoice.failed.billing` |
| Configuration | `gateway`, `api_key`, `webhook_secret`, `default_currency` |

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
| Models | `Teams::Team` (auto-slug), `Teams::Membership` (roles: owner/admin/member), `Teams::Invitation` (token + TTL) |
| Concerns (exposed) | `Teams::Teamable` (`teams`, `member_of?`, `admin_of?`, `owner_of?`), `Teams::Authorization` (`require_team_admin!`) |
| Controllers | `TeamsController`, `MembershipsController`, `InvitationsController` |
| Migrations | `teams`, `team_memberships`, `team_invitations` |
| Events emitted | `team.created.teams`, `team.member_added.teams`, `team.member_removed.teams`, `invitation.sent.teams`, `invitation.accepted.teams` |
| Configuration | `invitation_ttl`, `max_members_per_team` |

The accept route is top-level (`POST /invitations/accept/:token`) so
the email link doesn't leak the team_id and is short enough to share.
The accept action locks the invitation row and short-circuits on
already-accepted, so a double-clicked link redirects gracefully.

## Pulling them together

A real B2B SaaS using all four:

```ruby
# config/routes.rb
mount Auth::Engine,           at: "/auth"
mount Notifications::Engine,  at: "/notifications"
mount Billing::Engine,        at: "/billing"
mount Teams::Engine,          at: "/teams"
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Auth::Authenticatable
  include Notifications::Notifiable
  include Billing::Billable
  include Teams::Teamable
end
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Auth::Authentication
  before_action :authenticate_user!
end
```

That's a Bullet-Train-class app surface in four `bin/seams` commands.
The code is yours; nothing is hidden behind a gem.
