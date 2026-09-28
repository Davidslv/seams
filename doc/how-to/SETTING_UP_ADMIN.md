# Setting up the admin area

This guide adds an admin area at `/admin` to your app, signs you in to
it, and shows how to switch it to tenant mode or add your own
dashboards. For why it's built this way, see
[ARCHITECTURE_WAVE_11.md](../explanation/ARCHITECTURE_WAVE_11.md).

## What you need first

- The **`core`** and **`auth`** engines. Admin uses `Auth::Identity` for
  sign-in and `Core::AuditLog` for its audit trail.
- The other engines are optional. Admin ships dashboards for accounts,
  memberships, teams, invitations, notifications, plans, subscriptions,
  invoices and lifetime passes. Each appears only when its engine is
  installed. The rest are hidden and their URLs return 404.

## 1. Generate it

```bash
bin/seams admin
bundle install      # admin adds administrate and pundit to your Gemfile
```

The generator mounts the engine at `/admin`. It adds no tables, so no
migration is needed.

## 2. Let yourself in

Only **staff** can open the admin area by default. Mark your identity as
staff from a console:

```bash
bin/rails runner 'Auth::Identity.find_by!(email: "you@example.com").update!(staff: true)'
```

Start the app, sign in at `/auth/session/new`, then visit `/admin`:

| You are | You get |
| --- | --- |
| Signed out | Redirected to `/auth/session/new` |
| Signed in, not staff | 403 "Access denied" |
| Signed in, staff | The Identities dashboard, with a sidebar of every installed dashboard |

Every create, update and delete made through the admin area writes a
`Core::AuditLog` row, with you as the actor.

## 3. Choose platform or tenant mode

**Platform mode** is the default. Staff see every account's data. Use it
for your own operators.

**Tenant mode** lets each customer's `admin` and `owner` members manage
their own account only. It needs three settings. Create
`config/initializers/seams_admin.rb`:

```ruby
Seams::Admin.configure do |c|
  c.tenancy_scope = :tenant

  # Let any signed-in identity past the gate. The tenant policies then
  # decide what each role may do.
  c.authenticator = ->(ctrl) { ctrl.current_identity.present? }

  # Tell the admin area which membership the request belongs to. The
  # admin controllers don't inherit your ApplicationController, so resolve
  # it here. This example takes the identity's first active membership.
  # Use however your app picks the current account.
  c.current_membership_resolver = lambda do |ctrl|
    identity = ctrl.current_identity
    identity && Accounts::Membership.find_by(identity_id: identity.id, active: true)
  end
end
```

In tenant mode:
- An `admin` or `owner` sees only their account's rows.
- Another account's records return 404.
- A `member` gets 403.
- Staff still see everything.

> [!NOTE]
> Tenant mode needs the `accounts` engine.

## 4. Add a check before every admin request

`before_admin_action` runs after the gate on every admin request. Use it
for two-factor checks, IP allow-lists, or extra logging:

```ruby
Seams::Admin.configure do |c|
  c.before_admin_action = ->(ctrl) { ctrl.head(:forbidden) unless ctrl.request.remote_ip.start_with?("10.") }
end
```

## 5. Change a dashboard

Generated files are yours to edit. To keep your edits when the generator
runs again, eject the file first:

```bash
bin/seams resolve --eject admin/app/dashboards/admin/identity_dashboard.rb
```

Then edit `engines/admin/app/dashboards/admin/identity_dashboard.rb`.
Administrate's documentation covers fields and attribute lists:
<https://administrate-demo.herokuapp.com/>.

## 6. Add a dashboard for your own model

Adding a model such as `Project` takes a dashboard, a controller, two
policies, and a route. All of them live in the admin engine. The generated
`engines/admin/README.md` has the full recipe, under
"Customising a dashboard". In short:

1. **Dashboard.** Run `bin/rails generate administrate:dashboard Project`.
   Move the dashboard to
   `engines/admin/app/dashboards/admin/project_dashboard.rb`, wrap it in
   `module Admin`, and add `def self.model = ::Project`.
2. **Controller.** Delete the controller Administrate generated in your
   app's `app/controllers/admin/`, because it skips the admin gate.
   Create `Admin::ProjectsController < ::Seams::Admin::ApplicationController`
   in the engine instead.
3. **Policies.** Add `Admin::Platform::ProjectPolicy` and
   `Admin::Tenant::ProjectPolicy`, each subclassing its namespace's
   `ApplicationPolicy`. A dashboard without a policy is denied.
4. **Route.** Add `resources :projects, controller: "/admin/projects"`
   inside the `scope as: :admin do` block in
   `engines/admin/config/routes.rb`.

The sidebar picks up the new dashboard automatically.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `[seams admin] missing required dependency` at boot | The auth engine, `administrate`, or `pundit` is missing | `bin/seams auth`, then `bundle install` |
| 403 "Access denied" while signed in | The gate said no. By default it requires `staff?` | Set `staff: true` on your identity, or change `authenticator` |
| A dashboard returns 404 | Its engine isn't installed | Generate that engine, or ignore it; it stays hidden |
| Tenant admins get 403 everywhere | `authenticator` or `current_membership_resolver` isn't set | See [step 3](#3-choose-platform-or-tenant-mode) |
| Signing in fails with `Missing Active Record encryption credential` | No encryption keys | `bin/rails db:encryption:init`, then add the keys to credentials |
