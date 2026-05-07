# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/notifications/notifications_generator"

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
    it "AuthSubscriber subscribes to user.signed_up.auth and enqueues CreateNotificationJob (no inline DB writes)" do
      assert_file "engines/notifications/app/subscribers/notifications/auth_subscriber.rb" do |content|
        expect(content).to include('Seams::Events::Publisher.attach_once(SUBSCRIBER_KEY, "user.signed_up.auth")')
        expect(content).to include("Notifications::CreateNotificationJob.perform_later")
      end
    end

    it "uses Publisher.attach_once so Rails autoreload can't double-subscribe" do
      assert_file "engines/notifications/app/subscribers/notifications/auth_subscriber.rb" do |content|
        expect(content).to include("attach_once(SUBSCRIBER_KEY")
        expect(content).not_to include("@attached =") # old class-body flag would reset on reload
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

    it "BillingSubscriber enqueues CreateNotificationJob and resolves the host User by stripe_customer_id" do
      assert_file "engines/notifications/app/subscribers/notifications/billing_subscriber.rb" do |content|
        expect(content).to include("Notifications::CreateNotificationJob.perform_later")
        expect(content).to include("stripe_customer_id")
      end
    end

    it "BillingSubscriber reads customer_ref from the canonical payload (not from a local Invoice lookup)" do
      assert_file "engines/notifications/app/subscribers/notifications/billing_subscriber.rb" do |content|
        expect(content).to include("payload[:customer_ref]")
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
        assert_file "engines/notifications/app/views/notifications/templates/billing/#{name}.erb"
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

    it "creates PreferencesController with show + update" do
      assert_file "engines/notifications/app/controllers/notifications/preferences_controller.rb" do |content|
        expect(content).to include("def show")
        expect(content).to include("def update")
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
        expect(content).to include("stream_for current_user")
      end
    end

    it "creates the notification-bell Stimulus controller" do
      assert_file "engines/notifications/app/javascript/notifications/controllers/notification_bell_controller.js" do |content|
        expect(content).to include("@hotwired/stimulus")
      end
    end
  end

  describe "default templates" do
    it "creates default + welcome ERB templates resolved from app/views/notifications/templates/" do
      assert_file "engines/notifications/app/views/notifications/templates/default.erb"
      assert_file "engines/notifications/app/views/notifications/templates/welcome.erb"
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
        "t.references :owner",
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
        engines/notifications/spec/dummy/app/models/user.rb
        engines/notifications/spec/dummy/app/controllers/application_controller.rb
        engines/notifications/spec/rails_helper.rb
      ].each do |path|
        expect(File.exist?(File.join(destination_root, path))).to be(true), "missing #{path}"
      end
    end

    it "wires runtime specs into the engine output (boot + schedule round-trip)" do
      assert_file "engines/notifications/spec/runtime/notifications_boot_spec.rb"
      assert_file "engines/notifications/spec/runtime/notifications_schedule_round_trip_spec.rb"
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
          "factory :notifications_user"
        ].each { |needle| expect(content).to include(needle) }
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
  end
end
