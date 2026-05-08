# Notifications

> In-app + email + SMS notifications, scheduled or recurring, for a
> Seams-powered host. STI delivery strategies, ice_cube schedules,
> swappable adapters.

**Requires:** soft requirements only.
- The `auth` engine: `Notifications::AuthSubscriber.owner_class_name`
  resolves the recipient via `Auth::Identity` by default.
- The `accounts` and/or `billing` engines: the `BillingSubscriber`
  resolves the recipient via `Billing.configuration.billable_class`
  (default `"Accounts::Account"`). Without billing the subscriber
  attaches no handlers; without accounts, set `billable_class` to
  whatever class the host uses for the billing recipient.

## Model

`Notifications::Notification` is an STI base. Three concrete
subclasses, each implementing its own `#dispatch!`:

| Class                                | Channel | Dispatches via                                            |
| ---                                  | ---     | ---                                                       |
| `Notifications::Strategies::InApp`   | in-app  | ActionCable broadcast to the per-recipient channel        |
| `Notifications::Strategies::Email`   | email   | `Notifications.email_adapter.deliver(notification:)`      |
| `Notifications::Strategies::Sms`     | sms     | `Notifications.sms_adapter.deliver(notification:)`        |

Every Notification belongs to an `owner` (polymorphic), names a
`template` (an ERB filename), and carries an ice_cube schedule
serialised to a `schedule_data` jsonb column. `next_delivery_at` is
the indexed cache the recurring sweeper reads from.

### Polymorphic owner

The Notification's `owner` is polymorphic — an `owner_type` /
`owner_id` pair. After Wave 9 the canonical "human" is
`Auth::Identity`, but **any** ActiveRecord model can own
notifications: an Account (the tenant), a Membership (Identity in
Account), or a host-defined model. Hosts mix and match without any
schema changes:

```ruby
Notifications::Notification.create!(owner: identity,    template: "welcome")
Notifications::Notification.create!(owner: account,     template: "billing/invoice_paid")
Notifications::Notification.create!(owner: membership,  template: "team/role_changed")
Notifications::Notification.create!(owner: project,     template: "project/deadline")
```

## Scheduling

The examples below assume the host has included
`Notifications::Notifiable` on `Auth::Identity` (or another model)
to pick up the `#notify` helper — see "Notifiable is optional"
below. Hosts that skip the concern call
`Notifications::Notification.create!(owner: ..., template: ...)`
directly.

```ruby
# Send right now (default if you skip schedule_config)
identity.notify(strategy: :email, template: "welcome")

# Send in 24h
identity.notify(
  strategy: :email,
  template: "trial_ending",
  schedule_config: { starts_at: 1.day.from_now, frequency: "once" }
)

# Weekly digest
identity.notify(
  strategy: :email,
  template: "weekly_digest",
  schedule_config: {
    starts_at: Time.current.next_week,
    frequency: "weekly",
    interval:  1
  }
)

# Monthly, capped at 12 occurrences
identity.notify(
  strategy: :email,
  template: "anniversary",
  schedule_config: {
    starts_at: Time.current,
    frequency: "monthly",
    count:     12
  }
)
```

Or assemble the schedule yourself for richer rules (exception dates,
"first Tuesday of the month", etc.):

```ruby
sched = IceCube::Schedule.new(Time.current)
sched.add_recurrence_rule(
  IceCube::Rule.weekly.day(:monday).hour_of_day(9)
)
notification = identity.notifications.create!(
  type:     "Notifications::Strategies::Email",
  template: "monday_morning"
)
notification.schedule = sched
notification.save!
```

## Sweeper

`Notifications::SendDueNotificationsJob` is a plain `ApplicationJob`
that finds every `Notification.due` and enqueues a per-row
`SendNotificationJob`. Wire it into your queue's recurring
scheduler. With Rails 8's Solid Queue:

```yaml
# config/recurring.yml
production:
  notifications_dispatcher:
    class: Notifications::SendDueNotificationsJob
    schedule: every minute
```

## Events emitted

| Event name | Payload | Emitted when |
| --- | --- | --- |
| `notification.queued.notifications`     | `{ id:, type:, owner_type:, owner_id: }`  | `Notification#send!` begins |
| `notification.delivered.notifications`  | `{ id:, type:, owner_type:, owner_id: }`  | `dispatch!` succeeded + Delivery recorded |
| `notification.failed.notifications`     | `{ id:, type:, error: }`                  | `dispatch!` raised |

Owner reference uses `owner_type` + `owner_id` (the polymorphic
columns) — Notifications are addressed at any model, so subscribers
need both halves to resolve a recipient.

## Events consumed

| Event name | Subscriber | What it does |
| --- | --- | --- |
| `identity.signed_up.auth` | `Notifications::AuthSubscriber` | Creates an InApp + Email welcome notification owned by the Auth::Identity (subject to NotificationPreference). |
| `subscription.created.billing`  | `Notifications::BillingSubscriber` | InApp notification, template `billing/subscription_started`. |
| `subscription.updated.billing`  | `Notifications::BillingSubscriber` | InApp notification, template `billing/subscription_updated`. |
| `subscription.canceled.billing` | `Notifications::BillingSubscriber` | InApp notification, template `billing/subscription_canceled`. |
| `invoice.paid.billing`          | `Notifications::BillingSubscriber` | InApp notification, template `billing/invoice_paid`. |
| `invoice.failed.billing`        | `Notifications::BillingSubscriber` | InApp notification, template `billing/invoice_failed`. |
| `lifetime.granted.billing`      | `Notifications::BillingSubscriber` | InApp notification, template `billing/lifetime_granted`. |
| `lifetime.purchased.billing`    | `Notifications::BillingSubscriber` | InApp notification, template `billing/lifetime_purchased`. |

