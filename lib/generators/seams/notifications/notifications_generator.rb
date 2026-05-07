# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"

module Seams
  module Generators
    # Generates a canonical Notifications engine on top of the generic
    # engine scaffold. The engine subscribes to user.signed_up.auth and
    # routes outbound messages through swappable email + SMS adapters.
    #
    # Run with: bin/rails generate seams:notifications
    class NotificationsGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "notifications"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt", engine_path("lib/notifications/engine.rb"), force: true
      end

      def create_configuration
        template "lib/configuration.rb.tt", engine_path("lib/notifications/configuration.rb")
        template "lib/notifications.rb.tt", engine_path("lib/notifications.rb"), force: true
      end

      def create_adapters
        template "lib/adapters/abstract.rb.tt",      engine_path("lib/notifications/adapters/abstract.rb")
        template "lib/adapters/action_mailer.rb.tt", engine_path("lib/notifications/adapters/action_mailer.rb")
        template "lib/adapters/null_sms.rb.tt",      engine_path("lib/notifications/adapters/null_sms.rb")
      end

      def create_concern
        template "lib/concerns/notifiable.rb.tt",
                 engine_path("lib/notifications/concerns/notifiable.rb")
      end

      def create_jobs
        template "app/jobs/application_job.rb.tt",
                 engine_path("app/jobs/notifications/application_job.rb")
        template "app/jobs/deliver_email_job.rb.tt",
                 engine_path("app/jobs/notifications/deliver_email_job.rb")
        template "app/jobs/deliver_sms_job.rb.tt",
                 engine_path("app/jobs/notifications/deliver_sms_job.rb")
      end

      def create_subscriber
        template "app/subscribers/auth_subscriber.rb.tt",
                 engine_path("app/subscribers/notifications/auth_subscriber.rb")
      end

      def create_mailer
        template "app/mailers/application_mailer.rb.tt",
                 engine_path("app/mailers/notifications/application_mailer.rb")
        template "app/mailers/transactional_mailer.rb.tt",
                 engine_path("app/mailers/notifications/transactional_mailer.rb")
        template "app/mailers/welcome_mailer.rb.tt",
                 engine_path("app/mailers/notifications/welcome_mailer.rb")
        template "app/views/welcome_mailer/welcome.html.erb.tt",
                 engine_path("app/views/notifications/welcome_mailer/welcome.html.erb")
      end

      def create_migrations
        template "db/migrate/create_notification_deliveries.rb.tt",
                 engine_path("db/migrate/#{timestamp}_create_notification_deliveries.rb")
      end

      def create_specs
        template "spec/jobs/deliver_email_job_spec.rb.tt",
                 engine_path("spec/jobs/notifications/deliver_email_job_spec.rb")
        template "spec/adapters/action_mailer_spec.rb.tt",
                 engine_path("spec/adapters/notifications/action_mailer_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents = File.read(rubocop_path)
        replacement = "  ExposedConcerns:\n    - Notifications::Notifiable"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def report_summary
        say ""
        say "  Notifications engine generated at engines/notifications/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. `bin/rails db:migrate` to create the deliveries table"
        say "    2. Configure adapters in config/initializers/notifications.rb"
        say "    3. Run the engine specs: bin/rails seams:test[notifications]"
        say ""
        say "  Subscribed to: user.signed_up.auth (sends welcome email)"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      # Add 100 to the unix-style packed timestamp so this engine's
      # migrations don't collide with another engine generated in the
      # same second (e.g. by the same script).
      def timestamp
        base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        (base + 100).to_s
      end
    end
  end
end
