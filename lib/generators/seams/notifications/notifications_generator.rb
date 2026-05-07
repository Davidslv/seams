# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/dummy_app_writer"

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
    # rubocop:disable Metrics/ClassLength
    class NotificationsGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME      = "notifications"
      DEFAULT_CHANNELS = %w[in_app email sms].freeze
      BILLING_TEMPLATES = %w[
        subscription_started
        subscription_updated
        subscription_canceled
        invoice_paid
        invoice_failed
        lifetime_granted
        lifetime_purchased
      ].freeze

      class_option :channels, type: :string, default: "all",
                              desc: "Comma-separated channels to enable: in_app,email,sms (or 'all')"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt", engine_path("lib/notifications/engine.rb"), force: true
      end

      def create_configuration
        template "lib/configuration.rb.tt",  engine_path("lib/notifications/configuration.rb")
        template "lib/type_registry.rb.tt",  engine_path("lib/notifications/type_registry.rb")
        template "lib/notifications.rb.tt",  engine_path("lib/notifications.rb"), force: true
      end

      def create_adapters
        template "lib/adapters/abstract.rb.tt",      engine_path("lib/notifications/adapters/abstract.rb")
        template "lib/adapters/action_mailer.rb.tt", engine_path("lib/notifications/adapters/action_mailer.rb")
        # SMS adapter only ships when the sms channel is enabled.
        return unless channels.include?("sms")

        template "lib/adapters/null_sms.rb.tt", engine_path("lib/notifications/adapters/null_sms.rb")
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
        create_strategy_models
      end

      def create_strategy_models
        # STI strategy subclasses ship per --channels selection.
        # STRATEGY_CLASSES in the Notifiable concern is conditionally
        # rendered (in_app/email/sms) to match.
        channels.each do |channel|
          template "app/models/strategies/#{channel}.rb.tt",
                   engine_path("app/models/notifications/strategies/#{channel}.rb")
        end
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
        # Each notification template ships in two formats — .text.erb
        # for SMS / plain-text email + .html.erb for HTML email and
        # in-app rendering. Hosts override either or both by dropping
        # files at app/views/notifications/templates/<name>.<format>.erb.
        %i[text html].each do |format|
          template "app/views/templates/default.#{format}.erb.tt",
                   engine_path("app/views/notifications/templates/default.#{format}.erb")
          template "app/views/templates/welcome.#{format}.erb.tt",
                   engine_path("app/views/notifications/templates/welcome.#{format}.erb")
          BILLING_TEMPLATES.each do |name|
            template "app/views/templates/billing/#{name}.#{format}.erb.tt",
                     engine_path("app/views/notifications/templates/billing/#{name}.#{format}.erb")
          end
        end

        # Mailer layout — wraps every notification email so hosts get
        # consistent header/footer chrome without per-template repetition.
        template "app/views/layouts/notifications/mailer.html.erb.tt",
                 engine_path("app/views/layouts/notifications/mailer.html.erb")
        template "app/views/layouts/notifications/mailer.text.erb.tt",
                 engine_path("app/views/layouts/notifications/mailer.text.erb")
      end

      def create_migrations
        template "db/migrate/create_notifications.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_notifications.rb")
        template "db/migrate/create_notification_preferences.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_notification_preferences.rb")
        template "db/migrate/create_notification_deliveries.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_create_notification_deliveries.rb")
      end

      def create_specs
        # Phase 2B finish — coverage for the engine's three core models.
        template "spec/factories/notifications.rb.tt",
                 engine_path("spec/factories/notifications.rb")
        template "spec/models/notification_spec.rb.tt",
                 engine_path("spec/models/notifications/notification_spec.rb")
        template "spec/models/delivery_spec.rb.tt",
                 engine_path("spec/models/notifications/delivery_spec.rb")
        template "spec/models/notification_preference_spec.rb.tt",
                 engine_path("spec/models/notifications/notification_preference_spec.rb")
      end

      def create_dummy_app
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Notifications",
          mount_at: "/notifications",
          schema: dummy_schema,
          host_user: dummy_host_user
        )
        # Wire the runtime spec templates into the generator output —
        # they were orphaned in templates/ pre-Wave-12 (the integration
        # test silently skipped them).
        template "spec/runtime/boot_spec.rb.tt",
                 engine_path("spec/runtime/notifications_boot_spec.rb")
        template "spec/runtime/schedule_round_trip_spec.rb.tt",
                 engine_path("spec/runtime/notifications_schedule_round_trip_spec.rb")
        # Phase 2B (3/3) — bell + ActionCable broadcast verification.
        return unless channels.include?("in_app")

        template "spec/runtime/bell_broadcast_spec.rb.tt",
                 engine_path("spec/runtime/notifications_bell_broadcast_spec.rb")
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
        # factory_bot_rails powers the engine's spec/factories/*. Lives
        # in the host's test group only.
        host_inject_gem("factory_bot_rails", "~> 6.4", group: :test)
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

      # Resolved list of channels the host opted into via --channels.
      # "all" (or empty / unrecognised) → all three. Memoised per
      # generator run so conditional template branches stay consistent.
      def channels
        @channels ||= begin
          raw = options[:channels].to_s.downcase.strip
          if raw.empty? || raw == "all"
            DEFAULT_CHANNELS.dup
          else
            requested = raw.split(",").map(&:strip).reject(&:empty?)
            allowed   = requested & DEFAULT_CHANNELS
            allowed.empty? ? DEFAULT_CHANNELS.dup : allowed
          end
        end
      end

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

      def dummy_schema
        <<~SCHEMA
          create_table :users do |t|
            t.string :email, null: false
            t.timestamps
          end
          add_index :users, :email, unique: true

          create_table :notifications do |t|
            t.string  :type,             null: false
            t.references :owner,         polymorphic: true, null: false, index: true
            t.string  :recipient
            t.string  :template,         null: false
            t.jsonb   :schedule_data
            t.datetime :next_delivery_at
            t.datetime :read_at
            t.timestamps
          end
          add_index :notifications, :next_delivery_at

          create_table :notification_preferences do |t|
            t.bigint  :user_id,           null: false
            t.string  :channel,           null: false
            t.string  :notification_type
            t.boolean :enabled,           null: false, default: true
            t.timestamps
          end
          add_index :notification_preferences, %i[user_id channel notification_type], unique: true,
                                                                                       name: "index_notification_prefs_unique"

          create_table :notification_deliveries do |t|
            t.references :notification, null: false, foreign_key: true, index: true
            t.datetime   :sent_at,      null: false
            t.timestamps
          end
        SCHEMA
      end

      def dummy_host_user
        <<~RB
          # frozen_string_literal: true

          class User < ApplicationRecord
            include Notifications::Notifiable
          end
        RB
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
