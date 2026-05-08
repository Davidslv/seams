# Billing

> Subscription billing for a Seams-powered host. Stripe by default,
> swap-able to any gateway via the `Billing::Gateways::Abstract`
> contract.

**Requires:** by default, the `accounts` engine — billing rows
carry `account_id` and the `Billing::Billable` concern auto-includes
into `Billing.configuration.billable_class` (default
`"Accounts::Account"`). Hosts that prefer User-as-customer
override `billable_class` in `config/initializers/billing.rb` and
can run without the accounts engine.

## The Account-as-customer model

Post-Wave-9, the **Stripe customer represents an Account, not an
Identity (human)**. Subscriptions, invoices, and lifetime passes
belong to the tenant. The same Identity who is a member of two
Accounts has two independent billing relationships — even though
they're the same human.

Concrete: every billing table carries `account_id` (UUID, the
`Accounts::Account#id`) as its local foreign key. The Stripe
`customer_ref` (the `cus_*` id) is also stored on every row, so
webhook handlers can address rows either way. There is no
`user_id` / `host_user_id` column anywhere — those were removed in
this refactor.

`granted_by_identity_id` and `revoked_by_identity_id` on
`billing_lifetime_passes` are deliberate exceptions: they reference
an `Auth::Identity` (the human who pressed the "grant" or "revoke"
button), not an Account. The columns track human action, not
tenant-level data.

### Migration story for hosts on a prior wave

If your host already had Wave 8 billing in production with `user_id`
on `billing_subscriptions` etc, those columns are gone. Write a
host-side data migration that backfills `account_id` from your
existing User → Account mapping before adopting the new schema.
There is no automated migration shipped with seams — every host's
mapping is different.

## Wiring `Billing::Billable` into your tenant model

`Billing::Billable` provides the helpers that the host's tenant
model needs:

```ruby
account.billing_subscriptions          # association
account.billing_invoices               # association
account.billing_lifetime_passes        # association
account.has_active_billing?            # paying right now?
account.lifetime?                      # holds an active LTD?
account.has_lifetime_for?(plan_ref:)   # specific LTD?
account.start_subscription!(plan_ref:, email:)
account.cancel_subscription!(subscription_ref:)
account.stripe_customer_ref!(email:)   # lazy Stripe customer creation
```

The engine wires the concern into `Accounts::Account` automatically
at boot via:

```ruby
# lib/billing/engine.rb (paraphrased)
config.to_prepare do
  Billing.configuration.billable_class.constantize.include(Billing::Billable)
end
```

Override the target class in `config/initializers/billing.rb` if your
tenant lives on a different model:

```ruby
Billing.configure do |c|
  c.billable_class = "Workspaces::Workspace"
end
```

Set `c.billable_class = nil` to opt out and `include Billing::Billable`
manually wherever it makes sense.

## Events emitted

All billing events publish the **same canonical payload shape** so
subscribers can read one format regardless of source:

```
{ gateway:      "stripe",      # which adapter emitted it
  livemode:     true | false,  # gateway's livemode flag
  account_id:   "uuid",        # the Accounts::Account that owns this row
  customer_ref: "cus_xxx",     # gateway customer id
  ref:          "sub_xxx",     # canonical id of the subject
  object_id:    "sub_xxx",     # raw object id from the gateway
  object:       { ... } }      # the gateway object as a hash (incl. account_id where applicable)
```

