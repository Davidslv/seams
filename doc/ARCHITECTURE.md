# Architecture

Seams is a CLI framework that generates modular Rails engines. The
gem itself is small — its job is to ship templates, an event bus,
boundary cops, and a couple of CLI conveniences. The interesting
part lives in the engines it generates.

## The model

```
+-------------------+        +---------------------+
|  Host Rails app   |        |   engines/auth/     |
|                   |        |   engines/billing/  |
|  routes.rb mounts | -----> |   engines/teams/    |
|  Auth::Engine     |        |   engines/notifs/   |
|  Billing::Engine  |        +---------------------+
|  ...              |              ^         ^
+-------------------+              |         |
        |                          |         |
        |  events (sync)           |         |
        v                          |         |
+-------------------+              |         |
| Seams::Events     | --- subscribers --------+
| ::Publisher       | --- (always enqueue jobs)
+-------------------+
```

Every engine is a real `Rails::Engine` with `isolate_namespace`. The
host application bundles them all in one process. There are no HTTP
calls between engines.

## What the gem itself ships

- `Seams.configure { |c| ... }` — global config (event bus + observability adapters).
- `Seams::Events::Publisher.publish/subscribe` — inter-engine events.
- `Seams::EventRegistry` — tracks which engine emits which event;
  duplicates raise `Seams::Events::DuplicateEventError`.
- `Seams::Observability.adapter` — structured logging, swappable.
- Four custom RuboCop cops (`require: seams/cops`) that enforce
  cross-engine boundaries.
- Generators: `seams:install`, `seams:engine`, `seams:remove`,
  `seams:auth`, `seams:notifications`, `seams:billing`, `seams:teams`.
- `Seams::CLI::List` powers `bin/rails seams:list`.

## Why events instead of direct calls

Engines emit events. Other engines subscribe. The publisher does not
know who is listening — that is the point.

This means:

1. Adding an engine never requires editing another. The auth engine
   does not import anything from notifications even though
   notifications subscribes to its events.
2. Subscribers always enqueue background jobs. The publisher's
   transaction commits fast; side effects retry independently. This
   convention is documented in every engine's README and is not
   enforced by code — boundary review catches violations.
3. Event names follow `resource.action.engine` (e.g.
   `subscription.created.billing`). The trailing engine segment is
   the source of truth for ownership.

## Why boundary cops

`isolate_namespace` is necessary but not sufficient. Without
mechanical enforcement, an "include `Billing::Subscription`" sneaks
in during a Friday afternoon refactor and the engines slowly bleed
into each other. The four cops below catch the most common
violations at lint time:

| Cop | What it catches |
| --- | --- |
| `Seams/NoCrossEngineModelAccess`   | `Billing::Subscription.find(1)` from a different engine. |
| `Seams/NoCrossEngineDependency`    | `require "billing/sdk"` from a different engine. |
| `Seams/KnownQueueNames`            | `queue_as :unknown_queue` typos. |
| `Seams/MigrationComments`          | Migrations without a `# What/Why/Risk` block. |

Each engine's `.rubocop.yml` lists the OTHER engines in `OtherEngines`.
The seams:engine generator auto-populates this list every time a new
engine is added, and seams:remove prunes it.

## Why ExposedConcerns

Some cross-engine references are intentional. A host User (if
present post-Wave-9) can `include Auth::Authenticatable`, and
the canonical Account class includes `Billing::Billable` so the
billing engine's lifecycle hooks bind to the tenant. Note that
`Auth::Identity` is the default human post-Wave-9 — hosts only
keep a domain User when they want a domain-specific shape on top
of the credential model.

The `NoCrossEngineModelAccess` cop has an `ExposedConcerns:`
allowlist for exactly this — the canonical generators add their
concerns to it automatically. The cop also exempts every engine's
`<Engine>::Current` namespace from the boundary rule (each engine
ships its own `ActiveSupport::CurrentAttributes` peer; cross-engine
reads of per-request state are intentional). See
`doc/CURRENT_ATTRIBUTES.md`.

## Adapter pattern

Engines that talk to external services (notifications, billing) ship
an abstract adapter and a default implementation. Hosts swap in
their own by setting a single config knob. No subclass-specific
adapter contract leaks into the engine's domain code.

```ruby
Notifications.configure do |c|
  c.email_adapter = "MyApp::Adapters::Mailgun"
end
```

## What Seams is NOT

- Not a starter kit. Bullet Train ships a working SaaS app; Seams
  ships the substrate to build one.
- Not a microservices framework. Engines run in-process. Cross-engine
  calls are synchronous events.
- Not opinionated about authorization, multi-tenancy, or front-end
  framework. The engines emit events and ship data; you wire the rest.

## Where this design would strain

Honesty about the limits, for the person about to bet on it:

- **Synchronous in-process events.** The event bus is
  `ActiveSupport::Notifications` under the hood: a slow subscriber
  slows the publishing request, and a raising subscriber can break it.
  When a host needs real async fan-out (queues, retries, outbox), the
  event layer is the seam to swap — the adapter boundary exists for
  this — but Seams does not ship that today.
- **One database, one schema.** Engines isolate namespaces and code,
  not storage. Table-level coupling (a rogue join, a shared index
  bottleneck) is invisible to the boundary cops. True data isolation
  means per-engine schemas or databases, which the generators do not
  yet model.
- **Generated code drifts from the generator.** Every file belongs to
  the host — which means a host that heavily edits generated engines
  cannot cleanly re-run a newer generator over them. Upgrades are
  guided by CHANGELOG/upgrade notes, not automated codemods.
- **Boundary enforcement is advisory by construction.** The cops run
  where the host's RuboCop runs. A host that disables a cop, or
  reaches across engines in a way the cops don't model (raw SQL,
  `connection.execute`), gets no protection.
- **Scale of team, not scale of traffic.** The model buys clear
  ownership and independent testing. It does not buy independent
  deployment or independent scaling — if one engine's workload must
  scale separately, that engine is a candidate to extract, and Seams
  stops at the extraction boundary.
