# frozen_string_literal: true

require_relative "../rails_helper"

RSpec.describe "Notifications engine boot", type: :integration do
  it "loads the engine" do
    expect(defined?(Notifications::Engine)).to eq("constant")
  end

  it "registers the three canonical notification events" do
    %w[
      notification.queued.notifications
      notification.delivered.notifications
      notification.failed.notifications
    ].each do |event|
      expect(Seams::EventRegistry.registered?(event)).to be(true)
    end
  end

  it "creates the notification tables from the dummy schema" do
    %i[notifications notification_preferences notification_deliveries].each do |t|
      expect(ActiveRecord::Base.connection.table_exists?(t)).to be(true), "missing #{t}"
    end
  end

  it "exposes the strategy STI subclasses" do
    expect(Notifications::Strategies::InApp.superclass).to eq(Notifications::Notification)
    expect(Notifications::Strategies::Email.superclass).to eq(Notifications::Notification)
    expect(Notifications::Strategies::Sms.superclass).to   eq(Notifications::Notification)
  end

  it "Notifiable is mixed into the host User in the dummy" do
    expect(User.ancestors).to include(Notifications::Notifiable)
  end
end