| Event name                                  | Subject       | Emitted when |
| ---                                         | ---           | --- |
| `subscription.created.billing`              | Subscription  | StartSubscriptionJob succeeds, or `customer.subscription.created` webhook fires |
| `subscription.updated.billing`              | Subscription  | `customer.subscription.updated` webhook fires |
| `subscription.canceled.billing`             | Subscription  | CancelSubscriptionJob succeeds, or `customer.subscription.deleted` webhook fires |
| `subscription.trial_will_end.billing`       | Subscription  | `customer.subscription.trial_will_end` webhook fires (~3 days before trial end) |
| `invoice.created.billing`                   | Invoice       | `invoice.created` webhook fires (status: draft) |
| `invoice.paid.billing`                      | Invoice       | `invoice.paid` webhook fires |
| `invoice.failed.billing`                    | Invoice       | `invoice.payment_failed` webhook fires |
| `invoice.finalized.billing`                 | Invoice       | `invoice.finalized` webhook fires |
| `invoice.voided.billing`                    | Invoice       | `invoice.voided` webhook fires |
| `payment.succeeded.billing`                 | PaymentIntent | `payment_intent.succeeded` webhook fires |
| `payment.failed.billing`                    | PaymentIntent | `payment_intent.payment_failed` webhook fires |
| `charge.refunded.billing`                   | Charge        | `charge.refunded` webhook fires |
| `checkout.session_completed.billing`        | CheckoutSession | `checkout.session.completed` webhook fires (subscription mode; LTD mode forks to lifetime.purchased.billing) |
| `lifetime.granted.billing`                  | LifetimePass  | Admin grants a Lifetime Deal via `Billing::Lifetime::GrantPassService`. Includes `granted_by_identity_id`. |
| `lifetime.purchased.billing`                | LifetimePass  | Customer pays for an LTD via Stripe Checkout `mode: "payment"` |
| `lifetime.revoked.billing`                  | LifetimePass  | `Billing::Lifetime::RevokePassService` is called. Includes `revoked_by_identity_id`. |

The webhook controller upserts a local `Billing::Subscription` /
`Billing::Invoice` row before publishing, so subscribers can resolve
either from `payload[:account_id]` directly or by querying the
local DB with `payload[:ref]`.

## Events consumed

This engine does not subscribe to any other engine's events by default.
Hosts often subscribe to `account.created.accounts` to create a Stripe
customer at tenant creation time.

## Exposed concerns

| Concern              | Purpose                                                                        |
| ---                  | ---                                                                            |
| `Billing::Billable`  | Mix into your tenant model (default `Accounts::Account`) for `start_subscription!` / `cancel_subscription!` / `lifetime?` / `has_lifetime_for?(plan_ref:)` / `has_active_billing?` helpers. The engine auto-includes it via `Billing.configuration.billable_class` at boot. |

## Lifetime Deals (LTD)

The engine ships native LTD support — one-time payment for permanent
access — alongside recurring subscriptions. Two flows:

