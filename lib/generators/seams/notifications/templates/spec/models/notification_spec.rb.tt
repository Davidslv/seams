# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::Notification do
  describe "validations" do
    it "rejects an unknown type" do
      record = build(:notification, type: "Notifications::Strategies::Carrier")
      expect(record).not_to be_valid
    end

    it "requires a template" do
      record = build(:notification, template: "")
      expect(record).not_to be_valid
      expect(record.errors[:template]).not_to be_empty
    end

    it "rejects template paths with traversal segments" do
      record = build(:notification, template: "../../etc/passwd")
      expect(record).not_to be_valid
    end

    it "accepts subdirectory templates with safe segments" do
      record = build(:notification, template: "billing/invoice_paid")
      expect(record).to be_valid
    end
  end

  describe "STI subclasses" do
    it "Strategies::InApp persists as the InApp type" do
      record = create(:in_app_notification)
      expect(Notifications::Notification.find(record.id))
        .to be_a(Notifications::Strategies::InApp)
    end

    it "Strategies::Email persists as the Email type" do
      record = create(:email_notification)
      expect(Notifications::Notification.find(record.id))
        .to be_a(Notifications::Strategies::Email)
    end
  end

  describe "scopes" do
    it ".due includes notifications whose next_delivery_at is in the past" do
      due  = create(:in_app_notification, next_delivery_at: 1.minute.ago)
      late = create(:in_app_notification, next_delivery_at: 1.hour.from_now)

      expect(described_class.due).to     include(due)
      expect(described_class.due).not_to include(late)
    end

    it ".unread filters out rows whose read_at is set" do
      unread = create(:in_app_notification, read_at: nil)
      read   = create(:in_app_notification, read_at: Time.current)

      expect(described_class.unread).to     include(unread)
      expect(described_class.unread).not_to include(read)
    end
  end
end
