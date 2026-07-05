# Upgrading from Wave 8 to Wave 9

Wave 9 is a breaking rework of seams' identity / account / team
model. The old `Auth::User` (which conflated credentials with
tenant membership) is gone; in its place are three peer engines:

- `Auth::Identity` — the human and their credentials.
- `Accounts::Account` — the tenant boundary, plus `Membership`.
- `Teams::Team` — the optional collaborative grouping.

There are no published seams consumers yet, so the migration burden
falls on the canonical demo (seams-example). This doc captures the
exact change-set so a host that DID adopt seams pre-Wave-9 — or
the demo itself — can move to Wave 9 without guesswork.

## TL;DR

```bash
# In your host:
git checkout -b upgrade/seams-wave-9
bundle update seams
bin/rails generate seams:remove auth        --force      # removes Wave-8 auth
bin/rails generate seams:auth                            # adds Wave-9 auth
bin/rails generate seams:accounts                        # NEW engine
bin/rails generate seams:remove notifications --force
bin/rails generate seams:notifications
bin/rails generate seams:remove billing      --force
bin/rails generate seams:billing
bin/rails generate seams:remove teams        --force
bin/rails generate seams:teams
bin/rails db:rollback STEP=<count of pre-Wave-9 migrations>  # roll back
bin/rails db:migrate                                          # apply Wave-9
```

This is destructive; the safe path is a one-off data migration
script that copies `auth_users.*` rows into `auth_identities` (same
columns) and rewrites references in any host model that pointed at
`Auth::User`.

## Identity rename

| Wave 8 | Wave 9 |
| --- | --- |
| `Auth::User` (constant)            | `Auth::Identity` |
| `auth_users` (table)               | `auth_identities` |
| `current_user` (controller helper) | `current_identity` |
| `authenticate_user!`               | `authenticate_identity!` |
| `signed_in?` (unchanged)           | `signed_in?` |
| `Auth::Authenticatable`            | `Auth::Authenticatable` (now optional — only needed for hosts that maintain a User on top of Auth::Identity) |
| `password_reset_token` (column)    | `password_reset_token` (now standalone — Rails-8 has_secure_password no longer shadows it because `Auth::Identity` is its own table; `reset_token: false` workaround dropped) |

Hosts that maintain a domain User on top of `Auth::Identity` keep
mixing in `Auth::Authenticatable`; canonical Wave-9 hosts have no
domain User. `Auth::Identity` is the default human everywhere.

## Event renames

| Wave 8 | Wave 9 |
| --- | --- |
| `user.signed_up.auth`     | `identity.signed_up.auth` |
| `user.signed_in.auth`     | `identity.signed_in.auth` |
| `user.signed_out.auth`    | `identity.signed_out.auth` |
| `team.member_added.teams`   | `team.member_joined.teams` |
| `team.member_removed.teams` | `team.member_left.teams` |

Event payload keys: `user_id:` → `identity_id:`. The publisher's
`orphan_subscriptions` check will catch most missed renames at
boot.

Subscribers that hard-coded `"user.signed_up.auth"` need to update
the literal string to `"identity.signed_up.auth"`.

## API breaking changes

### `Team#member?(identity_id)`

Previously took an `Auth::User`-like record; now takes an
`identity_id` integer:

```ruby
# Wave 8
team.member?(current_user)

# Wave 9
team.member?(Auth::Current.identity.id)
# or, if you maintain a domain User:
team.member?(current_user.identity_id)
```

A passing record (an `Auth::User` instance) silently coerces to
`record.to_i = 0` in some Active Record versions, so the symptom is
"team checks just stopped working" with no error trace. Update all
callers or override the method in your host to accept either shape.

### `Notifications::PreferencesController` columns

`notification_preferences.user_id` is now `identity_id`. The
migration creates `identity_id`; pre-Wave-9 hosts that have a
`user_id` column need a data migration to copy the values across:

```ruby
# In a host migration (after seams:notifications regeneration):
class CopyUserIdToIdentityIdOnNotificationPreferences < ActiveRecord::Migration[8.0]
  def up
    Notifications::NotificationPreference
      .where(identity_id: nil)
      .where.not(user_id: nil)
      .find_each { |p| p.update_column(:identity_id, p.user_id) }
  end
  def down; end
end
```

(The Wave 9 migration drops `user_id` after copying. If you have
existing preference data, copy first, drop second.)

### `Billing.configuration.billable_class`

Default flipped from `"User"` to `"Accounts::Account"`. The
billable_class must respond to `stripe_customer_ref!(email:)`; the
`Billing::Billable` concern provides the canonical implementation
and is auto-included into `Accounts::Account` post-Wave-9.

If your host kept a domain User as the billable subject, override
the config:

```ruby
# config/initializers/billing.rb
Billing.configure do |c|
  c.billable_class = "User"
end
```

