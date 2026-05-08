# Teams

> Multi-tenant teams + memberships + invitations for a Seams-powered host.

**Requires:** the `auth` engine. `Teams::Membership.identity_id`
joins to `auth_identities`. The `Teams::Authorization` concern
reads `Auth::Current.identity` for membership checks; without auth
installed, `current_identity_id` returns nil and team-admin gates
return 403 unconditionally. Install auth before teams.

## Model

A `Teams::Team` is a peer to `Accounts::Account` — **not** nested
inside one. A `Teams::Membership` is a `(team_id, identity_id, role)`
join row that links an `Auth::Identity` directly to a `Teams::Team`.

If your application wants "Team belongs to Account" semantics, wire
that yourself with a host-side migration that adds an `account_id`
column to `teams`. The Teams engine deliberately stays out of the
Account/Tenant question: hosts that don't have Accounts (e.g. a B2C
SaaS that uses Teams as standalone groups) work without any further
plumbing.

`Auth::Identity` is referenced by id only (`identity_id` is a bare
bigint column on `team_memberships`, no `belongs_to :identity`). The
Teams engine never joins to `auth_identities` at the ActiveRecord
level — cross-engine integrity is enforced at the application layer
so Teams can move to a separate database in the future.

## Events emitted

| Event name                       | Payload                                                  | Emitted when |
| ---                              | ---                                                      | --- |
| `team.created.teams`             | `{ team_id:, creator_identity_id: }`                     | TeamsController#create succeeds |
| `team.member_joined.teams`       | `{ team_id:, identity_id:, role: }`                      | MembershipsController#create succeeds |
| `team.member_left.teams`         | `{ team_id:, identity_id: }`                             | MembershipsController#destroy runs |
| `invitation.sent.teams`          | `{ invitation_id:, team_id:, email:, role:, token: }`    | InvitationsController#create succeeds |
| `invitation.accepted.teams`      | `{ team_id:, identity_id:, invitation_id: }`             | InvitationsController#accept succeeds |

## Events consumed

| Event name              | Subscriber                       | What it does |
| ---                     | ---                              | --- |
| `invitation.sent.teams` | `Teams::InvitationSubscriber`    | Looks up the invitation by id and enqueues `Teams::InvitationMailer.invite(invitation_id).deliver_later`. The host overrides the email body at `app/views/teams/invitation_mailer/invite.text.erb`. |

## Exposed concerns

| Concern                  | Purpose                                                             |
| ---                      | ---                                                                 |
| `Teams::Authorization`   | Mixed into engine controllers; provides `require_team_member!` and `require_team_admin!`. Resolves the current human via `current_identity_id`, which by default reads `Auth::Current.identity` (the Auth engine's per-request namespace). Override `current_identity_id` to plug in a different resolver. |
| `Teams::AccountScoped`   | Mix into host models that belong to a single team. Sets up `belongs_to :team` + a `default_scope` on `Teams::Current.team`. |

> **Wave 9 note.** The `Teams::Teamable` host-User concern was removed.
> Wave 9 dropped the canonical demo's host User model: hosts that
> still maintain one are responsible for adding any
> `team_memberships`-keyed helper methods themselves (querying by
> `Teams::Membership.where(identity_id: …)`).

## Roles

| Role     | Capabilities |
| ---      | --- |
| `owner`  | Everything an admin can, plus deleting the team. |
| `admin`  | Manage memberships and invitations. |
| `member` | Read-only by default. |

Teams roles are intentionally independent of Accounts roles — a Team
is its own RBAC unit. Hosts that want a single role across both
should denormalise that themselves.

The engine ships role enforcement at the model level (`Membership#admin?`).
Authorization in controllers is the host's responsibility — Seams gives
you the data and the events; opinion-free on which authz library you use.

## Mounting

```ruby
# config/routes.rb (host application)
Rails.application.routes.draw do
  mount Teams::Engine, at: "/teams"
end
```

## Running the specs

```bash
bin/rails seams:test[teams]
```
