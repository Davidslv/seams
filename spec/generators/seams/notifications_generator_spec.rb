# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/notifications/notifications_generator"

NOTIF_TEMPLATE_FORMATS = %w[text html].freeze
NOTIF_BASE_TEMPLATES   = %w[default welcome].freeze
NOTIF_BILLING_TEMPLATES = %w[
  subscription_started subscription_updated subscription_canceled
  invoice_paid invoice_failed lifetime_granted lifetime_purchased
].freeze

RSpec.describe Seams::Generators::NotificationsGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/notifications_generator", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
  end

  def run_generator
    described_class.start([], destination_root: destination_root)
  end

  def assert_file(path)
    full = File.join(destination_root, path)
    expect(File.exist?(full)).to be(true), "expected #{path} to be created"
    yield(File.read(full)) if block_given?
  end

  before do
    prepare_destination
    run_generator
  end

  describe "engine entry point" do
    it "registers the three canonical notification events" do
      assert_file "engines/notifications/lib/notifications/engine.rb" do |content|
        expect(content).to include('"notification.queued.notifications"')
        expect(content).to include('"notification.delivered.notifications"')
        expect(content).to include('"notification.failed.notifications"')
      end
    end

    it "attaches the AuthSubscriber after_initialize" do
      assert_file "engines/notifications/lib/notifications/engine.rb" do |content|
        expect(content).to include("Notifications::AuthSubscriber.attach!")
      end
    end
  end

  describe "STI Notification base + strategy subclasses" do
    it "creates the STI Notification base with PERMITTED_TYPES" do
      assert_file "engines/notifications/app/models/notifications/notification.rb" do |content|
        expect(content).to include("class Notification < ApplicationRecord")
        expect(content).to include("PERMITTED_TYPES")
        expect(content).to include("Notifications::Strategies::InApp")
        expect(content).to include("Notifications::Strategies::Email")
        expect(content).to include("Notifications::Strategies::Sms")
      end
    end

    it "exposes ice_cube schedule + schedule_config= setters and advance!" do
      assert_file "engines/notifications/app/models/notifications/notification.rb" do |content|
        expect(content).to include("IceCube::Schedule.from_hash(schedule_data)")
        expect(content).to include("def schedule_config=")
        expect(content).to include("def advance!")
        expect(content).to include("next_occurrence")
      end
    end

    it "publishes the lifecycle events around send!" do
      assert_file "engines/notifications/app/models/notifications/notification.rb" do |content|
        expect(content).to include('"notification.queued.notifications"')
        expect(content).to include('"notification.delivered.notifications"')
        expect(content).to include('"notification.failed.notifications"')
      end
    end

    it "creates the InApp strategy that broadcasts on ActionCable" do
      assert_file "engines/notifications/app/models/notifications/strategies/in_app.rb" do |content|
        expect(content).to include("class InApp < Notification")
        expect(content).to include("Notifications::NotificationChannel.broadcast_to")
      end
    end

    it "creates the Email strategy that delegates to the email adapter" do
      assert_file "engines/notifications/app/models/notifications/strategies/email.rb" do |content|
        expect(content).to include("class Email < Notification")
        expect(content).to include("Notifications.email_adapter.deliver(notification: self)")
      end
    end

    it "Email strategy resolves recipient via try-chain (concern OR email_address OR email)" do
      assert_file "engines/notifications/app/models/notifications/strategies/email.rb" do |content|
        # The polymorphic owner might be Auth::Identity (uses :email),
        # a host User (uses :email_address or :email), or any AR model
        # via the optional Notifiable concern (#email_notification_recipient).
        expect(content).to include("try(:email_notification_recipient)")
        expect(content).to include("try(:email_address)")
        expect(content).to include("try(:email)")
      end
    end

    it "creates the Sms strategy that delegates to the sms adapter" do
      assert_file "engines/notifications/app/models/notifications/strategies/sms.rb" do |content|
        expect(content).to include("class Sms < Notification")
        expect(content).to include("Notifications.sms_adapter.deliver(notification: self)")
      end
    end

    it "creates the Delivery audit model" do
      assert_file "engines/notifications/app/models/notifications/delivery.rb" do |content|
        expect(content).to include("class Delivery < ApplicationRecord")
        expect(content).to include("belongs_to :notification")
      end
    end
  end

  describe "configuration" do
    it "defines a Notifications::Configuration with email + sms adapter knobs" do
      assert_file "engines/notifications/lib/notifications/configuration.rb" do |content|
        expect(content).to include("attr_accessor :email_adapter, :sms_adapter")
      end
    end

    it "wires Notifications.configure / .email_adapter / .sms_adapter" do
      assert_file "engines/notifications/lib/notifications.rb" do |content|
        expect(content).to include("def configure")
        expect(content).to include("def email_adapter")
        expect(content).to include("def sms_adapter")
      end
    end
  end

  describe "adapters (deliver(notification:))" do
    it "creates the abstract adapter that takes a Notification" do
      assert_file "engines/notifications/lib/notifications/adapters/abstract.rb" do |content|
        expect(content).to include("def deliver(notification:)")
        expect(content).to include("raise NotImplementedError")
      end
    end

    it "ActionMailer adapter delegates to NotificationMailer" do
      assert_file "engines/notifications/lib/notifications/adapters/action_mailer.rb" do |content|
        expect(content).to include("Notifications::NotificationMailer.notify(notification)")
      end
    end

    it "NullSms adapter logs via Seams::Observability" do
      assert_file "engines/notifications/lib/notifications/adapters/null_sms.rb" do |content|
        expect(content).to include("Seams::Observability.adapter.info")
      end
    end
  end

  describe "Notifiable concern" do
    it "exposes the notifications association + #notify helper" do
      assert_file "engines/notifications/lib/notifications/concerns/notifiable.rb" do |content|
        expect(content).to include('require "active_support/concern"')
        expect(content).to include("has_many :notifications")
        expect(content).to include("def notify(strategy:")
        expect(content).to include("STRATEGY_CLASSES")
      end
    end

    it "registers Notifications::Notifiable in the engine's ExposedConcerns rubocop list" do
      assert_file "engines/notifications/.rubocop.yml" do |content|
        expect(content).to include("Notifications::Notifiable")
      end
    end
  end

  describe "jobs" do
    it "creates Notifications::ApplicationJob extending the host's ApplicationJob" do
      assert_file "engines/notifications/app/jobs/notifications/application_job.rb" do |content|
        expect(content).to include("class ApplicationJob < ::ApplicationJob")
      end
    end

    it "creates SendDueNotificationsJob (the recurring sweeper)" do
      assert_file "engines/notifications/app/jobs/notifications/send_due_notifications_job.rb" do |content|
        expect(content).to include("queue_as :notifications")
        expect(content).to include("Notification.due.find_each(&:send_async)")
      end
    end

    it "creates SendNotificationJob (per-row send!)" do
      assert_file "engines/notifications/app/jobs/notifications/send_notification_job.rb" do |content|
        expect(content).to include("Notifications::Notification.find_by(id: notification_id)&.send!")
      end
    end
  end

  describe "subscriber" do
    it "AuthSubscriber subscribes to identity.signed_up.auth and enqueues CreateNotificationJob (no inline DB writes)" do
      assert_file "engines/notifications/app/subscribers/notifications/auth_subscriber.rb" do |content|
        expect(content).to include("Seams::Events::Publisher.attach_class(")
        expect(content).to include('"identity.signed_up.auth"')
        expect(content).to include('class_name:  "Notifications::AuthSubscriber"')
        expect(content).to include("method_name: :handle_signed_up")
        expect(content).to include("Notifications::CreateNotificationJob.perform_later")
      end
    end

    it "AuthSubscriber resolves the welcome notification owner via Auth::Identity (the canonical Wave-9 owner)" do
      assert_file "engines/notifications/app/subscribers/notifications/auth_subscriber.rb" do |content|
        expect(content).to include('OWNER_CLASS_NAME = "Auth::Identity"')
        expect(content).to include("identity_id = payload[:identity_id]")
        # Old payload keys are gone — Wave 9 dropped host_user_id /
        # auth_user_id from the auth event payload.
        expect(content).not_to include("host_user_id")
        expect(content).not_to include("auth_user_id")
      end
    end

    it "uses Publisher.attach_class so Rails autoreload can't double-subscribe AND survives reload of the subscriber file" do
      assert_file "engines/notifications/app/subscribers/notifications/auth_subscriber.rb" do |content|
        expect(content).to include("attach_class(")
        expect(content).to include("SUBSCRIBER_KEY")
        # attach_class re-resolves the class via Object.const_get on every
        # event, so a reload of the subscriber file picks up handler edits
        # without a server restart. A captured block (attach_once { ... })
        # would close over the pre-reload class object — reload-stale.
        expect(content).not_to include("attach_once(SUBSCRIBER_KEY")
        expect(content).not_to include("@attached =")
      end
    end

    it "consults NotificationPreference before creating the email" do
      assert_file "engines/notifications/app/subscribers/notifications/auth_subscriber.rb" do |content|
        expect(content).to include("NotificationPreference.enabled?")
      end
    end

    it "BillingSubscriber subscribes to all four billing lifecycle events" do
      assert_file "engines/notifications/app/subscribers/notifications/billing_subscriber.rb" do |content|
        %w[subscription.created.billing subscription.updated.billing subscription.canceled.billing invoice.paid.billing invoice.failed.billing].each do |event|
          expect(content).to include(%("#{event}"))
        end
      end
    end

    it "BillingSubscriber enqueues CreateNotificationJob and resolves the recipient via Wave-9 account_id" do
      assert_file "engines/notifications/app/subscribers/notifications/billing_subscriber.rb" do |content|
        expect(content).to include("Notifications::CreateNotificationJob.perform_later")
        # Wave 9: the canonical billing payload carries account_id directly;
        # there's no host-User lookup by stripe_customer_id any more.
        expect(content).to include("payload[:account_id]")
        expect(content).not_to include("stripe_customer_id")
      end
    end

    it "BillingSubscriber addresses the Notification owner via the configured billable_class" do
      assert_file "engines/notifications/app/subscribers/notifications/billing_subscriber.rb" do |content|
        # Default `Accounts::Account` (the canonical Wave-9 tenant), but
        # respects a host's `Billing.configuration.billable_class` override.
        expect(content).to include("Billing.configuration.billable_class")
        expect(content).to include("Accounts::Account")
        expect(content).not_to include("Billing::Invoice")
      end
    end

    it "engine.rb attaches BillingSubscriber only when Billing::Engine is loaded" do
      assert_file "engines/notifications/lib/notifications/engine.rb" do |content|
        expect(content).to include("Notifications::BillingSubscriber.attach! if defined?(Billing::Engine)")
      end
    end

    it "ships default ERB templates for all seven billing notifications (incl. LTD)" do
      %w[
        subscription_started
        subscription_updated
        subscription_canceled
        invoice_paid
        invoice_failed
        lifetime_granted
        lifetime_purchased
      ].each do |name|
        assert_file "engines/notifications/app/views/notifications/templates/billing/#{name}.text.erb"
      end
    end

    it "BillingSubscriber consumes the two LTD events" do
      assert_file "engines/notifications/app/subscribers/notifications/billing_subscriber.rb" do |content|
        expect(content).to include('"lifetime.granted.billing"')
        expect(content).to include('"lifetime.purchased.billing"')
      end
    end
  end

  describe "preferences model" do
    it "creates NotificationPreference with .enabled? lookup helper" do
      assert_file "engines/notifications/app/models/notifications/notification_preference.rb" do |content|
        expect(content).to include("class NotificationPreference")
        expect(content).to include("def self.enabled?")
      end
    end

    it "NotificationPreference keys off identity_id (Wave 9 rename — channel prefs live with the human)" do
      assert_file "engines/notifications/app/models/notifications/notification_preference.rb" do |content|
        expect(content).to include("validates :identity_id")
        expect(content).to include("def self.enabled?(identity_id:")
        expect(content).to include("find_by(identity_id: identity_id")
        # No leftovers from the pre-Wave-9 user_id key.
        expect(content).not_to match(/\buser_id\b/)
      end
    end
  end

  describe "read-side controllers" do
    it "creates NotificationsController scoped to InApp + the four actions" do
      assert_file "engines/notifications/app/controllers/notifications/notifications_controller.rb" do |content|
        expect(content).to include("def index")
        expect(content).to include("def mark_as_read")
        expect(content).to include("def mark_all_as_read")
        expect(content).to include("Notifications::Strategies::InApp")
      end
    end

    # Regression: pre-Wave-9 the controller resolved `current_user`, but
    # Auth::Authentication ships `current_identity` post-Wave-9 — every
    # action was returning empty / failing to find notifications.
    it "NotificationsController#current_recipient prefers Auth::Current.identity" do
      assert_file "engines/notifications/app/controllers/notifications/notifications_controller.rb" do |content|
        expect(content).to include("def current_recipient")
        expect(content).to include("Auth::Current")
      end
    end

    it "creates PreferencesController with show + update" do
      assert_file "engines/notifications/app/controllers/notifications/preferences_controller.rb" do |content|
        expect(content).to include("def show")
        expect(content).to include("def update")
      end
    end

    # Regression: pre-Wave-9 the controller queried `user_id`, but the
    # migration creates `identity_id` — every GET / PATCH was raising
    # ActiveRecord::StatementInvalid in canonical hosts.
    it "PreferencesController queries identity_id (not user_id) and reads Auth::Current.identity" do
      assert_file "engines/notifications/app/controllers/notifications/preferences_controller.rb" do |content|
        expect(content).to include("identity_id: current_identity_id")
        expect(content).to include("def current_identity_id")
        expect(content).to include("Auth::Current")
        expect(content).not_to match(/\buser_id\b/)
        expect(content).not_to include("def current_user_id")
      end
    end

    # Security: the generated controller must be brakeman-clean out of
    # the box. permit! is a mass-assignment risk (OWASP A03); the
    # registry-driven explicit permit list replaces it.
    it "PreferencesController uses the registry-driven explicit permit list instead of permit!" do
      assert_file "engines/notifications/app/controllers/notifications/preferences_controller.rb" do |content|
        expect(content).to include("Notifications::Preferences.allowed_keys")
        expect(content).to include("params.require(:preferences).permit(*Notifications::Preferences.allowed_keys)")
        expect(content).not_to include("permit!")
      end
    end
  end

  describe "Preferences key registry" do
    it "ships lib/notifications/preferences.rb with Notifications::Preferences.allowed_keys" do
      assert_file "engines/notifications/lib/notifications/preferences.rb" do |content|
        expect(content).to include("module Preferences")
        expect(content).to include("def allowed_keys")
        expect(content).to include("Notifications::NotificationPreference::CHANNELS")
        expect(content).to include("Notifications::TypeRegistry.names")
      end
    end

    it "lib/notifications.rb requires notifications/preferences" do
      assert_file "engines/notifications/lib/notifications.rb" do |content|
        expect(content).to include('require "notifications/preferences"')
      end
    end
  end

  describe "views + ActionCable + Stimulus" do
    it "creates the bell partial + index view" do
      assert_file "engines/notifications/app/views/notifications/notifications/_bell.html.erb"
      assert_file "engines/notifications/app/views/notifications/notifications/index.html.erb"
    end

    it "creates the per-recipient ActionCable channel" do
      assert_file "engines/notifications/app/channels/notifications/notification_channel.rb" do |content|
        expect(content).to include("class NotificationChannel")
        expect(content).to include("stream_for current_recipient")
        # Wave 9: prefer Auth's `current_identity` exposed by the
        # ApplicationCable connection. Old `current_user` is the
        # legacy fallback only.
        expect(content).to include("connection.current_identity")
      end
    end

    it "creates the notification-bell Stimulus controller" do
      assert_file "engines/notifications/app/javascript/notifications/controllers/notification_bell_controller.js" do |content|
        expect(content).to include("@hotwired/stimulus")
      end
    end
  end

  describe "default templates" do
    it "creates default + welcome ERB templates (text variant) resolved from app/views/notifications/templates/" do
      assert_file "engines/notifications/app/views/notifications/templates/default.text.erb"
      assert_file "engines/notifications/app/views/notifications/templates/welcome.text.erb"
    end
  end

  describe "mailer (single)" do
    it "creates Notifications::NotificationMailer that dispatches via the template chain" do
      assert_file "engines/notifications/app/mailers/notifications/notification_mailer.rb" do |content|
        expect(content).to include("class NotificationMailer < ApplicationMailer")
        expect(content).to include("def notify(notification)")
      end
    end

    it "creates Notifications::ApplicationMailer extending the host's ApplicationMailer" do
      assert_file "engines/notifications/app/mailers/notifications/application_mailer.rb" do |content|
        expect(content).to include("class ApplicationMailer < ::ApplicationMailer")
      end
    end
  end

  describe "migrations" do
    let(:create_notifications_needles) do
      [
        "create_table :notifications",
        "t.string  :type",
        # Wave 9: polymorphic owner stored as string columns so the
        # column holds both bigint Identity IDs and UUID Account IDs.
        "t.string  :owner_type",
        "t.string  :owner_id",
        "schedule_data",
        "next_delivery_at"
      ]
    end

    it "creates create_notifications with STI + schedule_data + next_delivery_at" do
      pattern = File.join(destination_root,
                          "engines/notifications/db/migrate",
                          "*_create_notifications.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      create_notifications_needles.each { |needle| expect(content).to include(needle) }
    end

    it "creates create_notification_preferences" do
      pattern = File.join(destination_root,
                          "engines/notifications/db/migrate",
                          "*_create_notification_preferences.rb")
      expect(Dir[pattern].first).not_to be_nil
    end

    it "create_notification_preferences keys off identity_id (Wave 9 rename)" do
      pattern = File.join(destination_root,
                          "engines/notifications/db/migrate",
                          "*_create_notification_preferences.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include(":identity_id")
      expect(content).to include("%i[identity_id channel notification_type]")
      expect(content).not_to match(/:user_id\b/)
    end

    it "creates create_notification_deliveries (audit) with notification_id + sent_at" do
      pattern = File.join(destination_root,
                          "engines/notifications/db/migrate",
                          "*_create_notification_deliveries.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :notification_deliveries")
      expect(content).to include("t.references :notification")
      expect(content).to include("t.datetime   :sent_at")
    end
  end

  describe "host wiring" do
    it "adds ice_cube to the host Gemfile when one exists" do
      # Reset to a fresh destination with a Gemfile in place this time.
      FileUtils.rm_rf(destination_root)
      FileUtils.mkdir_p(destination_root)
      FileUtils.mkdir_p(File.join(destination_root, "engines"))
      File.write(File.join(destination_root, "Gemfile"), "source \"https://rubygems.org\"\n")

      run_generator
      expect(File.read(File.join(destination_root, "Gemfile"))).to include('gem "ice_cube"')
    end
  end

  describe "documentation" do
    it "rewrites the README with the canonical events table" do
      assert_file "engines/notifications/README.md" do |content|
        expect(content).to include("notification.queued.notifications")
        expect(content).to include("Notifications::Notifiable")
        expect(content).to include("Strategies::InApp")
      end
    end
  end

  describe "Phase 2B — dummy app + factories + spec coverage" do
    it "writes a per-engine dummy app with the notifications schema" do
      %w[
        engines/notifications/spec/dummy/config/application.rb
        engines/notifications/spec/dummy/db/schema.rb
        engines/notifications/spec/dummy/app/models/auth/identity.rb
        engines/notifications/spec/dummy/app/controllers/application_controller.rb
        engines/notifications/spec/rails_helper.rb
      ].each do |path|
        expect(File.exist?(File.join(destination_root, path))).to be(true), "missing #{path}"
      end
    end

    it "wires runtime specs into the engine output (boot + schedule round-trip + billing skip)" do
      assert_file "engines/notifications/spec/runtime/notifications_boot_spec.rb"
      assert_file "engines/notifications/spec/runtime/notifications_schedule_round_trip_spec.rb"
      assert_file "engines/notifications/spec/runtime/notifications_billing_subscriber_skip_spec.rb" do |content|
        # The skip spec must assert against the actual warn key the
        # subscriber emits — drift on either side is the bug we're
        # gating against.
        expect(content).to include("notifications.billing_subscriber.skip")
        expect(content).to include("Seams::Observability.adapter")
      end
    end

    it "ships FactoryBot factories covering all 3 strategies + delivery + preference" do
      assert_file "engines/notifications/spec/factories/notifications.rb" do |content|
        [
          "FactoryBot.define",
          "factory :notification",
          "factory :in_app_notification",
          "factory :email_notification",
          "factory :sms_notification",
          "factory :notification_delivery",
          "factory :notification_preference",
          # Wave 9: :auth_identity is the canonical owner factory; the
          # legacy :notifications_user alias points at it.
          "factory :auth_identity",
          "factory :notifications_user"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "the :notification_preference factory keys off identity_id (post-Wave-9)" do
      assert_file "engines/notifications/spec/factories/notifications.rb" do |content|
        expect(content).to include("sequence(:identity_id)")
        expect(content).not_to include("sequence(:user_id)")
      end
    end

    it "ships Notification model spec covering STI, validations, and scopes" do
      assert_file "engines/notifications/spec/models/notifications/notification_spec.rb" do |content|
        [
          "Notifications::Strategies::InApp",
          "Notifications::Strategies::Email",
          "scopes",
          ".due",
          ".unread",
          "rejects template paths with traversal segments"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships Delivery model spec covering association + dependent destroy" do
      assert_file "engines/notifications/spec/models/notifications/delivery_spec.rb" do |content|
        [
          "RSpec.describe Notifications::Delivery",
          "is destroyed when its parent notification is destroyed",
          "ActiveRecord::NotNullViolation"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships NotificationPreference model spec covering .enabled? fallback chain" do
      assert_file "engines/notifications/spec/models/notifications/notification_preference_spec.rb" do |content|
        [
          "RSpec.describe Notifications::NotificationPreference",
          ".enabled?",
          "default-on",
          "falls back to the channel-wide row"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "wire_into_host adds factory_bot_rails to the test group" do
      gen_path = File.expand_path(
        "../../../lib/generators/seams/notifications/notifications_generator.rb",
        __dir__
      )
      content = File.read(gen_path)
      expect(content).to include('host_inject_gem("factory_bot_rails"')
      expect(content).to include("group: :test")
    end

    it "wire_into_host no longer auto-includes Notifiable into a host User (Wave 9 dropped that)" do
      gen_path = File.expand_path(
        "../../../lib/generators/seams/notifications/notifications_generator.rb",
        __dir__
      )
      content = File.read(gen_path)
      # The auto-include was the source of the host-User coupling
      # Wave 9 removed; hosts now opt in via the initializer template.
      expect(content).not_to include("host_inject_include_in_user")
    end

    it "ships a host config/initializers/notifications.rb that documents the optional Notifiable include" do
      assert_file "config/initializers/notifications.rb" do |content|
        expect(content).to include("Auth::Identity.include(Notifications::Notifiable)")
        expect(content).to include("Notifications.configure")
      end
    end
  end

  describe "TypeRegistry (Phase 2B (2/3))" do
    it "ships the TypeRegistry module" do
      assert_file "engines/notifications/lib/notifications/type_registry.rb" do |content|
        [
          "module TypeRegistry",
          "Type = Struct.new",
          "def register",
          "def fetch",
          "UnknownType",
          "Mutex.new"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "lib/notifications.rb seeds default cross-engine types" do
      assert_file "engines/notifications/lib/notifications.rb" do |content|
        [
          'require "notifications/type_registry"',
          "def seed_default_types!",
          "welcome",
          "billing.invoice_paid",
          "billing.subscription_started",
          "billing.lifetime_purchased"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Notifiable concern adds notify_typed that resolves a TypeRegistry entry" do
      assert_file "engines/notifications/lib/notifications/concerns/notifiable.rb" do |content|
        [
          "def notify_typed",
          "Notifications::TypeRegistry.fetch",
          "Notifications::NotificationPreference.enabled?"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "--channels generator flag (Phase 2B (2/3))" do
    let(:flag_destination) { File.expand_path("../../../tmp/notifications_channels", __dir__) }

    def run_with_channels(channels)
      FileUtils.rm_rf(flag_destination)
      FileUtils.mkdir_p(flag_destination)
      FileUtils.mkdir_p(File.join(flag_destination, "engines"))
      described_class.start(["--channels=#{channels}"], destination_root: flag_destination)
    end

    it "default (no flag) ships all three strategies + null_sms adapter" do
      assert_file "engines/notifications/app/models/notifications/strategies/in_app.rb"
      assert_file "engines/notifications/app/models/notifications/strategies/email.rb"
      assert_file "engines/notifications/app/models/notifications/strategies/sms.rb"
      assert_file "engines/notifications/lib/notifications/adapters/null_sms.rb"
    end

    it "--channels=in_app,email omits the SMS strategy + null_sms adapter" do
      run_with_channels("in_app,email")

      expect(File.exist?(File.join(flag_destination,
                                   "engines/notifications/app/models/notifications/strategies/in_app.rb"))).to be(true)
      expect(File.exist?(File.join(flag_destination,
                                   "engines/notifications/app/models/notifications/strategies/email.rb"))).to be(true)
      expect(File.exist?(File.join(flag_destination,
                                   "engines/notifications/app/models/notifications/strategies/sms.rb"))).to be(false)
      expect(File.exist?(File.join(flag_destination,
                                   "engines/notifications/lib/notifications/adapters/null_sms.rb"))).to be(false)
    end

    it "--channels=in_app,email rewrites STRATEGY_CLASSES without :sms" do
      run_with_channels("in_app,email")

      content = File.read(File.join(flag_destination,
                                    "engines/notifications/lib/notifications/concerns/notifiable.rb"))
      expect(content).to include("email:  \"Notifications::Strategies::Email\"")
      expect(content).to include("in_app: \"Notifications::Strategies::InApp\"")
      expect(content).not_to include("Notifications::Strategies::Sms")
    end

    it "--channels=garbage,unknown falls back to all three (no destructive interpretation)" do
      run_with_channels("garbage,unknown")
      assert_file "engines/notifications/app/models/notifications/strategies/sms.rb"
    end
  end

  describe "HTML + text template variants (Phase 2B (3/3))" do
    it "ships .text.erb + .html.erb pairs for every default template" do
      NOTIF_BASE_TEMPLATES.each do |name|
        NOTIF_TEMPLATE_FORMATS.each do |fmt|
          assert_file "engines/notifications/app/views/notifications/templates/#{name}.#{fmt}.erb"
        end
      end

      NOTIF_BILLING_TEMPLATES.each do |name|
        NOTIF_TEMPLATE_FORMATS.each do |fmt|
          assert_file "engines/notifications/app/views/notifications/templates/billing/#{name}.#{fmt}.erb"
        end
      end
    end

    it "ships HTML + text mailer layouts" do
      assert_file "engines/notifications/app/views/layouts/notifications/mailer.html.erb" do |content|
        expect(content).to include("<%= yield %>")
      end
      assert_file "engines/notifications/app/views/layouts/notifications/mailer.text.erb" do |content|
        expect(content).to include("<%= yield %>")
      end
    end

    it "NotificationMailer renders multipart with the layout" do
      assert_file "engines/notifications/app/mailers/notifications/notification_mailer.rb" do |content|
        [
          "format.text { render plain: text_body, layout: \"notifications/mailer\"",
          "format.html { render html: html_body.html_safe, layout: \"notifications/mailer\"",
          "template_exists?(format: :html)"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Notification#rendered_content + #template_exists? accept a format keyword" do
      assert_file "engines/notifications/app/models/notifications/notification.rb" do |content|
        [
          "def rendered_content(format: :text)",
          "def template_exists?(format: :text)",
          "def find_template_path(format: :text)",
          "PERMITTED_FORMATS = %i[text html].freeze",
          "raise(Notifications::Error"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "bell + ActionCable broadcast spec (Phase 2B (3/3))" do
    it "ships the bell broadcast runtime spec when in_app channel is enabled" do
      assert_file "engines/notifications/spec/runtime/notifications_bell_broadcast_spec.rb" do |content|
        [
          "Notifications::NotificationChannel",
          "broadcast_to",
          "rendered_content(format: :html)",
          "rendered_content(format: :text)",
          "unread_in_app_notifications"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  # Wave 10 Phase 2A: every catalogued insertion-point marker the
  # notifications engine ships must appear in its target file. These
  # assertions gate against accidental marker removal in future
  # template edits. See doc/INSERTION_POINTS_CATALOGUE.md for the
  # canonical list.
  describe "insertion-point markers (Wave 10)" do
    {
      "notifications.engine.events" => "engines/notifications/lib/notifications/engine.rb",
      "notifications.engine.subscribers" => "engines/notifications/lib/notifications/engine.rb",
      "notifications.configuration.attributes" => "engines/notifications/lib/notifications/configuration.rb",
      "notifications.configuration.defaults" => "engines/notifications/lib/notifications/configuration.rb",
      "notifications.notifiable.strategies" => "engines/notifications/lib/notifications/concerns/notifiable.rb",
      "notifications.type_registry.defaults" => "engines/notifications/lib/notifications.rb",
      "notifications.routes.after_preferences" => "engines/notifications/config/routes.rb"
    }.each do |marker, path|
      it "ships #{marker} in #{path}" do
        assert_file path do |content|
          expect(content).to include("# seams:insertion-point #{marker}")
        end
      end
    end
  end
end
