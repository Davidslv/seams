# Accounts

> Tenant boundary for a Seams-powered host application. Owns the
> `Accounts::Account` (the workspace), `Accounts::Membership`
> (Identity ↔ Account, with role), per-request `Accounts::Current`,
> and the two concerns hosts need to scope their own data and
> controllers to a tenant. Identity stays in the auth engine — this
> engine never owns credentials.

**Requires:** the `auth` engine. `Accounts::Membership.identity_id`
joins to `auth_identities`; `Accounts::Current.account=` reads
`Auth::Current.identity` to derive the matching Membership. Install
auth before accounts.

## Identity, Account, and Membership

Three peer concepts, three tables, one clear responsibility each:

| Model              | Owns                                                | Lives in                |
| ---                | ---                                                 | ---                     |
| `Auth::Identity`   | The human. Credentials, sessions, OAuth, API tokens. | `auth_identities` (auth engine) |
| `Accounts::Account`| The workspace / tenant. Name + soft-cancel state.   | `accounts` (this engine) |
| `Accounts::Membership` | The join. Says "Identity X is a Y in Account Z". | `accounts_memberships` (this engine) |

The same `Auth::Identity` can have memberships in multiple Accounts
with different roles. A Membership belongs to exactly one Account.

## Why is `identity_id` nullable on Membership?

System actors. Every Account ships with a `role: "system"` row whose
`identity_id` is NULL. That row is the audit-log writer for changes
that don't have a human behind them — background jobs syncing data
from a webhook, scheduled tasks expiring trials, billing-engine
hooks reconciling a subscription, etc.

Without a system actor, every audit entry would either need a
nullable `actor_id` (which is what the system row neatly avoids) or
a fake "robot" Identity that lives nowhere else and confuses
everything from email lookup to billing customer mapping.

## Roles

| Role     | identity_id   | Powers                                              |
| ---      | ---           | ---                                                 |
| `owner`  | required      | Full admin. Can manage members, billing, cancel the account. |
| `admin`  | required      | Manages members and most settings; cannot remove an owner. |
| `member` | required      | Default role. Read + write within the account's data scope. |
| `system` | NULL          | Audit-log actor only. Never logs in. One per account.        |

Every Account has exactly one system row (created automatically by
`Account.create_with_owner`); humans get `owner` / `admin` /
`member` rows.

## `staff` vs `admin` — platform admin vs in-account admin

These are different powers:

- `Auth::Identity#staff?` — a boolean on the Identity row. Platform-level
  super-user. Bypasses account scoping for support tooling
  (impersonation, cross-account search). Set by an out-of-band admin
  process; never via sign-up params.
- `Accounts::Membership#admin?` — true when role is `owner` OR `admin`.
  In-account admin. Manages the workspace's members and settings
  but has no power outside this account.

Use `ensure_staff` in controllers that span accounts.
Use `ensure_admin` in controllers that manage one account.

## Events emitted

| Event name                       | Payload                                                                    |
| ---                              | ---                                                                        |
| `account.created.accounts`       | `{ account_id:, owner_identity_id: }`                                      |
| `account.cancelled.accounts`     | `{ account_id:, cancelled_by_identity_id: }`                               |
| `membership.created.accounts`    | `{ account_id:, membership_id:, identity_id:, role: }`                     |
| `membership.role_changed.accounts` | `{ account_id:, membership_id:, from_role:, to_role:, changed_by_identity_id: }` |
| `membership.removed.accounts`    | `{ account_id:, membership_id:, identity_id:, removed_by_identity_id: }`   |

`identity_id` is the row id in the auth engine's `auth_identities`
table. Subscribers (notifications, billing, etc.) resolve the human
via Identity, never via a host User.

## Events consumed

This engine does not subscribe to any other engine's events.
Downstream engines (notifications, billing, teams) publish and
subscribe via `account_id` / `identity_id` carried on their event
payloads.

## Exposed concerns

### `Accounts::AccountScoped` — model concern

Mix into any model whose rows belong to a single Account:

```ruby
class AuditEntry < ApplicationRecord
  include Accounts::AccountScoped
end

Accounts::Current.account = account
AuditEntry.create!(action: "...")  # account_id auto-assigned
AuditEntry.all                     # only this account's rows (default_scope)
AuditEntry.unscoped.all            # opt out for cross-tenant queries
```

The default_scope is a no-op when `Accounts::Current.account` is
unset, so background jobs that haven't bound a Current account see
every row — wire `Accounts::Current.account =` into your job's
`#perform` if you need scoping there.

### `Accounts::Authorization` — controller concern

Mix into the host's `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  include Accounts::Authorization
  # default-on `before_action :ensure_account_access`
end
```

Then opt out per-controller:

```ruby
class PublicPagesController < ApplicationController
  disallow_account_scope          # public marketing
end

class OnboardingController < ApplicationController
  require_access_without_membership  # signed in, no membership yet
end
```

Plus two opt-in helpers any controller can call from its own `before_action`:

- `ensure_admin` — checks `Accounts::Current.membership&.admin?`
  (in-account owner OR admin)
- `ensure_staff` — checks `Auth::Current.identity&.staff?`
  (platform admin)

## Per-request state — `Accounts::Current`

The host wires `Accounts::Current.account` in a controller
before_action. Setting `account=` automatically derives the
matching `Membership` for the currently signed-in identity (read
from `Auth::Current.identity`):

```ruby
class ApplicationController < ActionController::Base
  before_action :resolve_current_account

  private

  def resolve_current_account
    Accounts::Current.account = current_account_from_url_or_session
  end
end

# Anywhere downstream:
Accounts::Current.account     # => Accounts::Account
Accounts::Current.membership  # => Accounts::Membership for the signed-in human
```

## Account creation

```ruby
identity = Auth::Identity.create!(email: "ada@example.com", password: "...")
owner    = Struct.new(:identity, :name).new(identity, "Ada Lovelace")

account = Accounts::Account.create_with_owner(
  account: { name: "Acme Corp" },
  owner:   owner
)

account.memberships.pluck(:role) # => ["system", "owner"]
```

The system membership is mandatory — it's the audit-log actor for
non-human changes. The owner membership is the human creating the
account. Wrapped in a transaction; if any of the three inserts
fail, all roll back.

## Migration / setup steps

1. Run the generator:
   ```bash
   bin/rails generate seams:accounts
   ```
2. Bundle install (no new gems, but locks the engine into the host).
3. Migrate:
   ```bash
   bin/rails db:migrate
   ```
4. Mount in `config/routes.rb` (the generator does this automatically):
   ```ruby
   mount Accounts::Engine, at: "/accounts"
   ```
5. Wire `Accounts::Authorization` into your `ApplicationController`.

## Mounting

```ruby
# config/routes.rb (host application)
Rails.application.routes.draw do
  mount Accounts::Engine, at: "/accounts"
end
```

This engine ships **no controllers** intentionally. Hosts drive
account-creation flows themselves (the shape of the sign-up wizard
varies too much to template). Use `Accounts::Account.create_with_owner`
from your own controller.

## Running the specs

```bash
bin/rails seams:test[accounts]
```