1. **Public purchase** — Stripe Checkout with `mode: "payment"`. The
   pricing page renders any `Billing::Plan` with `interval: "lifetime"`
   under a "Buy once, own forever" section. POST
   `/billing/checkout/lifetime?plan=<gateway_ref>` →
   `Billing::Lifetime::CreateLifetimeSessionService` (which threads
   the current Account's id into Stripe session metadata) →
   redirect to Stripe → on `checkout.session.completed` (or
   `checkout.session.async_payment_succeeded`) the webhook handler
   creates the `Billing::LifetimePass` row (with `account_id` read
   off the metadata) and publishes `lifetime.purchased.billing`.

2. **Private grant** — admin issues an LTD without a Stripe charge via
   `Billing::Admin::LifetimePassesController` (mounted at
   `/billing/admin/lifetime_passes`). Use for early adopters,
   influencer giveaways, ToS-violation refund-then-re-grant. Calls
   `Billing::Lifetime::GrantPassService` with the target Account's id
   AND the Identity of the admin pressing the button. Publishes
   `lifetime.granted.billing` with `granted_by_identity_id` set.

### Trade-off (read this before turning LTDs on)

LTDs lock you into supporting those users **indefinitely with no
recurring revenue**. They're a strong early-adopter / launch lever —
quick cash, fast feedback — but get expensive long-term as your
support load grows while LTD users contribute zero MRR. Cap inventory
on every LTD plan via `max_lifetime_units` (nil = unlimited):

```ruby
Billing::Plan.create!(
  gateway_ref:        "price_lifetime_pro_2026",
  name:               "Pro Lifetime",
  interval:           "lifetime",
  amount_cents:       249_00,
  currency:           "usd",
  max_lifetime_units: 100   # only the first 100 buyers
)
```

The pricing page reads `Plan#lifetime_inventory_remaining` and
disables the "Buy lifetime" button when `lifetime_sold_out?`.

### Authorization model

The engine ships no admin gate — `Billing::Admin::LifetimePassesController`
mounts at `/billing/admin/...` and the host wires their own
`require_admin!` `before_action` (ActiveAdmin / Avo / your own
solution). Per the issue #2 4B scope decision, Seams doesn't ship its
own admin engine.

### Revoke

`Billing::Lifetime::RevokePassService.call(pass:, revoked_by:, notes:)`
soft-revokes via `revoked_at`. `revoked_by` is an Auth::Identity
(the human pressing the revoke button); pass `nil` for system-revoked
passes. The pass row stays in the DB so the audit trail survives.
Stripe refund (for paid LTDs) is the caller's responsibility — this
service updates the local row only. Publishes `lifetime.revoked.billing`.

## Gateways

| Gateway                       | Default | Configure via                                                                    |
| ---                           | ---     | ---                                                                              |
| `Billing::Gateways::Stripe`   | yes     | `Billing.configure { \|c\| c.gateway = "Billing::Gateways::Stripe" }`            |

To add a gateway, subclass `Billing::Gateways::Abstract` and implement
`#create_subscription`, `#cancel_subscription`, `#fetch_subscription`,
`#verify_webhook`. Then point `Billing.configuration.gateway` at the
new class.

## Webhook setup

Stripe will POST events to `/billing/webhooks/stripe`. The engine
verifies signatures via `Billing::Stripe::WebhookSignature`. Set:

```bash
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

In your Stripe dashboard, configure the webhook endpoint to send any
of the events listed below. Each maps to a handler class in
`app/services/billing/webhooks/handlers/`; missing handlers no-op
gracefully so subscribing to extras is safe.

| Stripe event                              | Handler                                    | Canonical seams event                |
| ---                                       | ---                                        | ---                                  |
| `customer.subscription.created`           | `SubscriptionCreatedHandler`               | `subscription.created.billing`       |
| `customer.subscription.updated`           | `SubscriptionUpdatedHandler`               | `subscription.updated.billing`       |
| `customer.subscription.deleted`           | `SubscriptionDeletedHandler`               | `subscription.canceled.billing`      |
| `customer.subscription.trial_will_end`    | `SubscriptionTrialWillEndHandler`          | `subscription.trial_will_end.billing`|
| `invoice.created`                         | `InvoiceCreatedHandler`                    | `invoice.created.billing`            |
| `invoice.paid`                            | `InvoicePaidHandler`                       | `invoice.paid.billing`               |
| `invoice.payment_failed`                  | `InvoicePaymentFailedHandler`              | `invoice.failed.billing`             |
| `invoice.finalized`                       | `InvoiceFinalizedHandler`                  | `invoice.finalized.billing`          |
| `invoice.voided`                          | `InvoiceVoidedHandler`                     | `invoice.voided.billing`             |
| `payment_intent.succeeded`                | `PaymentSucceededHandler`                  | `payment.succeeded.billing`          |
| `payment_intent.payment_failed`           | `PaymentFailedHandler`                     | `payment.failed.billing`             |
| `charge.refunded`                         | `ChargeRefundedHandler`                    | `charge.refunded.billing`            |
| `checkout.session.completed`              | `CheckoutSessionCompletedHandler`          | (subscription path / LTD path)       |

The handler base resolves `account_id` for each webhook by looking
up the local `Billing::Subscription` / `Billing::Invoice` row keyed
on the gateway's `customer_ref`. For brand-new Stripe-initiated
subscriptions (created in the Stripe Dashboard, not via
`Account#start_subscription!`), there's no local row to resolve —
the upsert logs a warning and skips. Reconcile those via a
host-side sync task that maps Stripe customers to Accounts.

Adding a new event type means registering a handler from your host —
no fork required:

```ruby
Billing::Webhooks::EventRouter.register(
  "customer.tax_id.created",
  "MyApp::TaxIdCreatedHandler"
)
```

Default dispatch is synchronous so handler raises roll back the
`WebhookEvent` row and Stripe retries. Flip
`Billing.configuration.process_webhooks_async = true` to enqueue
`Billing::Webhooks::ProcessEventJob.perform_later` instead — Stripe
recommends responding in <100ms.

## Self-service controllers

| Controller                                  | Action                                                |
| ---                                         | ---                                                   |
| `Billing::SubscriptionsController#index`    | List the current Account's subscriptions              |
| `#show`                                     | Single subscription with cancel / change-plan controls|
| `#cancel`                                   | Period-end cancel (immediate via `?immediate=1`)      |
| `#reactivate`                               | Un-cancel a pending-cancellation subscription         |
| `#change_plan`                              | Switch to a new price (proration configurable)        |
| `Billing::InvoicesController#index/#show`   | Read-only billing history                             |

The controllers expect `current_billing_account` to return the
current `Accounts::Account` — by default they read
`Accounts::Current.account` (set up by the accounts engine's
controller concern). Override `#current_billing_account` and
`#current_billing_customer_ref` in your host's `SubscriptionsController` /
`InvoicesController` if your tenant resolution is bound differently.

## Stripe API surface used

Every Stripe call has a doc URL cited inline in
`lib/billing/gateways/stripe.rb` and in each `Billing::Stripe::Client`
method:

| Stripe call                       | Docs URL                                                             |
| ---                               | ---                                                                  |
| `POST /v1/customers`              | https://docs.stripe.com/api/customers/create                         |
| `GET  /v1/customers/search`       | https://docs.stripe.com/api/customers/search                         |
| `POST /v1/subscriptions`          | https://docs.stripe.com/api/subscriptions/create                     |
| `POST /v1/subscriptions/:id`      | https://docs.stripe.com/api/subscriptions/update                     |
| `DELETE /v1/subscriptions/:id`    | https://docs.stripe.com/api/subscriptions/cancel                     |
| `GET  /v1/subscriptions/:id`      | https://docs.stripe.com/api/subscriptions/retrieve                   |
| `GET  /v1/invoices/:id`           | https://docs.stripe.com/api/invoices/retrieve                        |
| `POST /v1/checkout/sessions`      | https://docs.stripe.com/api/checkout/sessions/create                 |
| `POST /v1/billing_portal/sessions`| https://docs.stripe.com/api/customer_portal/sessions/create          |
| Webhook signature verification    | https://docs.stripe.com/webhooks/signatures                          |

## Verifying the Stripe Checkout flow against test mode

For end-to-end confidence in the Stripe wiring, run a real Checkout
session against Stripe's test mode — no mocks, no webmock.

1. Grab a test secret key + webhook secret from
   https://dashboard.stripe.com/test/apikeys and
   https://dashboard.stripe.com/test/webhooks (point the webhook at a
   tunnelled URL via `stripe listen --forward-to localhost:3000/billing/webhooks/stripe`).
