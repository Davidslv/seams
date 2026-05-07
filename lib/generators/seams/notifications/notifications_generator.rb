# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"

module Seams
  module Generators
    # Generates a canonical Notifications engine on top of the generic
    # engine scaffold.
    #
    # Notifications uses STI: a single +Notifications::Notification+
    # base with three concrete subclasses under +Strategies+ — InApp,
    # Email, Sms — each implementing its own +#dispatch!+. The
    # schedule lives in a jsonb column populated by ice_cube;
    # +next_delivery_at+ is the indexed cache the recurring sweeper
    # reads from.
    #
    # Run with: bin/rails generate seams:notifications
    class NotificationsGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

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

      def create_models
        template "app/models/application_record.rb.tt",
                 engine_path("app/models/notifications/application_record.rb")
        template "app/models/notification.rb.tt",
                 engine_path("app/models/notifications/notification.rb")
        template "app/models/notification_preference.rb.tt",
                 engine_path("app/models/notifications/notification_preference.rb")
        template "app/models/delivery.rb.tt",
                 engine_path("app/models/notifications/delivery.rb")
        template "app/models/strategies/in_app.rb.tt",
                 engine_path("app/models/notifications/strategies/in_app.rb")
        template "app/models/strategies/email.rb.tt",
                 engine_path("app/models/notifications/strategies/email.rb")
        template "app/models/strategies/sms.rb.tt",
                 engine_path("app/models/notifications/strategies/sms.rb")
      end

      def create_jobs
        template "app/jobs/application_job.rb.tt",
                 engine_path("app/jobs/notifications/application_job.rb")
        template "app/jobs/send_due_notifications_job.rb.tt",
                 engine_path("app/jobs/notifications/send_due_notifications_job.rb")
        template "app/jobs/send_notification_job.rb.tt",
                 engine_path("app/jobs/notifications/send_notification_job.rb")
        template "app/jobs/create_notification_job.rb.tt",
                 engine_path("app/jobs/notifications/create_notification_job.rb")
      end

      def create_subscriber
        template "app/subscribers/auth_subscriber.rb.tt",
                 engine_path("app/subscribers/notifications/auth_subscriber.rb")
        template "app/subscribers/billing_subscriber.rb.tt",
                 engine_path("app/subscribers/notifications/billing_subscriber.rb")
      end

      def create_controllers
        template "app/controllers/notifications_controller.rb.tt",
                 engine_path("app/controllers/notifications/notifications_controller.rb")
        template "app/controllers/preferences_controller.rb.tt",
                 engine_path("app/controllers/notifications/preferences_controller.rb")
      end

      def create_views
        template "app/views/notifications/_bell.html.erb.tt",
                 engine_path("app/views/notifications/notifications/_bell.html.erb")
        template "app/views/notifications/index.html.erb.tt",
                 engine_path("app/views/notifications/notifications/index.html.erb")
      end

      def create_channel_and_stimulus
        template "app/channels/notification_channel.rb.tt",
                 engine_path("app/channels/notifications/notification_channel.rb")
        template "app/javascript/controllers/notification_bell_controller.js.tt",
                 engine_path("app/javascript/notifications/controllers/notification_bell_controller.js")
      end

      def create_mailer
        template "app/mailers/application_mailer.rb.tt",
                 engine_path("app/mailers/notifications/application_mailer.rb")
        template "app/mailers/notification_mailer.rb.tt",
                 engine_path("app/mailers/notifications/notification_mailer.rb")
      end

      def create_default_templates
        template "app/views/templates/default.erb.tt",
                 engine_path("app/views/notifications/templates/default.erb")
        template "app/views/templates/welcome.erb.tt",
                 engine_path("app/views/notifications/templates/welcome.erb")
        %w[
          subscription_started
          subscription_updated
          subscription_canceled
          invoice_paid
          invoice_failed
          lifetime_granted
          lifetime_purchased
        ].each do |name|
          template "app/views/templates/billing/#{name}.erb.tt",
                   engine_path("app/views/notifications/templates/billing/#{name}.erb")
        end
      end

      def create_migrations
        template "db/migrate/create_notifications.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_notifications.rb")
        template "db/migrate/create_notification_preferences.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_notification_preferences.rb")
        template "db/migrate/create_notification_deliveries.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_create_notification_deliveries.rb")
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

      def wire_into_host
        host_inject_gem("ice_cube", ">= 0.16")
        host_inject_mount(engine_class: "Notifications::Engine", at: "/notifications")
        host_inject_include_in_user("Notifications::Notifiable")
      end

      def report_summary
        say ""
        say "  Notifications engine generated at engines/notifications/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. bundle install   (picks up ice_cube)"
        say "    2. bin/rails db:migrate"
        say "    3. Schedule the sweeper. With Solid Queue, add to config/recurring.yml:"
        say "         notifications_dispatcher:"
        say "           class: Notifications::SendDueNotificationsJob"
        say "           schedule: every minute"
        say "    4. Configure adapters in config/initializers/notifications.rb"
        say ""
        say "  Subscribed to: user.signed_up.auth (creates an InApp + Email Notification)"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      # Add 100+offset to the packed timestamp so this engine's
      # migrations don't collide with another engine generated in the
      # same second.
      def timestamp(offset = 0)
        base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        (base + 100 + offset).to_s
      end
    end
  end
end
