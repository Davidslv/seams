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
    # Generates a canonical Teams engine on top of the generic engine
    # scaffold. Models cover Team, Membership, Invitation; controllers
    # cover team CRUD + membership management + invitation send/accept.
    #
    # Wave 9 model: Teams is a peer to Accounts (not nested). A
    # Teams::Membership joins Auth::Identity directly to a Teams::Team.
    # The host-User Teamable concern is gone — Wave 9 dropped the
    # canonical demo's host User, so there's nowhere to mix it into.
    #
    # Run with: bin/rails generate seams:teams
    class TeamsGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector
      include Seams::Generators::EjectAware

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "teams"
      DEFAULT_FEATURES = %w[invitations roles].freeze

      class_option :with, type: :string, default: "all",
                          desc: "Comma-separated features to enable: invitations,roles (or 'all')"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        # engine.rb / lib/teams.rb stay framework-managed.
        template "lib/engine.rb.tt",                 engine_path("lib/teams/engine.rb"),        force: true
        template "lib/teams.rb.tt",                  engine_path("lib/teams.rb"),               force: true
        template_unless_ejected "lib/configuration.rb.tt",
                                engine_path("lib/teams/configuration.rb")
      end

      def overwrite_routes
        template_unless_ejected "config/routes.rb.tt", engine_path("config/routes.rb"), force: true
      end

      def create_models
        template_unless_ejected "app/models/application_record.rb.tt",
                                engine_path("app/models/teams/application_record.rb")
        template_unless_ejected "app/models/team.rb.tt",
                                engine_path("app/models/teams/team.rb")
        template_unless_ejected "app/models/membership.rb.tt",
                                engine_path("app/models/teams/membership.rb")
        template_unless_ejected "app/models/current.rb.tt",
                                engine_path("app/models/teams/current.rb")
        return unless features.include?("invitations")

        template_unless_ejected "app/models/invitation.rb.tt",
                                engine_path("app/models/teams/invitation.rb")
      end

      def create_controllers
        template_unless_ejected "app/controllers/teams_controller.rb.tt",
                                engine_path("app/controllers/teams/teams_controller.rb")
        template_unless_ejected "app/controllers/memberships_controller.rb.tt",
                                engine_path("app/controllers/teams/memberships_controller.rb")
        return unless features.include?("invitations")

        template_unless_ejected "app/controllers/invitations_controller.rb.tt",
                                engine_path("app/controllers/teams/invitations_controller.rb")
      end

      # Phase 4A (2/2) — bare-bones views so the engine renders out
      # of the box. Hosts override by dropping files at
      # app/views/teams/teams/* in their own tree.
      def create_views
        %w[index show new edit].each do |action|
          template_unless_ejected "app/views/teams/#{action}.html.erb.tt",
                                  engine_path("app/views/teams/teams/#{action}.html.erb")
        end
        template_unless_ejected "app/views/memberships/index.html.erb.tt",
                                engine_path("app/views/teams/memberships/index.html.erb")
        return unless features.include?("invitations")

        template_unless_ejected "app/views/invitations/index.html.erb.tt",
                                engine_path("app/views/teams/invitations/index.html.erb")
      end

      def create_concerns
        # Phase 4A — account scoping helper that pairs with Core's
        # TenantScoped. Mix into models that belong to a single team.
        template_unless_ejected "lib/concerns/account_scoped.rb.tt",
                                engine_path("lib/teams/concerns/account_scoped.rb")
        # `--with=roles` ships role-based controller filters.
        return unless features.include?("roles")

        template_unless_ejected "lib/concerns/authorization.rb.tt",
                                engine_path("lib/teams/concerns/authorization.rb")
      end

      def create_jobs
        template_unless_ejected "app/jobs/application_job.rb.tt",
                                engine_path("app/jobs/teams/application_job.rb")
      end

      def create_mailer_and_subscriber
        return unless features.include?("invitations")

        template_unless_ejected "app/mailers/invitation_mailer.rb.tt",
                                engine_path("app/mailers/teams/invitation_mailer.rb")
        template_unless_ejected "app/views/invitation_mailer/invite.text.erb.tt",
                                engine_path("app/views/teams/invitation_mailer/invite.text.erb")
        template_unless_ejected "app/subscribers/invitation_subscriber.rb.tt",
                                engine_path("app/subscribers/teams/invitation_subscriber.rb")
      end

      def create_migrations
        template "db/migrate/create_teams.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_teams.rb")
        template "db/migrate/create_team_memberships.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_team_memberships.rb")
        return unless features.include?("invitations")

        template "db/migrate/create_team_invitations.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_create_team_invitations.rb")
      end

      def create_specs
        template_unless_ejected "spec/models/team_spec.rb.tt",
                                engine_path("spec/models/teams/team_spec.rb")
        template_unless_ejected "spec/models/membership_spec.rb.tt",
                                engine_path("spec/models/teams/membership_spec.rb")
        # Phase 4A — factories live alongside the model specs so any
        # spec can `create(:team)` without rolling its own fixture.
        template_unless_ejected "spec/factories/teams.rb.tt",
                                engine_path("spec/factories/teams.rb")
        return unless features.include?("invitations")

        template_unless_ejected "spec/models/invitation_spec.rb.tt",
                                engine_path("spec/models/teams/invitation_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents       = File.read(rubocop_path)
        exposed_lines  = ["    - Teams::AccountScoped"]
        exposed_lines << "    - Teams::Authorization" if features.include?("roles")
        replacement    = "  ExposedConcerns:\n#{exposed_lines.join("\n")}"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def create_dummy_app
        # Wave 9: no host User model in the dummy. The dummy ships a
        # slim Auth::Identity stub at app/models/auth/identity.rb so
        # the teams engine's boot-time dependency assertion (defined?
        # ::Auth::Identity) passes without pulling in the full auth
        # engine. The same stub also lets `create(:auth_identity)`
        # build real AR rows against the auth_identities table baked
        # into dummy_schema.
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Teams",
          mount_at: "/teams",
          schema: dummy_schema,
          host_user: dummy_host_identity,
          host_user_path: "app/models/auth/identity.rb"
        )
        template "spec/runtime/boot_spec.rb.tt",
                 engine_path("spec/runtime/teams_boot_spec.rb")
      end

      def wire_into_host
        # factory_bot_rails powers spec/factories/teams.rb. Lives in
        # the host's test group only.
        host_inject_gem("factory_bot_rails", "~> 6.4", group: :test)
        host_inject_mount(engine_class: "Teams::Engine", at: "/teams")
        # NB: no host_inject_include_in_user — the host User is gone
        # post-Wave-9. Hosts that DO keep a User model and want
        # team-membership query helpers wire those up themselves.
      end

      def report_summary
        say ""
        say "  Teams engine generated at engines/teams/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. bin/rails db:migrate"
        say "    2. Run the engine specs: bin/rails seams:test[teams]"
        say ""
      end

      private

      # Resolved feature list from --with. "all" (or empty / unrecognised)
      # → invitations + roles. Garbage / unknown values fall back to all
      # so the engine ships fully wired by default. Memoised so ERB
      # branches stay consistent across the generator run.
      def features
        @features ||= begin
          raw = options[:with].to_s.downcase.strip
          if raw.empty? || raw == "all"
            DEFAULT_FEATURES.dup
          else
            requested = raw.split(",").map(&:strip).reject(&:empty?)
            allowed   = requested & DEFAULT_FEATURES
            allowed.empty? ? DEFAULT_FEATURES.dup : allowed
          end
        end
      end

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      # Offset by 300 to avoid collisions with the other canonical
      # engines (auth +0/+1, notifications +100, billing +200/+201/+202).
      def timestamp(offset)
        base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        (base + 300 + offset).to_s
      end

      # Slim Auth::Identity stub for the teams dummy app. Stands in
      # for the real Auth::Identity (which lives in the auth engine,
      # not loaded by the dummy) so the teams engine's boot-time
      # cross-engine dependency assertion passes and specs that
      # `create(:auth_identity)` get a real Active Record row backing
      # the auth_identities table.
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

      # Includes auth_identities so factories that link memberships to
      # an Identity can `create(:auth_identity)` against a real row.
      # Match the auth engine's schema for that table so cross-engine
      # specs don't drift.
      def dummy_schema
        <<~SCHEMA
          create_table :auth_identities do |t|
            t.text    :email,            null: false
            t.string  :password_digest,  null: false
            t.boolean :staff,            null: false, default: false
            t.timestamps
          end
          add_index :auth_identities, :email, unique: true
          add_index :auth_identities, :staff, where: "staff = true"

          create_table :teams do |t|
            t.string :name, null: false
            t.string :slug, null: false
            t.timestamps
          end
          add_index :teams, :slug, unique: true

          create_table :team_memberships do |t|
            t.references :team,        null: false
            t.bigint     :identity_id, null: false
            t.string     :role,        null: false, default: "member"
            t.timestamps
          end
          add_index :team_memberships, %i[team_id identity_id], unique: true
          add_index :team_memberships, :identity_id

          create_table :team_invitations do |t|
            t.references :team,        null: false
            t.string     :email,       null: false
            t.string     :token,       null: false
            t.string     :role,        null: false, default: "member"
            t.datetime   :expires_at,  null: false
            t.datetime   :accepted_at
            t.timestamps
          end
          add_index :team_invitations, :token, unique: true
          add_index :team_invitations, %i[team_id email], unique: true,
                                                          where: "accepted_at IS NULL"
        SCHEMA
      end
    end
  end
end
