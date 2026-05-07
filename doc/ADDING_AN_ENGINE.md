# Adding an Engine

Two ways to add an engine: use one of the canonical generators, or
build your own on top of `seams:engine`.

## The canonical engines

| Generator | Engine             | What it ships |
| ---       | ---                | --- |
| `bin/seams auth`           | Auth          | User + Session + sign-in/out, Authenticatable + Authentication concerns |
| `bin/seams notifications`  | Notifications | DeliverEmailJob/DeliverSmsJob, ActionMailer + NullSms adapters, Notifiable concern |
| `bin/seams billing`        | Billing       | Subscription + Invoice, Stripe gateway, webhook controller with dedupe, Billable concern |
| `bin/seams teams`          | Teams         | Team + Membership + Invitation, Teamable + Authorization concerns |

Run any of them. The generator:

1. Calls the generic `seams:engine <name>` to scaffold the engine.
2. Layers in the canonical models, controllers, jobs, concerns,
   migrations, and views.
3. Updates the engine's `.rubocop.yml` with the canonical
   `ExposedConcerns`.
4. Updates every other engine's `.rubocop.yml` to add the new
   engine to their `OtherEngines` lists.
5. Prints a postinstall checklist.

## Building your own engine

When you want an engine that isn't in the catalogue:

```bash
bin/seams engine analytics
```

This produces a generic, fully-isolated `Rails::Engine` skeleton
under `engines/analytics/`:

- `analytics.gemspec`
- `lib/analytics/engine.rb` (with `isolate_namespace Analytics`)
- `lib/analytics/version.rb`
- `lib/analytics.rb`
- `config/routes.rb`
- `app/controllers/analytics/application_controller.rb`
- `.rubocop.yml` — pre-wired with the four boundary cops + your
  `OwnEngine` set, `OtherEngines` listing every existing sibling
  engine
- `spec/spec_helper.rb` + a sample passing spec
- `LICENSE`
- `README.md` with the standard "Events emitted / consumed / Exposed
  concerns / Adapters" tables

## Add models

```ruby
# engines/analytics/app/models/analytics/event.rb
module Analytics
  class Event < ApplicationRecord
    self.table_name = "analytics_events"
  end
end
```

## Add a migration

```ruby
# engines/analytics/db/migrate/20260507000001_create_analytics_events.rb
# What: creates analytics_events for the Analytics engine.
# Why:  every product event we want to query by funnel lands here.
# Risk: append-mostly, single-row writes from background jobs.
class CreateAnalyticsEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :analytics_events do |t|
      t.string :name, null: false
      t.bigint :user_id
      t.jsonb  :props, null: false, default: {}
      t.timestamps
    end
  end
end
```

The leading `# What:`/`# Why:`/`# Risk:` block is required by
`Seams/MigrationComments`.

## Register events the engine emits

```ruby
# engines/analytics/lib/analytics/engine.rb
module Analytics
  class Engine < ::Rails::Engine
    isolate_namespace Analytics

    initializer "analytics.register_events" do
      Seams::EventRegistry.register("event.tracked.analytics", emitted_by: "Analytics")
    end
  end
end
```

`Seams::EventRegistry` enforces uniqueness — registering the same
event name from two different engines raises
`Seams::Events::DuplicateEventError`.

## Publish from your code

```ruby
Seams::Events::Publisher.publish("event.tracked.analytics", user_id: 42, name: "viewed_pricing")
```

Publisher validates the name format (`resource.action.engine`) and
checks the registry — unregistered events raise.

## Subscribe to other engines' events

```ruby
# engines/analytics/app/subscribers/analytics/auth_subscriber.rb
module Analytics
  class AuthSubscriber
    @attached = false

    class << self
      attr_accessor :attached
      alias_method :attached?, :attached

      def attach!
        return if attached?

        Seams::Events::Publisher.subscribe("user.signed_up.auth") do |payload|
          TrackEventJob.perform_later(name: "signed_up", user_id: payload[:user_id])
        end

        self.attached = true
      end
    end
  end
end
```

```ruby
# engines/analytics/lib/analytics/engine.rb
config.after_initialize do
  Analytics::AuthSubscriber.attach!
end
```

Always enqueue jobs from subscribers — the publisher's transaction
should commit fast and side effects should retry independently.

## Expose a concern

If your engine has a concern the host should mix in:

```ruby
# engines/analytics/lib/analytics/concerns/trackable.rb
require "active_support/concern"

module Analytics
  module Trackable
    extend ActiveSupport::Concern

    def track(event_name, **props)
      Analytics::Event.create!(name: event_name, user_id: id, props: props)
    end
  end
end
```

Add it to the engine's `.rubocop.yml`:

```yaml
Seams/NoCrossEngineModelAccess:
  ExposedConcerns:
    - Analytics::Trackable
```

Now hosts can `include Analytics::Trackable` in their `User` without
the boundary cop firing.

## Verify

```bash
bin/seams list
bin/rails db:migrate
bin/seams test analytics
bundle exec rubocop engines/analytics
```