### `Core::HasCurrentAttributes#resolve_current_user`

Default resolution order changed:

1. `Auth::Current.identity` — the canonical signed-in human.
2. `current_identity` — the helper Auth engine exposes.
3. `current_user` — the legacy Wave-8 helper.

Hosts that override `#resolve_current_user` keep their override.
Hosts that DIDN'T override see `Core::Current.user` resolve to the
Identity instead of the host User. If your audit log queries
`Core::Current.user.email`, the call still works (Identity has
email); if it queries `Core::Current.user.full_name`, you need to
adjust the query — Identity doesn't carry a profile name by
default.

## New per-request namespaces

Wave 9 introduces three engine-owned `ActiveSupport::CurrentAttributes`
peers:

| Namespace | Owns |
| --- | --- |
| `Auth::Current`     | `identity` (the signed-in human) |
| `Accounts::Current` | `account`, `membership` (auto-derived from `Auth::Current.identity`) |
| `Teams::Current`    | `team` |

Wiring contract (in your `ApplicationController`):

1. Run the Auth engine's session lookup first — it sets
   `Auth::Current.identity`.
2. Resolve `Accounts::Current.account` from URL/session — its
   setter reads `Auth::Current.identity` to derive the matching
   membership, so step 1 must run first.
3. Resolve `Teams::Current.team` from URL/session if your host
   uses Teams.

Order matters: setting `Accounts::Current.account` BEFORE
`Auth::Current.identity` leaves `Accounts::Current.membership =
nil` silently. Wire the auth concern's before_action FIRST.

The cop's `Seams/NoCrossEngineModelAccess` rule treats every
`<Engine>::Current` as a framework-level constant — cross-engine
reads of per-request state are intentional and exempt.

## Removed: host User model

The canonical Wave-9 demo has no `app/models/user.rb`. Hosts that
WANT one keep theirs; the auth generator's
`host_inject_include_in_user("Auth::Authenticatable")` is now a
silent no-op when `app/models/user.rb` doesn't exist.

If your domain genuinely needs a User on top of `Auth::Identity`
(e.g. for a custom display name, avatar, profile preferences),
keep it and add the optional concerns:

```ruby
class User < ApplicationRecord
  include Auth::Authenticatable        # adds the credentials shim
  include Notifications::Notifiable    # adds notify_email / notify_sms
  # If billing is account-scoped, do NOT include Billing::Billable here;
  # it's auto-included into Accounts::Account.
end
```

If your User is JUST a wrapper for `Auth::Identity` with no extra
state, drop it. `Auth::Identity` already exposes the credential
methods directly.

## Removed: `Teams::Teamable`

Wave 8's `Teams::Teamable` concern was meant to be mixed into the
host User. Since Wave 9 has no canonical host User, the concern
is gone. Hosts that want team-membership query helpers on a
domain User write them themselves:

```ruby
class User < ApplicationRecord
  include Auth::Authenticatable

  def teams
    Teams::Team.joins(:memberships).where(memberships: { identity_id: identity_id })
  end

  def member_of?(team)
    Teams::Membership.exists?(team_id: team.id, identity_id: identity_id)
  end
end
```

## Schema changes summary

| Change | Wave 8 | Wave 9 |
| --- | --- | --- |
| `auth_users` table renamed                   | yes    | `auth_identities` |
| New `accounts` table                         | n/a    | UUID PK, name + external_account_id |
| New `accounts_memberships` table             | n/a    | UUID PK, account_id (UUID FK) + identity_id (bigint) + role |
| `team_memberships.user_id`                   | yes    | renamed `identity_id`, type stays bigint |
| `notification_preferences.user_id`           | yes    | renamed `identity_id` |
| `billing_subscriptions.user_id`              | yes    | renamed `account_id` (the tenant, not the human) |

Run `bin/rails db:migrate` after regenerating the engines. The
seams generators ship the migrations; the host doesn't write them
by hand.

## Verification checklist

After upgrading:

```bash
bundle exec rspec --exclude-pattern "spec/integration_full/**/*"  # gem tests
bundle exec rspec spec/integration_full/                           # full host smoke
bin/audit                                                          # cop + brakeman + bundle-audit
```

Known clean-up after this upgrade is complete:

- `app/models/user.rb`           — drop if you don't need it
- `auth_users` (table)            — dropped by the auth migration
- `Auth::User` (constant references) — search-and-replace to `Auth::Identity`
- `current_user` calls in your code — change to `current_identity`
- `team.member?(record)` calls    — change to `team.member?(record.id)` or `team.member?(current_identity.id)`

## Why no automated rewriter

Each host's domain shape is different — some keep a User, some
don't; some had `User#display_name` overrides, some didn't. A
hand-driven upgrade with this checklist is shorter than a
codemod that has to predict every variant. Wave 10 introduces
splicing tooling that gives future upgrades cleaner support.
