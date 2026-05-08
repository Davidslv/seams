# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notifications::Delivery do
  describe "associations" do
    it "belongs to a Notification" do
      delivery = create(:notification_delivery)
      expect(delivery.notification).to be_a(Notifications::Notification)
    end

    it "is destroyed when its parent notification is destroyed" do
      notification = create(:in_app_notification)
      delivery     = create(:notification_delivery, notification: notification)

      expect { notification.destroy }.to change(described_class, :count).by(-1)
      expect(described_class.where(id: delivery.id)).to be_empty
    end
  end

  describe "DB-level constraints" do
    it "rejects a row without sent_at (NOT NULL at the DB level)" do
      expect {
        build(:notification_delivery, sent_at: nil).save(validate: false)
      }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end
end
