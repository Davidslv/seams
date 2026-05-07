# Removing an Engine

```bash
bin/seams remove analytics            # prompts for confirmation
bin/seams remove analytics --force    # skip the prompt (CI-friendly)
```

This:

1. Deletes `engines/analytics/` and everything under it.
2. Updates every surviving engine's `.rubocop.yml` to remove
   `Analytics` from their `OtherEngines` lists.
3. Leaves the `engines/` root intact so subsequent generators still
   work.

What it does NOT do:

- Touch your host application's `config/routes.rb`. If you mounted
  the engine, remove the `mount Analytics::Engine` line manually.
- Drop tables. Run a destructive migration yourself if you want the
  data gone:

  ```ruby
  # db/migrate/20260507000099_drop_analytics_events.rb
  # What: drops analytics_events after removing the Analytics engine.
  # Why:  the engine was deleted; data is no longer referenced.
  # Risk: destructive, irreversible. Make sure the data is exported
  #       or backed up before running.
  class DropAnalyticsEvents < ActiveRecord::Migration[7.1]
    def change
      drop_table :analytics_events
    end
  end
  ```

- Remove subscribers other engines registered against this engine's
  events. The `Seams::Events::Publisher.orphan_subscriptions` method
  will list them at runtime — drop the dead subscribe blocks
  manually.

## Idempotent

Running `bin/seams remove` on an engine that doesn't exist warns
("skip engines/foo (not found)") instead of erroring. Safe to call
from CI cleanup scripts.

## Re-adding

Re-running the engine generator with the same name recreates the
scaffold. The sibling rubocop writer auto-adds the engine back to
every other engine's `OtherEngines`. Migrations get fresh
timestamps (no collision with the previously-deleted ones — those
are gone with the engine).
