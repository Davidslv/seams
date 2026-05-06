# frozen_string_literal: true

require "seams/events/adapter"

RSpec.describe Seams::Events::Adapter do
  let(:adapter_class) { Class.new(described_class) }
  let(:adapter)       { adapter_class.new }

  describe "interface" do
    it "raises NotImplementedError when #publish is not overridden" do
      expect { adapter.publish("subscription.created.billing", {}) }
        .to raise_error(NotImplementedError, /must implement #publish/)
    end

    it "raises NotImplementedError when #subscribe is not overridden" do
      expect { adapter.subscribe("subscription.created.billing") { :noop } }
        .to raise_error(NotImplementedError, /must implement #subscribe/)
    end

    it "raises NotImplementedError when #unsubscribe is not overridden" do
      expect { adapter.unsubscribe("subscriber-id") }
        .to raise_error(NotImplementedError, /must implement #unsubscribe/)
    end
  end
end
