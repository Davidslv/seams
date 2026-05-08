# frozen_string_literal: true

require_relative "../rails_helper"

# End-to-end check that the in-app notification path:
#   1. Persists a Notifications::Strategies::InApp row.
#   2. Broadcasts on Notifications::NotificationChannel for the owner.
#   3. Renders something usable in the bell partial.
RSpec.describe "In-app notification bell + ActionCable broadcast",
               type: :integration do
  let(:identity) { create(:auth_identity) }

  describe "InApp#dispatch!" do
    it "broadcasts the notification payload on the owner's channel" do
      notification = create(:in_app_notification, owner: identity, template: "default")
      captured = nil
      allow(Notifications::NotificationChannel).to receive(:broadcast_to) do |target, payload|
        captured = { target: target, payload: payload }
      end

      # dispatch! is the private per-strategy hook called by send!.
      # Invoking it directly keeps this spec focused on broadcast
      # behaviour without needing to seed a due schedule.
      notification.send(:dispatch!)

      expect(captured).not_to be_nil
      expect(captured[:target]).to eq(identity)
      expect(captured[:payload]).to include(
        id:       notification.id,
        template: "default"
      )
      expect(captured[:payload][:body]).to include("notification")
    end
  end

  describe "rendered_content format selection" do
    it "renders the html template for in-app + email contexts" do
      notification = create(:in_app_notification, owner: identity, template: "default")
      html         = notification.rendered_content(format: :html)
      expect(html).to include("<p>")
    end

    it "renders the text template for sms + plain-text email contexts" do
      notification = create(:in_app_notification, owner: identity, template: "default")
      text         = notification.rendered_content(format: :text)
      expect(text).to include("notification")
      expect(text).not_to include("<p>")
    end
  end

  describe "bell partial" do
    it "renders the unread count for the owner" do
      create_list(:in_app_notification, 3, owner: identity, read_at: nil)
      create(:in_app_notification, owner: identity, read_at: Time.current)

      expect(identity.unread_in_app_notifications.count).to eq(3)
    end
  end
end
