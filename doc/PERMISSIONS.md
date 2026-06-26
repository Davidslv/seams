# Permissions

Seams ships a small, code-defined authorisation layer. There is **no
database table for permissions** and **no DSL** — authorisation is a role
hierarchy defined in code, a catalog of ability codes each engine owns,
and one host-editable grant map. `Seams::Permissions.can?` resolves a
decision from those three pieces.

This is deliberately the *deferred-friendly* shape: a host changes
who-can-do-what by editing one Ruby file, ships it, and moves on. The
heavier machinery (custom roles in the database, a YAML DSL, per-ability
grants) is documented as out of scope below, with the trigger that would
bring it in.

## The model

Three moving parts, mirroring the event bus:

| Piece | Lives in | Owned by |
| --- | --- | --- |
| **Ability codes** (the catalog of *what can be done*) | `Seams::PermissionRegistry` | each engine, registered from its `engine.rb` |
| **Role hierarchy** (the ladder of *who*) | `Seams::Permissions::ROLE_HIERARCHY` | the gem |
| **Grant map** (which roles hold which codes) | `Seams.configuration.permission_grants` | the host (`config/initializers/seams_permissions.rb`) |

Roles are assigned at **runtime** — a person's role is the `role` column
on their per-account `Accounts::Membership`, so the same identity can be
an admin in one account and a member in another. Abilities are a **code
catalog** fixed at boot — an engine declares every ability it understands
when it loads. `can?(role:, ability:)` answers by walking the role up its
hierarchy and asking the grant map whether any of those roles holds the
code:

```ruby
Seams::Permissions.can?(role: "admin", ability: "invoice.manage.billing")
# => true  (admin is granted invoice.manage.billing by default)

Seams::Permissions.can?(role: "member", ability: "invoice.manage.billing")
# => false (member is not, and does not inherit it)
```

## Ability-code naming convention

Ability codes follow the same `resource.action.engine` shape as event
names, so abilities and events read alike:

```
invoice.read.billing
invoice.manage.billing
membership.manage.accounts
```

- **resource** — the noun the ability is about (`invoice`, `team`).
- **action** — usually `read` (the member-level view) or `manage` (the
  admin-level mutate). Engines may register finer actions.
- **engine** — the owning engine, so codes never collide across engines.

Three lowercase, snake_case-allowed, dot-separated segments. The pattern
is enforced: `Seams::Permissions.assert_valid_name!` raises
`InvalidAbilityNameError` on anything else.

## Registering a new ability

An ability code must be **registered by the engine that owns it** before
anything can grant or check it. Register from the engine's `engine.rb`,
right alongside the event registrations, behind the engine's
`*.engine.abilities` insertion-point marker:

```ruby
initializer "billing.register_abilities" do
  Seams::PermissionRegistry.register("invoice.read.billing",   owned_by: "Billing")
  Seams::PermissionRegistry.register("invoice.manage.billing", owned_by: "Billing")
  # Follow-up generators that ship new billing abilities register them here.
  # seams:insertion-point billing.engine.abilities
end
```

Registration is idempotent for the same owner and raises
`DuplicateAbilityError` if a second engine claims a code already owned by
another. List the live catalog any time:

```sh
bin/rails runner 'pp Seams::PermissionRegistry.all'
```

Once registered, grant the code to a role in the host grant map (below).
A code that is never registered is **deny-by-default and loud**: `can?`
raises `UnregisteredAbilityError` rather than quietly returning `false`,
so a typo fails fast instead of silently locking everyone out.

## Role hierarchy + bypass tiers

Roles are ordered most- to least-privileged, and each role **inherits
every ability granted to the roles below it**:

```
owner  ⊇  admin  ⊇  member
```

So a code granted to `member` is automatically held by `admin` and
`owner`; a code only needs to appear at the lowest role that should hold
it. There are two bypass tiers above and beside the hierarchy:

| Tier | Who | How it bypasses |
| --- | --- | --- |
| `system` | trusted internal callers (background jobs, system actors) | a pseudo-role passed to `can?`; resolves `true` for any registered code, no grant needed |
| `staff?` | platform staff (`Auth::Identity#staff?`) | a **request-layer** bypass applied by the caller (e.g. `authorize_permission!`), **not** by `can?` |

