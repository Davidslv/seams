# Observability

Seams ships a thin observability layer that every engine routes
through — `Seams::Observability.adapter`. The default adapter wraps
`Rails.logger` (or stdout when Rails isn't booted), tags every line
with the engine name, and serialises hash context as `key=value`
pairs so logs stay greppable in production.

## The adapter contract

```ruby
Seams::Observability.adapter.debug("msg", **context)
Seams::Observability.adapter.info("msg",  **context)
Seams::Observability.adapter.warn("msg",  **context)
Seams::Observability.adapter.error("msg", **context)

Seams::Observability.adapter.measure("billing.charge.attempt", engine: "billing") do
  gateway.charge!
end
```

`#measure` records the operation duration in `duration_ms` on success
and re-raises on failure (after recording `error=<class: message>`).

## Default output

```
[seams] [billing] billing.charge.attempt duration_ms=42.17 actor_id=8
```

## Swap the adapter

Configure in `config/initializers/seams.rb`:

```ruby
Seams.configure do |c|
  c.observability_adapter = "MyApp::Observability::Datadog"
end
```

Subclass `Seams::Observability::Adapter` and implement the five
methods. The contract is intentionally small — every plausible APM
target (Datadog, New Relic, OpenTelemetry, Honeycomb) can satisfy
it without contortions.

## Wire it through Core

If you've installed the Core engine, the `Core::HasCurrentAttributes`
controller concern populates `Core::Current.user`/`.team`/`.request_id`
on every request. The observability adapter doesn't read these
automatically, but the convention is: include them in your context
hash so they appear in logs.

The `Core::EventPublisher.publish` wrapper does this for you on the
event bus side.

## Events vs logs

These are two different signals.

- **Events** (`Seams::Events::Publisher.publish`) are the public
  contract between engines. Subscribers consume them. Naming:
  `resource.action.engine`.
- **Logs / metrics** (`Seams::Observability.adapter.info`,
  `.measure`) are the operator-facing signal. They are NOT a public
  contract — change them freely.

A typical engine call site looks like:

```ruby
def charge!(amount_cents)
  Seams::Observability.adapter.measure("billing.charge.attempt",
                                       engine: "billing", amount_cents: amount_cents) do
    gateway.charge(amount_cents)
  end

  Seams::Events::Publisher.publish("invoice.paid.billing",
                                   amount_cents: amount_cents)
end
```

## Per-environment configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.log_level = :info
end
```

Default adapter respects `Rails.logger.level`. Custom adapters should
honour the same convention.

## What the engines emit by default

Every canonical engine logs structured `info` lines for non-trivial
operations and `warn` for invalid input (e.g. bad webhook signature).
Grep for `[seams] [<engine>]` to filter to a single engine's stream.

| Engine          | Notable log lines                                                       |
| ---             | ---                                                                     |
| Notifications   | `notifications.null_sms.deliver` when the NullSms adapter is invoked.  |
| Billing         | `billing.webhook.duplicate` (Stripe retry deduped), `billing.webhook.invalid` (signature failure). |

## Tracing across engines

Subscribers run synchronously in the publisher's process (the default
ActiveSupport adapter), so a single web request that publishes
`user.signed_up.auth` and triggers two subscriber jobs all share the
same `request_id` if `Core::HasCurrentAttributes` is mixed into
ApplicationController. Pass `Core::Current.request_id` through to
your APM:

```ruby
class ApplicationController
  include Core::HasCurrentAttributes
  before_action :tag_apm

  def tag_apm
    Datadog.tracer.active_root_span&.set_tag("request.id", Core::Current.request_id)
  end
end
```
