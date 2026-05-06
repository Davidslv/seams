# frozen_string_literal: true

require "seams/events/adapters/active_support"

RSpec.describe Seams::Events::Adapters::ActiveSupport do
  subject(:adapter) { described_class.new }

  let(:event_name) { "subscription.created.billing" }
  let(:payload)    { { id: 42, plan: "pro" } }

  describe "#publish" do
    it "delivers the payload to a subscriber" do
      received = nil
      adapter.subscribe(event_name) { |_, _, _, _, p| received = p }
      adapter.publish(event_name, payload)

      expect(received).to eq(payload)
    end

    it "wraps a non-hash payload in a hash under :payload" do
      received = nil
      adapter.subscribe(event_name) { |_, _, _, _, p| received = p }
      adapter.publish(event_name, "not a hash")

      expect(received).to eq(payload: "not a hash")
    end
  end

  describe "#subscribe" do
    it "returns an ActiveSupport::Notifications subscriber that can be used to unsubscribe" do
      subscriber = adapter.subscribe(event_name) { :noop }
      expect { adapter.unsubscribe(subscriber) }.not_to raise_error
    end

    it "matches subscribers by exact event name (no prefix matching)" do
      received_other = false
      adapter.subscribe("other.event.engine") { received_other = true }
      adapter.publish(event_name, payload)

      expect(received_other).to be(false)
    end
  end

  describe "#unsubscribe" do
    it "stops a subscriber from receiving further events" do
      received = 0
      subscriber = adapter.subscribe(event_name) { received += 1 }
      adapter.publish(event_name, payload)
      adapter.unsubscribe(subscriber)
      adapter.publish(event_name, payload)

      expect(received).to eq(1)
    end
  end
end