The distinction matters: `can?` itself knows only
`owner`/`admin`/`member`/`system`. The platform-staff bypass is the
caller's responsibility, kept out of the gem so the gem stays a pure
`(role, ability)` function. An unknown or typo'd role resolves to just
itself with no grants, so it fails closed.

The default grant map (`Seams::Permissions::DEFAULT_GRANTS`) gives
`member` the `read` codes and `admin` the `manage` codes across the
canonical engines; `owner` and `system` need no entries (the hierarchy
and the bypass cover them).

## The `seams:permissions` generator

The generator writes one host-editable initializer:

```sh
bin/seams permissions          # or: bin/rails generate seams:permissions
# -> config/initializers/seams_permissions.rb
```

The file is a readable copy of `DEFAULT_GRANTS` assigned through
`Seams.configure`:

```ruby
Seams.configure do |config|
  config.permission_grants = {
    "member" => %w[
      invoice.read.billing
      membership.read.accounts
      # ...
    ],
    "admin" => %w[
      invoice.manage.billing
      membership.manage.accounts
      # ...
    ]
  }
end
```

**Editing.** Add, remove, or move codes between roles to fit your
product. You can only grant codes some engine has registered. Restart to
pick up changes. Because roles inherit downward, put a code at the lowest
role that should hold it.

**Ejecting.** The initializer is eject-aware. A re-run of the generator
leaves it alone once it carries the `# seams:ejected from` header, so
your edits survive regeneration. Stamp the header to fully own the file
(see [doc/INSERTION_POINTS.md](INSERTION_POINTS.md) and the eject CLI in
[doc/ARCHITECTURE_WAVE_10.md](ARCHITECTURE_WAVE_10.md)).

## Using `authorize_permission!`

The accounts engine ships an `Accounts::Authorization` controller concern
with `authorize_permission!`, which resolves the **current membership's
role** against a code and applies the platform-staff bypass:

```ruby
class InvoicesController < ApplicationController
  before_action -> { authorize_permission!("invoice.read.billing") }
end
```

It:

1. lets platform staff through (`Auth::Identity#staff?`);
2. otherwise asks `Seams::Permissions.can?` with the role from
   `Accounts::Current.membership`;
3. denies with `403 Forbidden` if neither holds.

The role is read per-request from the active membership, never a global,
which is what keeps powers isolated per account (cross-tenant safety):
the same person gets admin powers in the account where they're an admin
and member powers elsewhere.

## How admin policies consume it

The admin engine's **tenant** Pundit policies
(`Admin::Tenant::*Policy`) resolve through the same registry rather than
hardcoding a role literal. Each policy names the ability code its
resource maps to and defers to `Seams::Permissions.can?` with the
membership role, then adds a per-record tenant guard
(`record_in_tenant_scope?`) so a tenant-admin can't reach another
account's record by id-tampering. The **platform** policies
(`Admin::Platform::*Policy`) gate on `staff?` instead, because platform
admin is the cross-tenant power. See
[doc/ARCHITECTURE_WAVE_11.md](ARCHITECTURE_WAVE_11.md).

## Deliberately deferred

The following are **out of scope** for this layer by design. The grant
map + code catalog cover the common case (a fixed role ladder with a
host-tuned grant map) without the cost of the machinery below:

- **A YAML / Ruby permissions DSL** — declarative role and grant
  definitions loaded from a registry file.
- **Database-backed custom roles** — roles beyond
  `owner`/`admin`/`member` created and edited at runtime by tenants.
- **Per-ability or per-record grants in the database** — granting a
  single code to a single membership without touching the role ladder.

**Revisit trigger.** When a host needs roles beyond the fixed ladder, or
tenants creating their own roles, Wave 11B introduces a
`seams:permissions:add_role` follow-up generator targeting a permissions
insertion-point marker, following the admin engine's per-policy ejection
pattern. Until that need is real, the single editable grant map is the
whole layer.

## See also

- [doc/CURRENT_ATTRIBUTES.md](CURRENT_ATTRIBUTES.md) — where the
  per-request membership (and its role) comes from.
- [doc/ARCHITECTURE_WAVE_11.md](ARCHITECTURE_WAVE_11.md) — the admin
  engine + how its policies consume permissions.
- `spec/seams/authorization_spec.rb` — the access-rule regression matrix.
