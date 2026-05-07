# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"

module Seams
  module Generators
    # Generates a canonical Auth engine on top of the generic engine
    # scaffold. Adds:
    #
    #   - User and Session ActiveRecord models (has_secure_password).
    #   - SessionsController + RegistrationsController with sign in /
    #     sign up / sign out.
    #   - Authenticatable concern that the host application's user-like
    #     model can `include Auth::Authenticatable` (added to the
    #     engine's ExposedConcerns automatically).
    #   - Migrations for auth_users and auth_sessions.
    #   - lib/auth/engine.rb registers the four canonical events:
    #     user.signed_up.auth, user.signed_in.auth, user.signed_out.auth,
    #     session.expired.auth.
    #
    # Run with: bin/rails generate seams:auth
    class AuthGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "auth"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt", engine_path("lib/auth/engine.rb"), force: true
      end

      def overwrite_routes
        template "config/routes.rb.tt", engine_path("config/routes.rb"), force: true
      end

      def create_models
        template "app/models/application_record.rb.tt",
                 engine_path("app/models/auth/application_record.rb")
        template "app/models/user.rb.tt",
                 engine_path("app/models/auth/user.rb")
        template "app/models/session.rb.tt",
                 engine_path("app/models/auth/session.rb")
      end

      def create_controllers
        template "app/controllers/sessions_controller.rb.tt",
                 engine_path("app/controllers/auth/sessions_controller.rb")
        template "app/controllers/registrations_controller.rb.tt",
                 engine_path("app/controllers/auth/registrations_controller.rb")
      end

      def create_concern
        template "lib/concerns/authenticatable.rb.tt",
                 engine_path("lib/auth/concerns/authenticatable.rb")
      end

      def create_migrations
        template "db/migrate/create_auth_users.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_auth_users.rb")
        template "db/migrate/create_auth_sessions.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_auth_sessions.rb")
      end

      def create_specs
        template "spec/models/user_spec.rb.tt",
                 engine_path("spec/models/auth/user_spec.rb")
        template "spec/models/session_spec.rb.tt",
                 engine_path("spec/models/auth/session_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents = File.read(rubocop_path)
        replacement = "  ExposedConcerns:\n    - Auth::Authenticatable"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def report_summary
        say ""
        say "  Auth engine generated at engines/auth/", :green
        say "  Run its specs with: bin/rails seams:test[auth]"
        say "  Mount in config/routes.rb: mount Auth::Engine, at: '/auth'"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      def timestamp(offset)
        # Deterministic-ish migration timestamp: now + offset seconds.
        # Two migrations generated together get distinct timestamps.
        (Time.now + offset).utc.strftime("%Y%m%d%H%M%S")
      end
    end
  end
end
