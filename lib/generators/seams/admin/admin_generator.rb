# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/eject_aware"
require "seams/generators/dummy_app_writer"

module Seams
  module Generators
    # Generates a canonical Admin engine on top of the generic engine
    # scaffold. Wave 11A — Phase 1 (foundation) + Phase 2 (dashboards).
    # Phase 3 wires Pundit policies + the audit-log auto-write.
    #
    # Phase 1 (foundation) ships:
    #   - lib/admin/engine.rb that registers events, mounts under the
    #     host, and asserts Auth::Identity + Administrate are present
    #     at boot.
    #   - lib/admin.rb + lib/admin/configuration.rb exposing four
    #     configuration knobs:
    #       - authenticator       (callable; default: staff? on current_identity)
    #       - tenancy_scope       (:platform | :tenant; default :platform)
    #       - theme_css_path      (nil; host-supplied admin restyle)
    #       - before_admin_action (callable; hook for 2FA / IP allow-list)
    #   - app/controllers/seams/admin/application_controller.rb
    #     subclassing Administrate::ApplicationController, gating via
    #     the authenticator concern.
    #   - lib/admin/concerns/authenticator.rb — the gate concern.
    #   - config/routes.rb scoped to the engine, with insertion-point
    #     markers + the twelve canonical resource declarations.
    #
    # Phase 2 (dashboards) ships:
    #   - app/dashboards/admin/<name>_dashboard.rb — twelve Administrate
    #     dashboards covering Identity, Account, Membership (x2),
    #     Team, TeamMembership, Invitation, Notification,
    #     NotificationPreference, Plan, Subscription, Invoice,
    #     LifetimePass. Each subclasses Administrate::BaseDashboard.
    #   - app/controllers/admin/<plural>_controller.rb — twelve
    #     thin Administrate controllers, each subclassing
    #     Seams::Admin::ApplicationController (NOT Administrate's
    #     directly) so they inherit the gate, the pundit_user hook,
    #     and Phase 3's audit-log auto-write.
    #   - Dummy app schema + slim model stubs for each of the twelve
    #     so the engine's runtime spec can boot Administrate against
    #     a real ActiveRecord schema.
    #
    # The engine ships NO migrations. It is read-only over existing
    # tables; Phase 3 may revisit if the audit-log table needs an
    # extra column.
    #
    # Run with: bin/rails generate seams:admin
    # rubocop:disable Metrics/ClassLength
    class AdminGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector
      include Seams::Generators::EjectAware

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "admin"

      # Phase 2 dashboard catalogue. Each entry carries:
      #   - the snake-cased dashboard name (filename + dashboard class)
      #   - the full model class name (used inside the controller via
      #     `def resource_class`)
      #   - the owning engine (informational; useful for documentation
      #     and future Pundit policy splits in Phase 3)
      #
      # The order here is the order routes + dashboards appear in
      # the generated files; Identity comes first so the engine root
      # (`root to: "admin/identities#index"`) lands on something
      # meaningful.
      DASHBOARD_MODELS = [
        # [dashboard_basename, model_class, owning_engine]
        ["identity",                "Auth::Identity",                       "auth"],
        ["account",                 "Accounts::Account",                    "accounts"],
        ["accounts_membership",     "Accounts::Membership",                 "accounts"],
        ["team",                    "Teams::Team",                          "teams"],
        ["teams_membership",        "Teams::Membership",                    "teams"],
        ["invitation",              "Teams::Invitation",                    "teams"],
        ["notification",            "Notifications::Notification",          "notifications"],
        ["notification_preference", "Notifications::NotificationPreference", "notifications"],
        ["plan",                    "Billing::Plan",                        "billing"],
        ["subscription",            "Billing::Subscription",                "billing"],
        ["invoice",                 "Billing::Invoice",                     "billing"],
        ["lifetime_pass",           "Billing::LifetimePass",                "billing"]
      ].freeze

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        # engine.rb / lib/admin.rb stay framework-managed.
        template "lib/engine.rb.tt", engine_path("lib/admin/engine.rb"), force: true
        template "lib/admin.rb.tt",  engine_path("lib/admin.rb"),        force: true
      end

      def overwrite_routes
        template_unless_ejected "config/routes.rb.tt", engine_path("config/routes.rb"), force: true
      end

      # The base EngineGenerator creates app/controllers/admin/ and
      # app/models/admin/ files because it assumes a single-segment
      # namespace (`Admin::*`). The admin engine uses the two-segment
      # `Seams::Admin::*` namespace for its own ApplicationController,
      # but the per-dashboard controllers + dashboards live under
      # the single-segment `Admin::*` namespace (Administrate's
      # convention). We delete only the leftover ApplicationController
      # / ApplicationRecord files; Phase 2 templates re-populate
      # app/controllers/admin/.
      def remove_single_namespace_leftovers
        %w[
          app/controllers/admin/application_controller.rb
          app/models/admin/application_record.rb
          spec/admin_spec.rb
        ].each do |relative|
          full = engine_path(relative)
          next unless File.exist?(full)

          FileUtils.rm(full)
          say "  remove  #{relative} (single-namespace leftover)", :red
        end

        # Best-effort: clean up the now-empty parent dir for app/models/admin.
        # (app/controllers/admin gets repopulated by Phase 2 dashboards.)
        full = engine_path("app/models/admin")
        return unless File.directory?(full) && Dir.empty?(full)

        Dir.rmdir(full)
      end

      def create_application_controller
        # Zeitwerk-friendly path: lives at app/controllers/seams/admin/
        # so the constant `Seams::Admin::ApplicationController` resolves
        # without explicit requires.
        template_unless_ejected "app/controllers/admin/application_controller.rb.tt",
                                engine_path("app/controllers/seams/admin/application_controller.rb")
      end

      def create_configuration
        template_unless_ejected "lib/configuration.rb.tt",
                                engine_path("lib/admin/configuration.rb")
      end

      def create_authenticator_concern
        template_unless_ejected "lib/concerns/authenticator.rb.tt",
                                engine_path("lib/admin/concerns/authenticator.rb")
      end

      # Phase 3 — Seams::Admin::Context Struct (the value pundit_user
      # returns). Wraps the current Identity + Membership so policies
      # can read both signals (staff? on Identity, role/account_id on
      # Membership) without each policy reaching into the controller.
      def create_context
        template_unless_ejected "lib/context.rb.tt",
                                engine_path("lib/admin/context.rb")
      end

      # Phase 3 — Pundit policies. Two namespaces (`Admin::Platform`
      # and `Admin::Tenant`) selected at request time by
      # `Seams::Admin.config.tenancy_scope`. Each namespace ships an
      # ApplicationPolicy base + one policy per entry in
      # DASHBOARD_MODELS. `template_unless_ejected` so a host that
      # ejects an individual policy (e.g. to override `destroy?`)
      # keeps their version on the next generator run.
      POLICY_NAMESPACES = %w[platform tenant].freeze
      private_constant :POLICY_NAMESPACES

      def create_policies
        POLICY_NAMESPACES.each do |namespace|
          template_unless_ejected(
            "app/policies/admin/#{namespace}/application_policy.rb.tt",
            engine_path("app/policies/admin/#{namespace}/application_policy.rb")
          )
        end

        DASHBOARD_MODELS.each do |basename, _model_class, _engine|
          POLICY_NAMESPACES.each do |namespace|
            template_unless_ejected(
              "app/policies/admin/#{namespace}/#{basename}_policy.rb.tt",
              engine_path("app/policies/admin/#{namespace}/#{basename}_policy.rb")
            )
          end
        end
      end

      # Phase 2: emit one dashboard + one controller per entry in
      # DASHBOARD_MODELS. `template_unless_ejected` so a host that
      # ejects an individual dashboard (e.g. to restyle the Identity
      # form) keeps their version on the next generator run.
      def create_dashboards
        DASHBOARD_MODELS.each do |basename, _model_class, _engine|
          template_unless_ejected(
            "app/dashboards/admin/#{basename}_dashboard.rb.tt",
            engine_path("app/dashboards/admin/#{basename}_dashboard.rb")
          )

          template_unless_ejected(
            "app/controllers/admin/#{basename.pluralize}_controller.rb.tt",
            engine_path("app/controllers/admin/#{basename.pluralize}_controller.rb")
          )
        end
      end

      def create_dummy_app
        # Phase 2 dashboards target every canonical seams model, so
        # the dummy schema covers every table they read. Slim model
        # stubs ship alongside so Administrate's Zeitwerk-driven class
        # resolution finds an `Auth::Identity` / `Billing::Plan` /
        # etc. constant when the dashboard class loads.
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Admin",
          mount_at: "/admin",
          schema: dummy_schema,
          host_user: dummy_host_identity,
          host_user_path: "app/models/auth/identity.rb"
        )
        write_auth_current_stub
        write_accounts_current_stub
        write_dummy_model_stubs
        amend_dummy_application_rb
        rewrite_dummy_routes_for_namespaced_engine
      end

      # DummyAppWriter renders `mount Admin::Engine, at: "/admin"` from
      # the `engine_module: "Admin"` argument — but our engine lives at
      # `Seams::Admin::Engine` (two-namespace, matching the gem layout).
      # We can't pass `engine_module: "Seams::Admin"` because DummyAppWriter
      # also uses that value to `require "<downcase>"` the engine's lib
      # entry point, and `require "seams::admin"` isn't a thing. Cheapest
      # fix: rewrite the dummy's routes.rb after DummyAppWriter writes it.
      def rewrite_dummy_routes_for_namespaced_engine
        path = File.join(destination_root, "engines", ENGINE_NAME, "spec/dummy/config/routes.rb")
        return unless File.exist?(path)

        contents = File.read(path)
        File.write(path, contents.sub("mount Admin::Engine", "mount Seams::Admin::Engine"))
      end

      def append_administrate_to_engine_gemfile
        # The engine's standalone Gemfile (engine_path("Gemfile"))
        # gets `administrate` appended so that running engine specs
        # in isolation (cd engines/admin && bundle exec rspec) can
        # require the gem. The host-side Gemfile is updated separately
        # by `wire_into_host`.
        gemfile = engine_path("Gemfile")
        return unless File.exist?(gemfile)

        contents = File.read(gemfile)
        return if contents.include?('gem "administrate"')

        File.write(gemfile, contents.rstrip + <<~RB)


          # Phase 2 dashboards subclass Administrate::BaseDashboard; the
          # gem must be available when the engine runs its own specs.
          gem "administrate", "~> 1.0"
        RB
      end

      # Phase 3 — append `pundit` to the engine's standalone Gemfile so
      # `cd engines/admin && bundle exec rspec` can require it. The
      # host-side Gemfile already gets pundit via `wire_into_host`
      # (added in Phase 2 ahead of Phase 3 wiring).
      def append_pundit_to_engine_gemfile
        gemfile = engine_path("Gemfile")
        return unless File.exist?(gemfile)

        contents = File.read(gemfile)
        return if contents.include?('gem "pundit"')

        File.write(gemfile, contents.rstrip + <<~RB)


          # Phase 3 ApplicationController includes Pundit::Authorization
          # and the per-model policies live under Admin::Platform::*
          # and Admin::Tenant::*. The gem must be available when the
          # engine runs its own specs.
          gem "pundit", "~> 2.4"
        RB
      end

      def create_factories
        template_unless_ejected "spec/factories/admin.rb.tt",
                                engine_path("spec/factories/admin.rb")
      end

      def create_unit_specs
        # Per-dashboard specs are deferred to Phase 3 (where the
        # Pundit policies introduce real behaviour worth covering).
        # Phase 2's coverage lives in the runtime boot spec.
      end

      def create_runtime_specs
        template "spec/runtime/admin_boot_spec.rb.tt",
                 engine_path("spec/runtime/admin_boot_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def wire_into_host
        # Administrate is the dashboard framework; Pundit is the
        # authorisation layer Phase 3 will wire policies through.
        # Both go into the host's main bundle (admin runs in-app, not
        # a separate process).
        host_inject_gem("administrate", "~> 1.0")
        host_inject_gem("pundit",       "~> 2.4")
        host_inject_mount(engine_class: "Seams::Admin::Engine", at: "/admin")
      end

      def report_summary
        say report_summary_text, :green
      end

      def report_summary_text
        <<~TXT

          Admin engine generated at engines/admin/

          Next steps:
            1. bundle install
               (picks up administrate + pundit, both injected into the host Gemfile)

            2. Promote yourself to a platform admin:
                 bin/rails runner 'Auth::Identity.find_by(email: "you@example.com").update!(staff: true)'
               No migration is needed — admin is read-only over the
               existing seams tables, and `staff` already lives on
               auth_identities (Wave 9).

            3. Boot the host:
                 bin/rails server

            4. Visit /admin in your browser. You should land on the
               Identities index with sidebar entries for all twelve
               canonical seams models.

          Tenancy modes:
            - :platform (default) — admins see every Account's data.
              Gate: Auth::Identity#staff?.
            - :tenant — admins see only their own Account's data.
              Gate: Accounts::Membership#role == "admin".
            Switch via config/initializers/seams_admin.rb:
              Seams::Admin.configure { |c| c.tenancy_scope = :tenant }

          Customise a dashboard:
            bin/seams resolve --eject admin/app/dashboards/admin/identity_dashboard.rb
            # Edit your local copy; future `bin/seams admin` runs leave it alone.

          Audit log:
            Every successful create/update/destroy writes a Core::AuditLog
            row keyed on Auth::Current.identity. No-ops cleanly if the
            core engine isn't installed.

          Run the engine specs:
            bin/rails seams:test[admin]

          See engines/admin/README.md for the full configuration
          reference and the four config knobs (authenticator,
          tenancy_scope, theme_css_path, before_admin_action).

        TXT
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      # Slim Auth::Current stub for the dummy app. Stands in for the
      # real Auth::Current (which lives in the auth engine, not loaded
      # by the dummy) so the admin boot spec can wire
      # `Current.identity = identity` against the same surface area
      # the canonical seams host uses.
      def write_auth_current_stub
        path = File.join(destination_root, "engines", ENGINE_NAME,
                         "spec/dummy/app/models/auth/current.rb")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, <<~RB)
          # frozen_string_literal: true
          module Auth
            class Current < ActiveSupport::CurrentAttributes
              attribute :identity
            end
          end
        RB
      end

      # Phase 3 — Accounts::Current stub for the dummy app. Stands in
      # for the real Accounts::Current (Wave 9's CurrentAttributes
      # object) so the admin boot spec can wire
      # `Accounts::Current.membership = membership` against the same
      # surface area the canonical seams host uses.
      #
      # The admin engine's `pundit_user` calls
      # `Accounts::Current.membership` to read the active membership
      # for tenant-mode policy decisions. Without this stub the dummy
      # app would NameError on first request.
      def write_accounts_current_stub
        path = File.join(destination_root, "engines", ENGINE_NAME,
                         "spec/dummy/app/models/accounts/current.rb")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, <<~RB)
          # frozen_string_literal: true
          module Accounts
            class Current < ActiveSupport::CurrentAttributes
              attribute :membership
            end
          end
        RB
      end

      # Phase 2: every dashboard targets a model in another engine
      # (Auth::Identity, Accounts::Account, Billing::Plan, etc.).
      # The dummy app doesn't load those engines, so we ship a slim
      # ApplicationRecord stub per model — just enough that
      # Administrate's Zeitwerk-driven dashboard lookup can resolve
      # the constant and inspect the columns. Each stub is
      # `class Foo < ApplicationRecord; self.table_name = "..."; end`
      # — no associations, no validations, no callbacks. The dummy
      # schema (see #dummy_schema) ships the matching tables.
      def write_dummy_model_stubs
        DUMMY_MODEL_STUBS.each do |relative_path, body|
          full = File.join(destination_root, "engines", ENGINE_NAME,
                           "spec/dummy/app/models", relative_path)
          FileUtils.mkdir_p(File.dirname(full))
          File.write(full, body)
        end
      end

      # Append explicit `require_relative` lines to the dummy
      # application.rb so the model stubs load at boot. Zeitwerk is
      # configured eager_load: false in the dummy (see
      # DummyAppWriter); explicit requires guarantee the constants
      # exist before the runtime spec asks Administrate to look up a
      # dashboard's resource_class.
      def amend_dummy_application_rb
        path = File.join(destination_root, "engines", ENGINE_NAME,
                         "spec/dummy/config/application.rb")
        return unless File.exist?(path)

        contents = File.read(path)
        marker   = "# seams:admin dummy stubs"
        return if contents.include?(marker)

        require_block = <<~RB

          #{marker}
          # Phase 2 — explicitly require the model stubs the dummy
          # ships for the admin engine's dashboards. Zeitwerk would
          # find them by autoload, but eager_load is off in the dummy
          # and the runtime spec asks Administrate to inspect each
          # dashboard's resource_class at boot — explicit requires
          # guarantee the constants are defined before Administrate
          # introspects them.
          # Load order matters: the require loop runs during application.rb
          # evaluation, BEFORE Zeitwerk is set up, so abstract parents have
          # to be present in the const table by the time a child's
          # `class Foo < ApplicationRecord` line evaluates. Three priority
          # tiers: top-level `app/models/application_record.rb` first, then
          # every `<namespace>/application_record.rb`, then everything else
          # alphabetical.
          stubs = Dir[File.expand_path("../app/models/**/*.rb", __dir__)]
          stubs.sort_by! do |path|
            relative = path.sub(%r{\\A.*?/app/models/}, "")
            tier =
              if relative == "application_record.rb"           then 0
              elsif File.basename(path) == "application_record.rb" then 1
              else                                             2
              end
            [tier, relative]
          end
          stubs.each { |stub| require stub }
        RB

        File.write(path, "#{contents.rstrip}\n#{require_block}")
      end

      # Slim model stubs for each canonical engine model. Each stub is
      # `class Foo < ApplicationRecord; self.table_name = "..."; end` —
      # no associations, no validations, no callbacks. Just enough that
      # Administrate's Zeitwerk-driven dashboard lookup can resolve the
      # constant and inspect the columns. The dummy schema (see
      # #dummy_schema) ships the matching tables.
      DUMMY_MODEL_STUBS = {
        "core/application_record.rb" => <<~RB,
          # frozen_string_literal: true
          module Core
            class ApplicationRecord < ::ApplicationRecord
              self.abstract_class = true
            end
          end
        RB
        "core/audit_log.rb" => <<~RB,
          # frozen_string_literal: true
          module Core
            # Slim AuditLog stub for the dummy app. Mirrors the
            # canonical seams Core::AuditLog (lives in the core engine,
            # not loaded by the dummy). The admin engine's
            # `record_admin_audit` after_action writes rows here when
            # the constant is defined; without this stub the runtime
            # spec couldn't exercise the audit-log path at all.
            class AuditLog < ApplicationRecord
              self.table_name = "core_audit_logs"
              ACTIONS = %w[create update destroy].freeze
              validates :action, inclusion: { in: ACTIONS }
            end
          end
        RB
        "accounts/application_record.rb" => <<~RB,
          # frozen_string_literal: true
          module Accounts
            class ApplicationRecord < ::ApplicationRecord
              self.abstract_class = true
            end
          end
        RB
        "accounts/account.rb" => <<~RB,
          # frozen_string_literal: true
          module Accounts
            class Account < ApplicationRecord
              self.table_name = "accounts"
              self.primary_key = "id"
              has_many :memberships, class_name: "Accounts::Membership",
                                     foreign_key: :account_id, dependent: :destroy
            end
          end
        RB
        "accounts/membership.rb" => <<~RB,
          # frozen_string_literal: true
          module Accounts
            class Membership < ApplicationRecord
              self.table_name = "accounts_memberships"
              self.primary_key = "id"
              belongs_to :account, class_name: "Accounts::Account"
            end
          end
        RB
        "teams/application_record.rb" => <<~RB,
          # frozen_string_literal: true
          module Teams
            class ApplicationRecord < ::ApplicationRecord
              self.abstract_class = true
            end
          end
        RB
        "teams/team.rb" => <<~RB,
          # frozen_string_literal: true
          module Teams
            class Team < ApplicationRecord
              self.table_name = "teams"
              has_many :memberships, class_name: "Teams::Membership",
                                     foreign_key: :team_id, dependent: :destroy
              has_many :invitations, class_name: "Teams::Invitation", dependent: :destroy
            end
          end
        RB
        "teams/membership.rb" => <<~RB,
          # frozen_string_literal: true
          module Teams
            class Membership < ApplicationRecord
              self.table_name = "team_memberships"
              belongs_to :team, class_name: "Teams::Team"
            end
          end
        RB
        "teams/invitation.rb" => <<~RB,
          # frozen_string_literal: true
          module Teams
            class Invitation < ApplicationRecord
              self.table_name = "team_invitations"
              belongs_to :team, class_name: "Teams::Team"
            end
          end
        RB
        "notifications/application_record.rb" => <<~RB,
          # frozen_string_literal: true
          module Notifications
            class ApplicationRecord < ::ApplicationRecord
              self.abstract_class = true
            end
          end
        RB
        "notifications/notification.rb" => <<~RB,
          # frozen_string_literal: true
          module Notifications
            class Notification < ApplicationRecord
              self.table_name = "notifications"
              belongs_to :owner, polymorphic: true
            end
          end
        RB
        "notifications/notification_preference.rb" => <<~RB,
          # frozen_string_literal: true
          module Notifications
            class NotificationPreference < ApplicationRecord
              self.table_name = "notification_preferences"
            end
          end
        RB
        "billing/application_record.rb" => <<~RB,
          # frozen_string_literal: true
          module Billing
            class ApplicationRecord < ::ApplicationRecord
              self.abstract_class = true
            end
          end
        RB
        "billing/plan.rb" => <<~RB,
          # frozen_string_literal: true
          module Billing
            class Plan < ApplicationRecord
              self.table_name = "billing_plans"
            end
          end
        RB
        "billing/subscription.rb" => <<~RB,
          # frozen_string_literal: true
          module Billing
            class Subscription < ApplicationRecord
              self.table_name = "billing_subscriptions"
            end
          end
        RB
        "billing/invoice.rb" => <<~RB,
          # frozen_string_literal: true
          module Billing
            class Invoice < ApplicationRecord
              self.table_name = "billing_invoices"
            end
          end
        RB
        "billing/lifetime_pass.rb" => <<~RB
          # frozen_string_literal: true
          module Billing
            class LifetimePass < ApplicationRecord
              self.table_name = "billing_lifetime_passes"
            end
          end
        RB
      }.freeze
      private_constant :DUMMY_MODEL_STUBS

      # Slim Auth::Identity stub for the dummy app — mirrors the
      # canonical seams Auth::Identity (auth/templates/app/models/
      # identity.rb.tt). The canonical Identity does NOT declare
      # `has_many :memberships` (the auth engine deliberately stays
      # credential-only and avoids reaching into accounts), so the
      # dummy doesn't either. Phase 4 rewrote the tenant
      # IdentityPolicy to use a subquery on `accounts_memberships`
      # instead of an association join, so the policy works against
      # this exact shape — and the runtime spec exercises the same
      # path real seams hosts will hit.
      def dummy_host_identity
        <<~RB
          # frozen_string_literal: true
          module Auth
            class Identity < ApplicationRecord
              self.table_name = "auth_identities"
              has_secure_password
            end
          end
        RB
      end

      # Schema covers every table the Phase 2 dashboards target.
      # Mirrors the canonical engine migrations:
      #   - auth_identities (auth engine)
      #   - accounts, accounts_memberships (accounts engine)
      #   - teams, team_memberships, team_invitations (teams engine)
      #   - notifications, notification_preferences,
      #     notification_deliveries (notifications engine)
      #   - billing_plans, billing_subscriptions, billing_invoices,
      #     billing_lifetime_passes, billing_webhook_events (billing)
      #   - core_audit_logs (core engine; Phase 3 reads it)
      def dummy_schema
        <<~SCHEMA
          enable_extension "pgcrypto"

          create_table :auth_identities do |t|
            t.text    :email,            null: false
            t.string  :password_digest,  null: false
            t.boolean :staff,            null: false, default: false
            t.timestamps
          end
          add_index :auth_identities, :email, unique: true
          add_index :auth_identities, :staff, where: "staff = true"

          create_table :accounts, id: :uuid do |t|
            t.string   :name,                 null: false
            t.bigint   :external_account_id,  null: false
            t.datetime :cancelled_at
            t.datetime :incinerated_at
            t.timestamps
          end
          add_index :accounts, :external_account_id, unique: true
          add_index :accounts, :cancelled_at

          create_table :accounts_memberships, id: :uuid do |t|
            t.references :account, type: :uuid, null: false,
                                   foreign_key: { to_table: :accounts }, index: false
            t.bigint     :identity_id, null: true
            t.string     :name,        null: false
            t.string     :role,        null: false, default: "member"
            t.boolean    :active,      null: false, default: true
            t.datetime   :verified_at
            t.timestamps
          end
          add_index :accounts_memberships, %i[account_id identity_id], unique: true,
                                                                       name: "index_accounts_memberships_unique"
          add_index :accounts_memberships, %i[account_id role]

          create_table :teams do |t|
            t.string :name, null: false
            t.string :slug, null: false
            t.timestamps
          end
          add_index :teams, :slug, unique: true

          create_table :team_memberships do |t|
            t.references :team,        null: false, foreign_key: { to_table: :teams }, index: true
            t.bigint     :identity_id, null: false
            t.string     :role,        null: false, default: "member"
            t.timestamps
          end
          add_index :team_memberships, %i[team_id identity_id], unique: true
          add_index :team_memberships, :identity_id

          create_table :team_invitations do |t|
            t.references :team,        null: false, foreign_key: { to_table: :teams }, index: true
            t.string     :email,       null: false
            t.string     :token,       null: false
            t.string     :role,        null: false, default: "member"
            t.datetime   :expires_at,  null: false
            t.datetime   :accepted_at
            t.timestamps
          end
          add_index :team_invitations, :token, unique: true

          create_table :notifications do |t|
            t.string   :type,             null: false
            t.string   :owner_type,       null: false
            t.string   :owner_id,         null: false
            t.string   :recipient
            t.string   :template,         null: false
            t.jsonb    :schedule_data
            t.datetime :next_delivery_at
            t.datetime :read_at
            t.timestamps
          end
          add_index :notifications, %i[owner_type owner_id]
          add_index :notifications, :next_delivery_at

          create_table :notification_preferences do |t|
            t.bigint  :identity_id,       null: false
            t.string  :channel,           null: false
            t.string  :notification_type
            t.boolean :enabled,           null: false, default: true
            t.timestamps
          end
          add_index :notification_preferences, %i[identity_id channel notification_type], unique: true,
                                                                                           name: "index_notification_prefs_unique"

          create_table :notification_deliveries do |t|
            t.references :notification, null: false, foreign_key: true, index: true
            t.datetime   :sent_at,      null: false
            t.timestamps
          end

          create_table :billing_plans do |t|
            t.string  :gateway_ref,        null: false
            t.string  :name,               null: false
            t.text    :description
            t.integer :amount_cents,       null: false, default: 0
            t.string  :currency,           null: false, default: "usd"
            t.string  :interval,           null: false, default: "month"
            t.integer :trial_period_days
            t.boolean :active,             null: false, default: true
            t.jsonb   :features,           null: false, default: {}
            t.integer :max_lifetime_units
            t.timestamps
          end
          add_index :billing_plans, :gateway_ref, unique: true

          create_table :billing_subscriptions do |t|
            t.uuid     :account_id,          null: false
            t.string   :customer_ref,        null: false
            t.string   :plan_ref,            null: false
            t.string   :gateway_ref,         null: false
            t.string   :status,              null: false, default: "incomplete"
            t.datetime :current_period_end
            t.timestamps
          end
          add_index :billing_subscriptions, :gateway_ref, unique: true

          create_table :billing_invoices do |t|
            t.uuid       :account_id,       null: false
            t.string     :gateway_ref,      null: false
            t.string     :customer_ref,     null: false
            t.string     :subscription_ref
            t.integer    :amount_cents,     null: false
            t.string     :currency,         null: false, default: "USD"
            t.string     :status,           null: false, default: "open"
            t.datetime   :paid_at
            t.timestamps
          end
          add_index :billing_invoices, :gateway_ref, unique: true

          create_table :billing_lifetime_passes do |t|
            t.uuid     :account_id,          null: false
            t.string   :customer_ref,        null: false
            t.string   :plan_ref,            null: false
            t.string   :gateway_ref
            t.bigint   :granted_by_identity_id
            t.datetime :granted_at,          null: false
            t.datetime :revoked_at
            t.bigint   :revoked_by_identity_id
            t.text     :notes
            t.timestamps
          end
          add_index :billing_lifetime_passes, %i[account_id plan_ref], unique: true,
                                                                       name: "index_billing_ltd_unique"

          create_table :billing_webhook_events do |t|
            t.string   :gateway,            null: false
            t.string   :gateway_event_id,   null: false
            t.string   :event_type,         null: false
            t.boolean  :livemode,           null: false, default: false
            t.timestamps
          end
          add_index :billing_webhook_events, %i[gateway gateway_event_id], unique: true

          create_table :core_audit_logs do |t|
            t.string  :action,          null: false
            t.string  :auditable_type
            t.string  :auditable_id
            t.bigint  :actor_id
            t.jsonb   :payload,         null: false, default: {}
            t.timestamps
          end
          add_index :core_audit_logs, %i[auditable_type auditable_id]
        SCHEMA
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
