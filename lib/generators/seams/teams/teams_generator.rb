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
        template "app/models/invitation.rb.tt",
                 engine_path("app/models/teams/invitation.rb")
      end

      def create_controllers
        template "app/controllers/teams_controller.rb.tt",
                 engine_path("app/controllers/teams/teams_controller.rb")
        template "app/controllers/memberships_controller.rb.tt",
                 engine_path("app/controllers/teams/memberships_controller.rb")
        template "app/controllers/invitations_controller.rb.tt",
                 engine_path("app/controllers/teams/invitations_controller.rb")
      end

      def create_concerns
        template "lib/concerns/teamable.rb.tt",
                 engine_path("lib/teams/concerns/teamable.rb")
        template "lib/concerns/authorization.rb.tt",
                 engine_path("lib/teams/concerns/authorization.rb")
      end

      def create_jobs
        template "app/jobs/application_job.rb.tt",
                 engine_path("app/jobs/teams/application_job.rb")
      end

      def create_migrations
        template "db/migrate/create_teams.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_teams.rb")
        template "db/migrate/create_team_memberships.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_team_memberships.rb")
        template "db/migrate/create_team_invitations.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_create_team_invitations.rb")
      end

      def create_specs
        template "spec/models/team_spec.rb.tt",
                 engine_path("spec/models/teams/team_spec.rb")
        template "spec/models/membership_spec.rb.tt",
                 engine_path("spec/models/teams/membership_spec.rb")
        template "spec/models/invitation_spec.rb.tt",
                 engine_path("spec/models/teams/invitation_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents = File.read(rubocop_path)
        replacement = "  ExposedConcerns:\n    - Teams::Teamable\n    - Teams::Authorization"
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
