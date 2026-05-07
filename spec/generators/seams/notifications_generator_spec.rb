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
        expect(content).to include('Seams::EventRegistry.register("notification.queued.notifications"')
        expect(content).to include('Seams::EventRegistry.register("notification.delivered.notifications"')
        expect(content).to include('Seams::EventRegistry.register("notification.failed.notifications"')
      end
    end

    it "attaches the AuthSubscriber after_initialize" do
      assert_file "engines/notifications/lib/notifications/engine.rb" do |content|
        expect(content).to include("Notifications::AuthSubscriber.attach!")
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

  describe "adapters" do
    it "creates the abstract adapter that raises NotImplementedError" do
      assert_file "engines/notifications/lib/notifications/adapters/abstract.rb" do |content|
        expect(content).to include("raise NotImplementedError")
      end
    end

    it "creates the ActionMailer adapter" do
      assert_file "engines/notifications/lib/notifications/adapters/action_mailer.rb" do |content|
        expect(content).to include("class ActionMailer < Abstract")
      end
    end

    it "creates the NullSms adapter" do
      assert_file "engines/notifications/lib/notifications/adapters/null_sms.rb" do |content|
        expect(content).to include("class NullSms < Abstract")
      end
    end
  end

  describe "concern" do
    it "creates Notifications::Notifiable with notify_email and notify_sms" do
      assert_file "engines/notifications/lib/notifications/concerns/notifiable.rb" do |content|
        expect(content).to include("def notify_email")
        expect(content).to include("def notify_sms")
      end
    end

    it "registers Notifications::Notifiable in the engine's ExposedConcerns rubocop list" do
      assert_file "engines/notifications/.rubocop.yml" do |content|
        expect(content).to include("Notifications::Notifiable")
      end
    end
  end

  describe "jobs" do
    it "creates DeliverEmailJob with queue + event publishing" do
      assert_file "engines/notifications/app/jobs/notifications/deliver_email_job.rb" do |content|
        expect(content).to include("queue_as :notifications")
        expect(content).to include('"notification.queued.notifications"')
        expect(content).to include('"notification.delivered.notifications"')
        expect(content).to include('"notification.failed.notifications"')
      end
    end

    it "creates DeliverSmsJob with queue + event publishing" do
      assert_file "engines/notifications/app/jobs/notifications/deliver_sms_job.rb" do |content|
        expect(content).to include("queue_as :notifications")
      end
    end
  end

  describe "subscriber" do
    it "creates AuthSubscriber that subscribes to user.signed_up.auth and enqueues DeliverEmailJob" do
      assert_file "engines/notifications/app/subscribers/notifications/auth_subscriber.rb" do |content|
        expect(content).to include('Seams::Events::Publisher.subscribe("user.signed_up.auth")')
        expect(content).to include("DeliverEmailJob.perform_later")
      end
    end
  end

  describe "mailer" do
    it "creates WelcomeMailer + html template" do
      assert_file "engines/notifications/app/mailers/notifications/welcome_mailer.rb" do |content|
        expect(content).to include("class WelcomeMailer < ApplicationMailer")
      end
      assert_file "engines/notifications/app/views/notifications/welcome_mailer/welcome.html.erb"
    end
  end

  describe "migration" do
    it "creates create_notification_deliveries with What/Why/Risk comment block" do
      pattern = File.join(destination_root,
                          "engines/notifications/db/migrate",
                          "*_create_notification_deliveries.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("# What:")
      expect(content).to include("# Why:")
      expect(content).to include("create_table :notification_deliveries")
    end
  end

  describe "documentation + specs" do
    it "rewrites the README with the canonical events table" do
      assert_file "engines/notifications/README.md" do |content|
        expect(content).to include("notification.queued.notifications")
        expect(content).to include("Notifications::Notifiable")
      end
    end

    it "creates job and adapter specs" do
      assert_file "engines/notifications/spec/jobs/notifications/deliver_email_job_spec.rb"
      assert_file "engines/notifications/spec/adapters/notifications/action_mailer_spec.rb"
    end
  end
end
