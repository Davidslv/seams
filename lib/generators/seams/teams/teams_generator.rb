# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/dummy_app_writer"

module Seams
  module Generators
    # Generates a canonical Teams engine on top of the generic engine
    # scaffold. Models cover Team, Membership, Invitation; controllers
    # cover team CRUD + membership management + invitation send/accept;
    # the Teamable concern is exposed for the host's user model.
    #
    # Run with: bin/rails generate seams:teams
    class TeamsGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "teams"
      DEFAULT_FEATURES = %w[invitations roles].freeze

      class_option :with, type: :string, default: "all",
                          desc: "Comma-separated features to enable: invitations,roles (or 'all')"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt",         engine_path("lib/teams/engine.rb"),        force: true
        template "lib/teams.rb.tt",          engine_path("lib/teams.rb"),               force: true
        template "lib/configuration.rb.tt",  engine_path("lib/teams/configuration.rb")
      end

      def overwrite_routes
        template "config/routes.rb.tt", engine_path("config/routes.rb"), force: true
      end

      def create_models
        template "app/models/application_record.rb.tt",
                 engine_path("app/models/teams/application_record.rb")
        template "app/models/team.rb.tt",
                 engine_path("app/models/teams/team.rb")
        template "app/models/membership.rb.tt",
                 engine_path("app/models/teams/membership.rb")
        return unless features.include?("invitations")

        template "app/models/invitation.rb.tt",
                 engine_path("app/models/teams/invitation.rb")
      end

      def create_controllers
        template "app/controllers/teams_controller.rb.tt",
                 engine_path("app/controllers/teams/teams_controller.rb")
        template "app/controllers/memberships_controller.rb.tt",
                 engine_path("app/controllers/teams/memberships_controller.rb")
        return unless features.include?("invitations")

        template "app/controllers/invitations_controller.rb.tt",
                 engine_path("app/controllers/teams/invitations_controller.rb")
      end

      # Phase 4A (2/2) — bare-bones views so the engine renders out
      # of the box. Hosts override by dropping files at
      # app/views/teams/teams/* in their own tree.
      def create_views
        %w[index show new edit].each do |action|
          template "app/views/teams/#{action}.html.erb.tt",
                   engine_path("app/views/teams/teams/#{action}.html.erb")
        end
        template "app/views/memberships/index.html.erb.tt",
                 engine_path("app/views/teams/memberships/index.html.erb")
        return unless features.include?("invitations")

        template "app/views/invitations/index.html.erb.tt",
                 engine_path("app/views/teams/invitations/index.html.erb")
      end

      def create_concerns
        template "lib/concerns/teamable.rb.tt",
                 engine_path("lib/teams/concerns/teamable.rb")
        # Phase 4A — account scoping helper that pairs with Core's
        # TenantScoped. Mix into models that belong to a single team.
        template "lib/concerns/account_scoped.rb.tt",
                 engine_path("lib/teams/concerns/account_scoped.rb")
        # `--with=roles` ships role-based controller filters.
        return unless features.include?("roles")

        template "lib/concerns/authorization.rb.tt",
                 engine_path("lib/teams/concerns/authorization.rb")
      end

      def create_jobs
        template "app/jobs/application_job.rb.tt",
                 engine_path("app/jobs/teams/application_job.rb")
      end

      def create_mailer_and_subscriber
        return unless features.include?("invitations")

        template "app/mailers/invitation_mailer.rb.tt",
                 engine_path("app/mailers/teams/invitation_mailer.rb")
        template "app/views/invitation_mailer/invite.text.erb.tt",
                 engine_path("app/views/teams/invitation_mailer/invite.text.erb")
        template "app/subscribers/invitation_subscriber.rb.tt",
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
        template "spec/models/team_spec.rb.tt",
                 engine_path("spec/models/teams/team_spec.rb")
        template "spec/models/membership_spec.rb.tt",
                 engine_path("spec/models/teams/membership_spec.rb")
        # Phase 4A — factories live alongside the model specs so any
        # spec can `create(:team)` without rolling its own fixture.
        template "spec/factories/teams.rb.tt",
                 engine_path("spec/factories/teams.rb")
        return unless features.include?("invitations")

        template "spec/models/invitation_spec.rb.tt",
                 engine_path("spec/models/teams/invitation_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents       = File.read(rubocop_path)
        exposed_lines  = ["    - Teams::Teamable", "    - Teams::AccountScoped"]
        exposed_lines << "    - Teams::Authorization" if features.include?("roles")
        replacement    = "  ExposedConcerns:\n#{exposed_lines.join("\n")}"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def create_dummy_app
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Teams",
          mount_at: "/teams",
          schema: dummy_schema,
          host_user: dummy_host_user
        )
        template "spec/runtime/boot_spec.rb.tt",
                 engine_path("spec/runtime/teams_boot_spec.rb")
      end

      def wire_into_host
        # factory_bot_rails powers spec/factories/teams.rb. Lives in
        # the host's test group only.
        host_inject_gem("factory_bot_rails", "~> 6.4", group: :test)
        host_inject_mount(engine_class: "Teams::Engine", at: "/teams")
        host_inject_include_in_user("Teams::Teamable")
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

      def dummy_schema
        <<~SCHEMA
          create_table :teams do |t|
            t.string :name, null: false
            t.string :slug, null: false
            t.timestamps
          end
          add_index :teams, :slug, unique: true

          create_table :team_memberships do |t|
            t.references :team,    null: false
            t.bigint     :user_id, null: false
            t.string     :role,    null: false, default: "member"
            t.timestamps
          end
          add_index :team_memberships, %i[team_id user_id], unique: true

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

          create_table :users do |t|
            t.string :email
            t.timestamps
          end
        SCHEMA
      end

      def dummy_host_user
        <<~RB
          # frozen_string_literal: true

          class User < ApplicationRecord
            include Teams::Teamable
          end
        RB
      end
    end
  end
end
