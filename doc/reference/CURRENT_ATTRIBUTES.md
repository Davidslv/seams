# CurrentAttributes namespaces

Every seams engine that needs per-request state ships its own
`ActiveSupport::CurrentAttributes` namespace. There is no single
top-level `::Current` — each engine's namespace is a peer:

| Namespace | Owned by | Attributes |
| --- | --- | --- |
| `Auth::Current`         | auth          | `identity` |
| `Accounts::Current`     | accounts      | `account`, `membership` |
| `Teams::Current`        | teams         | `team` |
| `Core::Current`         | core          | `user` (the actor — defaults to `Auth::Current.identity`), `team`, `request_id` |

## Why one per engine, not one shared `::Current`

Engines should be installable independently. A host that doesn't
install accounts shouldn't see `Accounts::Current.account` floating
around at the top level. Putting the namespace inside the engine
keeps it discoverable (`grep '::Current' engines/<engine>/`) and
keeps `seams:remove <engine>` semantically clean — the namespace
goes away with the engine.

## Cascade order

Some engines' Current setters read from another engine's Current:

- `Accounts::Current.account=` reads `Auth::Current.identity` to
  auto-derive the matching `Membership`. So `Auth::Current.identity`
  MUST be set BEFORE `Accounts::Current.account =` for the
  membership to populate.
- `Core::HasCurrentAttributes#resolve_current_user` reads
  `Auth::Current.identity` first (with a `current_identity` and
  `current_user` fallback chain). So the auth concern's
  before_action MUST run before `Core::HasCurrentAttributes`'s
  `before_action :populate_current_attributes` for
  `Core::Current.user` to populate.

Canonical wiring in your `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  include Auth::Authentication               # 1. sets Auth::Current.identity
  include Core::HasCurrentAttributes         # 2. reads Auth::Current.identity
  include Accounts::Authorization            # 3. reads Auth::Current.identity

  before_action :authenticate_identity!

  before_action do
    # 4. resolve account from URL/session — the setter reads
    # Auth::Current.identity to compute Accounts::Current.membership
    Accounts::Current.account = current_account_from_params
  end

  before_action do
    # 5. resolve team from URL/session
    Teams::Current.team = current_team_from_params if defined?(Teams::Current)
  end
end
```

## Cross-engine reads are intentional

The `Seams/NoCrossEngineModelAccess` cop exempts `<Engine>::Current`
from the boundary rule. Cross-engine reads of per-request state
are a feature, not a leak: every engine's `Current` is the
documented contract for "what's bound to this request right now."

If you find yourself wanting to MUTATE another engine's Current
from inside your engine, stop and reconsider — that IS a
boundary violation. Reads only.

## Background jobs

`Active Job` runs without a request context, so every `Current`
attribute is nil unless the job explicitly binds them:

```ruby
class MyJob < ApplicationJob
  def perform(account_id, identity_id)
    Accounts::Account.find(account_id).then do |account|
      Auth::Current.identity = Auth::Identity.find(identity_id)
      Accounts::Current.account = account
      do_the_work
    end
  end
end
```

Or use the `with_*` helpers each `Current` ships:

```ruby
Accounts::Current.with_account(account) do
  do_the_work
end
```

The `with_*` helpers reset state at the end of the block, which is
the right shape for nested context-binding (a job that calls a
service that publishes an event that a subscriber processes
synchronously).

## What `Core::Current.user` actually means

Post-Wave-9, `Core::Current.user` is best read as "the current
actor." `Core::HasCurrentAttributes#resolve_current_user` reads
`Auth::Current.identity` first, then `current_identity`, then
`current_user`. The auditable concern writes:

```ruby
record.actor_id = Core::Current.user&.id
```

So `actor_id` is the Identity's id by default. Hosts that want the
actor to be a domain User instead override
`#resolve_current_user` in their `ApplicationController`.

## Seams cop exception, in full

The cop's `DEFAULT_IGNORED_LEAF_NAMES` list is:

```ruby
%w[
  Engine
  VERSION
  ApplicationController
  ApplicationRecord
  ApplicationJob
  ApplicationMailer
  ApplicationHelper
  ApplicationCable
  Routes
  Current
]
```

`Current` is the only non-Rails-framework name in the list. The
others are constants every Rails engine exposes by virtue of being
a Rails engine; `Current` is a seams convention. The cop's
docstring documents this exception inline.
