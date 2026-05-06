# frozen_string_literal: true

require "seams/events/publisher"
require "seams/events/adapters/active_support"
require "seams/event_registry"

RSpec.describe Seams::Events::Publisher do
  let(:adapter) { Seams::Events::Adapters::ActiveSupport.new }

  before do
    allow(described_class).to receive(:adapter).and_return(adapter)
    Seams::EventRegistry.reset!
    Seams::EventRegistry.register("subscription.created.billing", emitted_by: "Billing")
  end

  describe ".publish" do
    it "delegates to the configured adapter" do
      received = nil
      adapter.subscribe("subscription.created.billing") { |_, _, _, _, p| received = p }

      described_class.publish("subscription.created.billing", id: 42)

      expect(received).to eq(id: 42)
    end

    it "raises if the event has not been registered" do
      expect do
        described_class.publish("ghost.event.unknown", {})
      end.to raise_error(Seams::Events::UnregisteredEventError, /ghost\.event\.unknown/)
    end

    it "rejects names that don't follow the resource.action.engine convention" do
      expect do
        described_class.publish("badly_named_event", {})
      end.to raise_error(Seams::Events::InvalidEventNameError, /resource\.action\.engine/)
    end
  end

  describe ".subscribe" do
    it "wraps the block so the engine receives the payload directly" do
      payload_seen = nil
      described_class.subscribe("subscription.created.billing") { |p| payload_seen = p }
      described_class.publish("subscription.created.billing", id: 7)

      expect(payload_seen).to eq(id: 7)
    end
  end
end
