# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/dummy_app_writer"

module Seams
  module Generators
    # Generates a canonical Accounts engine on top of the generic engine
    # scaffold. Adds:
    #
    #   - Accounts::Account model. Tenant boundary. UUID PK.
    #   - Accounts::Membership model. Joins Auth::Identity to Account
    #     with a role enum (owner/admin/member/system); identity_id is
    #     nullable for system actors used by audit-log writes.
    #   - Accounts::Current per-request namespace.
    #   - Accounts::AccountScoped model concern (default_scope to
    #     Current.account, opt-out via .unscoped).
    #   - Accounts::Authorization controller concern (default-on
    #     ensure_account_access; opt out via disallow_account_scope or
    #     require_access_without_membership; helpers ensure_admin /
    #     ensure_staff).
    #   - Migrations for accounts + accounts_memberships (pgcrypto).
    #   - lib/accounts/engine.rb registers the canonical events:
    #     account.created.accounts, account.cancelled.accounts,
    #     membership.created.accounts, membership.role_changed.accounts,
    #     membership.removed.accounts.
    #
    # The engine ships NO controllers in Wave 9 — hosts drive their
    # own account-creation flows; this engine is the model + concern
    # layer.
    #
    # Run with: bin/rails generate seams:accounts
    class AccountsGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "accounts"

      def create_engine_skeleton
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt",         engine_path("lib/accounts/engine.rb"),        force: true
        template "lib/accounts.rb.tt",       engine_path("lib/accounts.rb"),               force: true
        template "lib/configuration.rb.tt",  engine_path("lib/accounts/configuration.rb")
      end

      def overwrite_routes
        template "config/routes.rb.tt", engine_path("config/routes.rb"), force: true
      end

      def create_models
        template "app/models/application_record.rb.tt",
                 engine_path("app/models/accounts/application_record.rb")
        template "app/models/account.rb.tt",
                 engine_path("app/models/accounts/account.rb")
        template "app/models/membership.rb.tt",
                 engine_path("app/models/accounts/membership.rb")
        template "app/models/current.rb.tt",
                 engine_path("app/models/accounts/current.rb")
      end

      def create_concerns
        template "lib/concerns/account_scoped.rb.tt",
                 engine_path("lib/accounts/concerns/account_scoped.rb")
        template "lib/concerns/authorization.rb.tt",
                 engine_path("lib/accounts/concerns/authorization.rb")
      end

      def create_migrations
        template "db/migrate/create_accounts.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_accounts.rb")
        template "db/migrate/create_accounts_memberships.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_accounts_memberships.rb")
      end

      def create_factories
        template "spec/factories/accounts.rb.tt",
                 engine_path("spec/factories/accounts.rb")
      end

      def create_unit_specs
        template "spec/models/accounts/account_spec.rb.tt",
                 engine_path("spec/models/accounts/account_spec.rb")
        template "spec/models/accounts/membership_spec.rb.tt",
                 engine_path("spec/models/accounts/membership_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents     = File.read(rubocop_path)
        replacement  = "  ExposedConcerns:\n    - Accounts::AccountScoped\n    - Accounts::Authorization"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def create_dummy_app
        # Post Wave 9: the dummy app does NOT ship a host User model.
        # Auth::Identity is the canonical human; accounts membership
        # is the per-tenant role row. The accounts engine specs DO
        # exercise Auth::Identity directly (a Membership without an
        # Identity to point at is meaningless), so we ship a slim
        # stub at app/models/auth/identity.rb the same way the
        # notifications engine does.
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Accounts",
          mount_at: "/accounts",
          schema: dummy_schema,
          host_user: dummy_host_identity,
          host_user_path: "app/models/auth/identity.rb"
        )
        write_auth_current_stub
        template "spec/runtime/accounts_boot_spec.rb.tt",
                 engine_path("spec/runtime/accounts_boot_spec.rb")
      end

      # Write a tiny `Auth::Current` stub so the accounts engine specs
      # (which read Current.identity) can run without pulling in the
      # full auth engine.
      def write_auth_current_stub
        path = File.join(destination_root, "engines", ENGINE_NAME,
                         "spec/dummy/app/models/auth/current.rb")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, <<~RB)
          # frozen_string_literal: true
          # Slim Auth::Current stub for the accounts dummy app. Stands in
          # for the real Auth::Current (which lives in the auth engine,
          # not loaded by the dummy) so accounts specs can wire
          # `Current.identity = identity` against the same surface area
          # the canonical seams host uses.
          module Auth
            class Current < ActiveSupport::CurrentAttributes
              attribute :identity
            end
          end
        RB
      end

      def create_runtime_specs
        # Currently a single runtime boot spec covers events, schema,
        # create_with_owner, and Accounts::Current. Split into multiple
        # files in a later phase if the file grows past ~120 lines.
      end

      def wire_into_host
        # factory_bot_rails powers spec/factories/accounts.rb. Lives
        # in the host's test group only.
        host_inject_gem("factory_bot_rails", "~> 6.4", group: :test)
        host_inject_mount(engine_class: "Accounts::Engine", at: "/accounts")
        # NB: no host_inject_include_in_user — the host User is going
        # away in Wave 9. Hosts that DO keep a User model wire it up
        # themselves.
      end

      def report_summary
        say ""
        say "  Accounts engine generated at engines/accounts/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. bin/rails db:migrate"
        say "    2. Include Accounts::Authorization in your ApplicationController"
        say "    3. Wire Accounts::Current.account in a before_action"
        say "    4. Run the engine specs: bin/rails seams:test[accounts]"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      def timestamp(offset)
        # Microsecond-resolution timestamp so migrations generated
        # back-to-back don't collide. Offset by +50 so accounts'
        # `accounts` + `accounts_memberships` tables migrate AFTER
        # auth's `auth_identities` (+0..+3, since memberships address
        # an Identity at the application layer) but BEFORE engines
        # whose schemas depend on `accounts.id` semantically:
        # notifications +100, billing +200, teams +300. Without this,
        # billing's `subscriptions.account_id` would migrate before
        # the `accounts` table existed — no DB-level FK so it's
        # silent, but ordering matters if a host ever tightens to a
        # real foreign-key constraint.
        base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        (base + 50 + offset).to_s
      end

      # Slim Auth::Identity stub for the dummy app. Stands in for the
      # real Auth::Identity (which lives in the auth engine, not loaded
      # by the dummy) so accounts specs can build an Identity for the
      # owner-membership join. Includes has_secure_password so spec
      # fixtures can pass `password:` like the real Identity accepts.
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

      def dummy_schema
        # Includes auth_identities so factories that link memberships
        # to an Identity can `create(:auth_identity)` against a real
        # row. Match the auth engine's schema for that table so
        # cross-engine specs don't drift.
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
          add_index :accounts_memberships, :identity_id
          # Wave 9 invariant: exactly one system actor per Account.
          add_index :accounts_memberships, :account_id, unique: true,
                    where: "role = 'system'",
                    name: "index_accounts_memberships_one_system_per_account"
        SCHEMA
      end
    end
  end
end
