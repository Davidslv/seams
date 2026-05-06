# frozen_string_literal: true

require "seams/event_registry"

RSpec.describe Seams::EventRegistry do
  before { described_class.reset! }

  describe ".register" do
    it "stores the event name and the emitting engine" do
      described_class.register("subscription.created.billing", emitted_by: "Billing")

      expect(described_class.registered?("subscription.created.billing")).to be(true)
      expect(described_class.emitter_of("subscription.created.billing")).to eq("Billing")
    end

    it "raises when the same event is registered by two different engines" do
      described_class.register("subscription.created.billing", emitted_by: "Billing")

      expect do
        described_class.register("subscription.created.billing", emitted_by: "Auth")
      end.to raise_error(Seams::Events::DuplicateEventError, /already registered/)
    end

    it "is idempotent when the same engine re-registers the same event" do
      described_class.register("subscription.created.billing", emitted_by: "Billing")

      expect do
        described_class.register("subscription.created.billing", emitted_by: "Billing")
      end.not_to raise_error
    end

    it "validates the resource.action.engine naming convention" do
      expect do
        described_class.register("nope", emitted_by: "X")
      end.to raise_error(Seams::Events::InvalidEventNameError)
    end
  end

  describe ".all" do
    it "returns the full registry as an enumerable hash" do
      described_class.register("a.b.c", emitted_by: "C")
      described_class.register("d.e.f", emitted_by: "F")

      expect(described_class.all).to eq("a.b.c" => "C", "d.e.f" => "F")
    end
  end

  describe ".reset!" do
    it "clears all registered events" do
      described_class.register("a.b.c", emitted_by: "C")
      described_class.reset!

      expect(described_class.all).to be_empty
    end
  end
end
