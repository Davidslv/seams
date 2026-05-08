# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/dummy_app_writer"

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
    # rubocop:disable Metrics/ClassLength
    class AuthGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "auth"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt",         engine_path("lib/auth/engine.rb"),        force: true
        template "lib/auth.rb.tt",           engine_path("lib/auth.rb"),               force: true
        template "lib/configuration.rb.tt",  engine_path("lib/auth/configuration.rb")
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
        # OAuth identity link table — issue #2 section 2A. Lives under
        # the Auth::OAuth namespace alongside the lib/ adapter classes
        # (Abstract, Google, Github) so the Zeitwerk inflector only
        # needs the single "oauth" => "OAuth" mapping at engine boot.
        template "app/models/oauth/provider.rb.tt",
                 engine_path("app/models/auth/oauth/provider.rb")
        # Bearer-token API access — issue #2 section 2A.
        template "app/models/api_token.rb.tt",
                 engine_path("app/models/auth/api_token.rb")
      end

      def create_controllers
        template "app/controllers/sessions_controller.rb.tt",
                 engine_path("app/controllers/auth/sessions_controller.rb")
        template "app/controllers/registrations_controller.rb.tt",
                 engine_path("app/controllers/auth/registrations_controller.rb")
        template "app/controllers/password_resets_controller.rb.tt",
                 engine_path("app/controllers/auth/password_resets_controller.rb")
        template "app/controllers/oauth/callbacks_controller.rb.tt",
                 engine_path("app/controllers/auth/oauth/callbacks_controller.rb")
      end

      def create_services
        template "app/services/register_user.rb.tt",
                 engine_path("app/services/auth/register_user.rb")
        template "app/services/authenticate_user.rb.tt",
                 engine_path("app/services/auth/authenticate_user.rb")
        template "app/services/reset_password.rb.tt",
                 engine_path("app/services/auth/reset_password.rb")
        template "app/services/oauth/authenticator.rb.tt",
                 engine_path("app/services/auth/oauth/authenticator.rb")
        template "app/services/generate_api_token.rb.tt",
                 engine_path("app/services/auth/generate_api_token.rb")
        # Phase Wave 5 (review fix): the revoke path was documented in
        # the README + registered in engine.rb but had no implementer.
        template "app/services/revoke_api_token.rb.tt",
                 engine_path("app/services/auth/revoke_api_token.rb")
      end

      def create_jobs
        template "app/jobs/application_job.rb.tt",
                 engine_path("app/jobs/auth/application_job.rb")
        template "app/jobs/cleanup_expired_sessions_job.rb.tt",
                 engine_path("app/jobs/auth/cleanup_expired_sessions_job.rb")
      end

      def create_rake_tasks
        # Wave 11: PII rotation task for hosts upgrading from Wave ≤10.
        template "lib/tasks/auth_pii.rake.tt",
                 engine_path("lib/tasks/auth_pii.rake")
      end

      def create_oauth_adapters
        template "lib/oauth/abstract.rb.tt",
                 engine_path("lib/auth/oauth/abstract.rb")
        template "lib/oauth/google.rb.tt",
                 engine_path("lib/auth/oauth/google.rb")
        template "lib/oauth/github.rb.tt",
                 engine_path("lib/auth/oauth/github.rb")
      end

      def create_mailer
        template "app/mailers/passwords_mailer.rb.tt",
                 engine_path("app/mailers/auth/passwords_mailer.rb")
        template "app/views/passwords_mailer/reset_email.html.erb.tt",
                 engine_path("app/views/auth/passwords_mailer/reset_email.html.erb")
      end

      def create_views
        template "app/views/sessions/new.html.erb.tt",
                 engine_path("app/views/auth/sessions/new.html.erb")
        template "app/views/sessions/_oauth_buttons.html.erb.tt",
                 engine_path("app/views/auth/sessions/_oauth_buttons.html.erb")
        template "app/views/registrations/new.html.erb.tt",
                 engine_path("app/views/auth/registrations/new.html.erb")
        template "app/views/password_resets/new.html.erb.tt",
                 engine_path("app/views/auth/password_resets/new.html.erb")
        template "app/views/password_resets/edit.html.erb.tt",
                 engine_path("app/views/auth/password_resets/edit.html.erb")
      end

      def create_concerns
        template "lib/concerns/authenticatable.rb.tt",
                 engine_path("lib/auth/concerns/authenticatable.rb")
        template "lib/concerns/authentication.rb.tt",
                 engine_path("lib/auth/concerns/authentication.rb")
        # Bearer-token controller auth for API endpoints.
        template "lib/concerns/api_authenticatable.rb.tt",
                 engine_path("lib/auth/concerns/api_authenticatable.rb")
      end

      def create_migrations
        template "db/migrate/create_auth_users.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_auth_users.rb")
        template "db/migrate/create_auth_sessions.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_auth_sessions.rb")
        template "db/migrate/add_password_reset_to_auth_users.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_add_password_reset_to_auth_users.rb")
        template "db/migrate/create_auth_oauth_providers.rb.tt",
                 engine_path("db/migrate/#{timestamp(3)}_create_auth_oauth_providers.rb")
        template "db/migrate/create_auth_api_tokens.rb.tt",
                 engine_path("db/migrate/#{timestamp(4)}_create_auth_api_tokens.rb")
      end

      def create_specs
        template "spec/models/user_spec.rb.tt",
                 engine_path("spec/models/auth/user_spec.rb")
        template "spec/models/session_spec.rb.tt",
                 engine_path("spec/models/auth/session_spec.rb")
        # Phase 2A finish — coverage for the new Wave-9/10 models.
        template "spec/models/api_token_spec.rb.tt",
                 engine_path("spec/models/auth/api_token_spec.rb")
        template "spec/models/oauth/provider_spec.rb.tt",
                 engine_path("spec/models/auth/oauth/provider_spec.rb")
        template "spec/mailers/passwords_mailer_spec.rb.tt",
                 engine_path("spec/mailers/auth/passwords_mailer_spec.rb")
        template "spec/factories/auth.rb.tt",
                 engine_path("spec/factories/auth.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents = File.read(rubocop_path)
        replacement = "  ExposedConcerns:\n    - Auth::Authenticatable\n    - Auth::Authentication"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def create_dummy_app
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Auth",
          mount_at: "/auth",
          schema: dummy_schema,
          host_user: dummy_host_user
        )
        template "spec/runtime/boot_spec.rb.tt",
                 engine_path("spec/runtime/auth_boot_spec.rb")
        template "spec/runtime/event_payload_spec.rb.tt",
                 engine_path("spec/runtime/auth_event_payload_spec.rb")
        # Phase 2A finish — login flow round-trip via the request stack.
        template "spec/runtime/login_flow_spec.rb.tt",
                 engine_path("spec/runtime/auth_login_flow_spec.rb")
      end

      def wire_into_host
        host_inject_gem("bcrypt",  "~> 3.1")
        # OAuth adapters speak HTTP via Faraday (no Net::HTTP — see
        # memory feedback_external_apis.md). The host needs Faraday on
        # the load path even if it never configures an OAuth provider.
        host_inject_gem("faraday", "~> 2.0")
        # factory_bot_rails powers the engine's spec/factories/*. Lives
        # in the host's test group only.
        host_inject_gem("factory_bot_rails", "~> 6.4", group: :test)
        host_inject_mount(engine_class: "Auth::Engine", at: "/auth")
        host_inject_include_in_user("Auth::Authenticatable")
        host_inject_include_in_application_controller("Auth::Authentication")
      end

      def report_summary
        say ""
        say "  Auth engine generated at engines/auth/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. bundle install   (picks up bcrypt + Auth::Engine)"
        say "    2. bin/rails db:migrate"
        say "    3. Run the engine specs: bin/rails seams:test[auth]"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      def timestamp(offset)
        # Microsecond-resolution timestamp so migrations generated
        # back-to-back (and across sibling generators in the same
        # second) don't collide. The 14-digit format is what Rails
        # uses for its own generators.
        base = Time.now.utc
        seconds = base.strftime("%Y%m%d%H%M%S").to_i
        (seconds + offset).to_s
      end

      def dummy_schema
        <<~SCHEMA
          create_table :auth_users do |t|
            t.text    :email,            null: false
            t.string  :password_digest,  null: false
            t.bigint  :host_user_id
            t.string  :password_reset_token
            t.datetime :password_reset_token_sent_at
            t.timestamps
          end
          add_index :auth_users, :email, unique: true
          add_index :auth_users, :password_reset_token, unique: true,
                                                        where: "password_reset_token IS NOT NULL"

          create_table :auth_sessions do |t|
            t.references :user,       null: false, foreign_key: { to_table: :auth_users }
            t.string     :token,      null: false
            t.datetime   :expires_at, null: false
            t.timestamps
          end
          add_index :auth_sessions, :token, unique: true

          create_table :auth_oauth_providers do |t|
            t.references :user,         null: false, foreign_key: { to_table: :auth_users }
            t.string     :provider,     null: false
            t.text       :provider_uid, null: false
            t.text       :access_token
            t.text       :refresh_token
            t.datetime   :expires_at
            t.string     :token_type,   default: "Bearer"
            t.jsonb      :profile_data, null: false, default: {}
            t.timestamps
          end
          add_index :auth_oauth_providers, %i[provider provider_uid], unique: true
          add_index :auth_oauth_providers, %i[user_id provider],      unique: true

          create_table :auth_api_tokens do |t|
            t.references :user,         null: false, foreign_key: { to_table: :auth_users }
            t.string     :name,         null: false
            t.string     :token_digest, null: false
            t.string     :token_prefix, null: false
            t.datetime   :expires_at
            t.datetime   :last_used_at
            t.timestamps
          end
          add_index :auth_api_tokens, :token_digest, unique: true
        SCHEMA
      end

      def dummy_host_user
        <<~RB
          # frozen_string_literal: true

          class User < ApplicationRecord
            self.table_name = "auth_users"
            include Auth::Authenticatable
          end
        RB
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
