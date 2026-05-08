# frozen_string_literal: true

require "fileutils"

module Seams
  module Generators
    # Writes a slim spec/dummy/ Rails app inside a generated engine so
    # the engine's specs can boot Rails and run against a real
    # ActiveRecord database without requiring the host application.
    #
    # The boilerplate (application.rb, boot.rb, environment.rb,
    # database.yml, environments/test.rb, application_record.rb,
    # log/.gitkeep, spec_helper.rb, rails_helper.rb) is emitted by
    # this helper. Engines supply the bits that vary: the schema, the
    # optional host User model, and the routes block.
    #
    #   Seams::Generators::DummyAppWriter.write!(
    #     engine_path:      "engines/auth",
    #     engine_module:    "Auth",
    #     mount_at:         "/auth",
    #     schema:           "<schema body>",
    #     host_user:        "<class User body>",      # optional
    #     host_user_path:   "app/models/user.rb",     # optional, defaults to app/models/user.rb
    #   )
    #
    # `host_user_path` lets engines whose dummy "user" model lives at a
    # different autoload path (e.g. `app/models/auth/identity.rb`)
    # write the file where Zeitwerk will find it.
    module DummyAppWriter
      module_function

      def write!(engine_path:, engine_module:, schema:, mount_at: nil, host_user: nil,
                 host_user_path: "app/models/user.rb")
        ensure_directories(engine_path)
        write_dummy_config(engine_path, engine_module, mount_at)
        write_dummy_app(engine_path, host_user, host_user_path)
        write_dummy_db(engine_path, schema)
        write_dummy_meta(engine_path)
        write_spec_helpers(engine_path)
      end

      def ensure_directories(engine_path)
        %w[
          spec/dummy/config/environments
          spec/dummy/config/initializers
          spec/dummy/db
          spec/dummy/app/models
          spec/dummy/app/controllers
          spec/dummy/app/mailers
          spec/dummy/log
          spec/dummy/tmp
          spec/runtime
        ].each { |dir| FileUtils.mkdir_p(File.join(engine_path, dir)) }
      end

      def write_dummy_config(engine_path, engine_module, mount_at)
        write(File.join(engine_path, "spec/dummy/config/boot.rb"),         boot_rb)
        write(File.join(engine_path, "spec/dummy/config/application.rb"),  application_rb(engine_module))
        write(File.join(engine_path, "spec/dummy/config/environment.rb"),  environment_rb)
        write(File.join(engine_path, "spec/dummy/config/database.yml"),    database_yml(engine_path))
        write(File.join(engine_path, "spec/dummy/config/environments/test.rb"),       test_environment_rb)
        write(File.join(engine_path, "spec/dummy/config/initializers/secret_key.rb"), secret_key_rb)
        write(File.join(engine_path, "spec/dummy/config/routes.rb"), routes_rb(engine_module, mount_at))
      end

      def write_dummy_app(engine_path, host_user, host_user_path)
        write(File.join(engine_path, "spec/dummy/app/models/application_record.rb"), application_record_rb)
        write(File.join(engine_path, "spec/dummy/app/controllers/application_controller.rb"), application_controller_rb)
        write(File.join(engine_path, "spec/dummy/app/mailers/application_mailer.rb"),         application_mailer_rb)
        return unless host_user

        full_user_path = File.join(engine_path, "spec/dummy", host_user_path)
        FileUtils.mkdir_p(File.dirname(full_user_path))
        write(full_user_path, host_user)
      end

      def write_dummy_db(engine_path, schema)
        write(File.join(engine_path, "spec/dummy/db/schema.rb"), schema_rb(schema))
      end

      def write_dummy_meta(engine_path)
        write(File.join(engine_path, "spec/dummy/log/.keep"), "")
        write(File.join(engine_path, "spec/dummy/tmp/.keep"), "")
        write(File.join(engine_path, "spec/dummy/Rakefile"), rakefile_rb)
        write(File.join(engine_path, "spec/dummy/config.ru"), config_ru)
      end

      def write_spec_helpers(engine_path)
        write(File.join(engine_path, "spec/spec_helper.rb"),  spec_helper_rb(engine_path))
        write(File.join(engine_path, "spec/rails_helper.rb"), rails_helper_rb)
      end

      def write(path, content)
        File.write(path, content)
      end

      def boot_rb
        <<~RB
          # frozen_string_literal: true

          ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../Gemfile", __dir__)
          require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])
        RB
      end

      def application_rb(engine_module)
        <<~RB
          # frozen_string_literal: true

          require_relative "boot"

          require "rails/all"

          Bundler.require(*Rails.groups)

          # The engine isn't a published gem; it lives at engines/<name>/.
          # Put its lib/ on the load path before requiring its root file.
          $LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)
          require "#{engine_module.downcase}"

          module Dummy
            class Application < Rails::Application
              # Pin root to the dummy app so Rails doesn't walk up
              # and pick up the host application's Rakefile/config.ru.
              config.root = File.expand_path("..", __dir__)

              config.load_defaults Rails::VERSION::STRING.to_f
              config.eager_load = false
              config.active_support.deprecation = :stderr
              config.action_controller.include_all_helpers = false
            end
          end
        RB
      end

      def environment_rb
        <<~RB
          # frozen_string_literal: true

          require_relative "application"
          Rails.application.initialize!
        RB
      end

      def database_yml(engine_path)
        # Postgres-only — engine schemas use jsonb columns. Per-engine
        # database name keeps parallel test runs from clobbering each
        # other. CI sets PG* env vars; locally they default to the
        # current user with no password (Homebrew Postgres default).
        db_name = "#{File.basename(engine_path)}_dummy_test"
        <<~YML
          test:
            adapter: postgresql
            database: #{db_name}
            host:     <%= ENV.fetch("PGHOST",     "localhost") %>
            port:     <%= ENV.fetch("PGPORT",     "5432") %>
            username: <%= ENV.fetch("PGUSER",     ENV["USER"]) %>
            password: <%= ENV.fetch("PGPASSWORD", "") %>
            pool: 5
            encoding: unicode
        YML
      end

      def test_environment_rb
        <<~RB
          # frozen_string_literal: true

          Rails.application.configure do
            config.cache_classes               = true
            config.eager_load                  = false
            config.public_file_server.enabled  = true
            config.consider_all_requests_local = true
            config.action_controller.perform_caching = false
            config.action_dispatch.show_exceptions   = :rescuable
            config.action_controller.allow_forgery_protection = false
            config.active_support.deprecation = :stderr

            # Throwaway keys for the dummy app so models that declare
            # `encrypts` can round-trip in specs. The dummy DB is wiped
            # every run, so deterministic strings are safe here.
            # Hosts use `bin/rails db:encryption:init` + Rails credentials.
            config.active_record.encryption.primary_key            = "dummy_primary_key_for_tests_only"
            config.active_record.encryption.deterministic_key      = "dummy_deterministic_key_for_tests_only"
            config.active_record.encryption.key_derivation_salt    = "dummy_key_derivation_salt_for_tests_only"
            config.active_record.encryption.support_unencrypted_data = true

            # Mailer specs render views that call URL helpers (e.g.
            # `edit_password_reset_url`). Without a host they raise
            # "Missing host to link to!". `test.host` is the Rails
            # test convention.
            config.action_mailer.delivery_method     = :test
            config.action_mailer.default_url_options = { host: "test.host" }
          end
        RB
      end

      def secret_key_rb
        <<~RB
          # frozen_string_literal: true

          Rails.application.config.secret_key_base = "test_secret_key_base_for_dummy_app"
        RB
      end

      def routes_rb(engine_module, mount_at)
        body = mount_at ? %(  mount #{engine_module}::Engine, at: "#{mount_at}") : ""
        <<~RB
          # frozen_string_literal: true

          Rails.application.routes.draw do
          #{body}
          end
        RB
      end

      def schema_rb(schema_body)
        # Match Rails::VERSION at write-time so schema-format defaults
        # match the host's Rails. A 7.1 schema declared on Rails 8.x
        # still loads, but column-default semantics drift. defined?
        # check guards a Rails-loaded-but-VERSION-not-yet-required boot
        # window the generator specs hit.
        rails_version =
          if defined?(Rails::VERSION::STRING)
            Rails::VERSION::STRING.split(".")[0, 2].join(".")
          else
            "8.1"
          end
        <<~RB
          # frozen_string_literal: true

          ActiveRecord::Schema[#{rails_version}].define(version: 0) do
          #{schema_body.lines.map { |l| "  #{l}" }.join.rstrip}
          end
        RB
      end

      def application_record_rb
        <<~RB
          # frozen_string_literal: true

          class ApplicationRecord < ActiveRecord::Base
            self.abstract_class = true
          end
        RB
      end

      def application_controller_rb
        # Minimal host ApplicationController so engine controllers that
        # inherit from ::ApplicationController (the seams:engine generator
        # default) can boot inside a request spec. Real hosts will have
        # their own; this is dummy-only.
        <<~RB
          # frozen_string_literal: true

          class ApplicationController < ActionController::Base
          end
        RB
      end

      def application_mailer_rb
        # Minimal host ApplicationMailer so engine mailers that inherit
        # from ::ApplicationMailer (auth's PasswordsMailer,
        # notifications' ApplicationMailer) can be autoloaded inside
        # the dummy. Real hosts will have their own; this is
        # dummy-only.
        <<~RB
          # frozen_string_literal: true

          class ApplicationMailer < ActionMailer::Base
            default from: "from@example.com"
          end
        RB
      end

      def rakefile_rb
        <<~RB
          # frozen_string_literal: true

          # Marker file so Rails::Engine.find_root anchors here, not
          # in the parent host application.
          require_relative "config/application"
          Rails.application.load_tasks if defined?(Rails.application)
        RB
      end

      def config_ru
        <<~RB
          # frozen_string_literal: true

          require_relative "config/environment"
          run Rails.application
        RB
      end

      def spec_helper_rb(engine_path)
        engine_name = File.basename(engine_path)
        <<~RB
          # frozen_string_literal: true

          ENV["RAILS_ENV"] ||= "test"

          # Rails has to load before the engine's lib/<name>.rb runs,
          # because engine.rb references Rails::Engine. Specs that need
          # ActiveRecord should `require "rails_helper"` instead — that
          # ALSO boots the dummy app, defines the schema, and connects
          # to the test DB.
          require "rails"
          $LOAD_PATH.unshift File.expand_path("../lib", __dir__)
          require "#{engine_name}"

          RSpec.configure do |config|
            config.expect_with :rspec do |expectations|
              expectations.include_chain_clauses_in_custom_matcher_descriptions = true
            end

            config.mock_with :rspec do |mocks|
              mocks.verify_partial_doubles = true
            end

            config.shared_context_metadata_behavior = :apply_to_host_groups
            config.disable_monkey_patching!
            config.order = :random
            Kernel.srand config.seed
          end
        RB
      end

      def rails_helper_rb
        <<~RB
          # frozen_string_literal: true

          require_relative "spec_helper"
          ENV["RAILS_ENV"] ||= "test"

          # Ensure the per-engine Postgres test database exists before
          # the dummy app boots and tries to connect to it. We connect
          # to the maintenance "postgres" database first, CREATE DATABASE
          # if missing, then let the dummy app pick up its own config.
          require "active_record"
          require "yaml"
          require "erb"
          dummy_db_yml = File.expand_path("dummy/config/database.yml", __dir__)
          db_config    = YAML.safe_load(ERB.new(File.read(dummy_db_yml)).result, aliases: true)["test"]
          target_db    = db_config["database"]
          admin_config = db_config.merge("database" => "postgres")
          ActiveRecord::Base.establish_connection(admin_config)
          unless ActiveRecord::Base.connection.execute(
            "SELECT 1 FROM pg_database WHERE datname = '\#{target_db}'"
          ).any?
            ActiveRecord::Base.connection.execute(%(CREATE DATABASE "\#{target_db}"))
          end
          ActiveRecord::Base.remove_connection

          require File.expand_path("dummy/config/environment", __dir__)
          abort("Rails is in production mode!") if Rails.env.production?

          require "rspec/rails"

          # WebMock is optional — engines that stub outbound HTTP
          # (billing's stub_stripe helpers, auth's OAuth adapter
          # specs) bring in `webmock` via the host Gemfile. If
          # available, require it so specs can call WebMock.stub_request
          # without each one re-requiring it. We disable real HTTP
          # connections to make missing stubs explicit instead of
          # accidentally hitting the network.
          begin
            require "webmock/rspec"
            WebMock.disable_net_connect!(allow_localhost: true)
          rescue LoadError
            # webmock isn't bundled — engines that don't stub HTTP
            # don't need it.
          end

          # FactoryBot is optional — engines that ship factories add
          # `factory_bot_rails` to the host Gemfile. If it's loaded, wire
          # the syntax methods + auto-discover the engine's
          # spec/factories/*.rb (default search paths look in the host's
          # spec/factories which doesn't exist when running engine specs
          # from the host root).
          if defined?(FactoryBot)
            require "factory_bot_rails"
            engine_factories = File.expand_path("factories", __dir__)
            FactoryBot.definition_file_paths = [engine_factories]
            FactoryBot.find_definitions if FactoryBot.factories.none?
          end

          ActiveRecord::Schema.verbose = false
          # Drop and reload the schema for a clean slate every run.
          ActiveRecord::Base.connection.tables.each do |t|
            ActiveRecord::Base.connection.drop_table(t, force: :cascade)
          end
          load File.expand_path("dummy/db/schema.rb", __dir__)

          RSpec.configure do |config|
            config.use_transactional_fixtures = true
            config.infer_spec_type_from_file_location!
            config.filter_rails_from_backtrace!

            if defined?(FactoryBot)
              config.include FactoryBot::Syntax::Methods
            end
          end
        RB
      end
    end
  end
end