2. Set the env vars:
   ```bash
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_WEBHOOK_SECRET=whsec_...   # from `stripe listen` output
   ```
3. Seed at least one Plan whose `gateway_ref` matches a Stripe test
   price id.
4. Visit `/billing/plans`, click "Subscribe", complete Checkout with
   the test card `4242 4242 4242 4242`.
5. Watch your logs — `customer.subscription.created` and
   `invoice.paid` should arrive within seconds; the local
   `Billing::Subscription` + `Billing::Invoice` rows should appear
   with the current Account's id pinned to them.
6. Visit `/billing/subscriptions` — your new subscription should be
   listed. Cancel + reactivate via the UI to exercise the full
   service-object surface.

If webhook events do not arrive, check
`Billing::WebhookEvent.where(gateway: "stripe").order(created_at: :desc)`
— rows mean Stripe reached you but a handler raised; absence means
the signature verification or the URL is wrong.

## Gateway contract specs

The shared example `"a billing gateway"` lives at
`spec/support/shared_examples/a_billing_gateway.rb`. Every gateway
adapter (Stripe is the reference; Paddle / Adyen / your own) MUST
satisfy it:

```ruby
RSpec.describe Billing::Gateways::Paddle do
  it_behaves_like "a billing gateway"
end
```

The contract checks that every method on `Billing::Gateways::Abstract`
exists on the subclass with the documented keyword arguments, and
that `verify_webhook` raises `Billing::WebhookError` on a bad
signature. Wiring-level correctness ("does Paddle actually charge
people?") needs an integration test against that gateway's test mode
— see the Stripe walk-through above for the pattern.

## Running the specs

```bash
bin/rails seams:test[billing]
```