The Billing subscriber resolves the recipient by reading
`Billing.configuration.billable_class` (default `Accounts::Account`)
and looking up the row by `account_id` carried on the billing
event payload. It only attaches when `Billing::Engine` is loaded.
Hosts that want a different recipient (e.g. a domain User on top
of `Auth::Identity`) override `Billing.configuration.billable_class`
in their initializer.

### Cross-engine dependencies

The subscribers in this engine resolve owners by reaching into other
engines' models. This dependency direction is intentional but worth
documenting explicitly:

| Subscriber | Reaches into | Why |
| --- | --- | --- |
| `Notifications::AuthSubscriber`    | `Auth::Identity`                              | resolve owner from `identity_id` payload (the human who just signed up) |
| `Notifications::BillingSubscriber` | `Billing.configuration.billable_class` (default `Accounts::Account`) | resolve owner from `account_id` payload — the tenant the subscription / invoice / lifetime grant belongs to |
| `Notifications::CreateNotificationJob` | any AR class                              | resolve owner via `owner_class.constantize.find_by(id: owner_id)` |

If you want a different owner for the welcome notification (an
Account, a Membership, a host User), copy
`engines/notifications/app/subscribers/notifications/auth_subscriber.rb`
into your host, change `OWNER_CLASS_NAME`, then re-attach in
`config/initializers/notifications.rb`. The Notification table is
fully polymorphic — no schema changes needed.

### Subscribers enqueue, never block the publisher

`Seams::Events::Publisher` runs subscribers synchronously in the
publisher's thread. Every subscriber here therefore enqueues
`Notifications::CreateNotificationJob` (which does the actual DB
write + send) rather than calling `Notification.create!` inline.
Publishing should never wait on the bus.

## Exposed concerns

| Concern | Purpose |
| --- | --- |
| `Notifications::Notifiable` | OPTIONAL. Mix into any model that should expose `notifications` + `#notify(strategy:, template:, schedule_config:)` sugar. |

### Notifiable is optional

The `Notifications::Notification` row is polymorphic — every record
has an `owner_type` / `owner_id` pair, and `create!(owner: anything, template: ...)`
works with any ActiveRecord model. The `Notifiable` concern is just
sugar for the receiving side; you don't need it.

Three include patterns hosts can pick from:

1. **Wire onto `Auth::Identity`** (canonical post-Wave-9 host —
   the "human" is `Auth::Identity`, no host User):

   ```ruby
   # config/initializers/notifications.rb
   Rails.application.config.to_prepare do
     Auth::Identity.include(Notifications::Notifiable)
   end
   ```

2. **Wire onto a host User class** (hosts that keep their own User
   alongside `Auth::Identity`):

   ```ruby
   class User < ApplicationRecord
     include Notifications::Notifiable
   end
   ```

3. **Don't include the concern at all.** Use
   `Notifications::Notification.create!(owner: ..., template: ...)`
   directly — the polymorphic owner column accepts any AR record.

Hosts including the concern on a non-Identity class (an Account, a
host User keyed by a different `identity_id`, etc.) should override
`#notification_preference_identity_id` so preference lookups key off
the right Identity.

## Adapters

| Interface | Default                                  | Override via                                                                  |
| ---       | ---                                      | ---                                                                           |
| Email     | `Notifications::Adapters::ActionMailer`  | `Notifications.configure { \|c\| c.email_adapter = "MyApp::MailgunAdapter" }` |
| SMS       | `Notifications::Adapters::NullSms`       | `Notifications.configure { \|c\| c.sms_adapter   = "MyApp::TwilioAdapter" }`  |

To add a new adapter, subclass `Notifications::Adapters::Abstract`
and implement `#deliver(notification:)`. The adapter receives the
full Notification so it can read `recipient`, `template`,
`rendered_content`, `owner` — whatever the gateway needs.

## Templates

Notifications are rendered via ERB files looked up in this order:

1. `app/views/notifications/templates/<name>.erb` in the host
2. `app/views/notifications/templates/<name>.erb` in the engine

Drop a file in your host to override. The notification is exposed in
the template via the local variable `notification` — use
`notification.owner`, `notification.recipient`, etc.

## Preferences

`Notifications::NotificationPreference` lets an Identity opt out by
channel + notification_type. The table keys off `identity_id` (not
the polymorphic Notification owner) — channel preferences live with
the human, not with whatever model a notification happens to be
addressed at:

```ruby
Notifications::NotificationPreference.enabled?(
  identity_id: 42, channel: "email", notification_type: "weekly_digest"
) # => true (default) | false (if a row says enabled: false)
```

The shipped `AuthSubscriber` consults this before creating the
Email Notification at signup.

## Running the specs

```bash
bin/rails seams:test[notifications]
```
