# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::NotificationPreference do
  describe "validations" do
    it "rejects an unknown channel" do
      record = build(:notification_preference, channel: "carrier_pigeon")
      expect(record).not_to be_valid
      expect(record.errors[:channel]).not_to be_empty
    end

    it "requires identity_id and channel" do
      record = described_class.new
      expect(record).not_to be_valid
      expect(record.errors[:identity_id]).not_to be_empty
      expect(record.errors[:channel]).not_to be_empty
    end

    it "uniqueness scoped on (channel, notification_type) prevents duplicates per identity" do
      create(:notification_preference, identity_id: 7, channel: "email", notification_type: "billing")
      dup = build(:notification_preference, identity_id: 7, channel: "email", notification_type: "billing")
      expect(dup).not_to be_valid
    end
  end

  describe ".enabled?" do
    it "returns true when no row exists for the identity/channel (default-on)" do
      expect(described_class.enabled?(identity_id: 999, channel: "email")).to be(true)
    end

    it "returns the stored value when a specific notification_type row exists" do
      create(:notification_preference, identity_id: 7, channel: "email",
                                       notification_type: "billing", enabled: false)
      expect(described_class.enabled?(identity_id: 7, channel: "email",
                                      notification_type: "billing")).to be(false)
    end

    it "falls back to the channel-wide row (notification_type: nil) when no specific row exists" do
      create(:notification_preference, identity_id: 7, channel: "email",
                                       notification_type: nil, enabled: false)
      expect(described_class.enabled?(identity_id: 7, channel: "email",
                                      notification_type: "billing")).to be(false)
    end
  end
end
