# Removing an Engine

```bash
bin/seams remove analytics            # prompts for confirmation
bin/seams remove analytics --force    # skip the prompt (CI-friendly)
```

This:

1. Deletes `engines/analytics/` and everything under it.
2. Updates every surviving engine's `.rubocop.yml` to remove
   `Analytics` from their `OtherEngines` lists.
3. **Generates a drop-table migration** in the host's `db/migrate/`
   that drops every table the engine created. Run
   `bin/rails db:migrate` to apply it. The migration uses
   `if table_exists?` guards so re-running is safe; the `down`
   direction is `IrreversibleMigration` (re-run the engine generator
   to recreate the schema instead).
4. Reverses host edits made by the canonical generators
   (mount line, `include` directives in `User` /
   `ApplicationController`, the engine's `config/initializers/<name>.rb`).
5. Leaves the `engines/` root intact so subsequent generators still
   work.

What it does NOT do:

- Touch the host's `Gemfile`. Other engines may share gem
  dependencies (e.g. `bcrypt`, `faraday`, `factory_bot_rails`) so
  the Gemfile is left for you to prune manually.
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
