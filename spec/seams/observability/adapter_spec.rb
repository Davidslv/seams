# frozen_string_literal: true

require "seams/observability/adapter"

RSpec.describe Seams::Observability::Adapter do
  let(:adapter_class) { Class.new(described_class) }
  let(:adapter)       { adapter_class.new }

  describe "interface" do
    %i[debug info warn error].each do |level|
      it "raises NotImplementedError when ##{level} is not overridden" do
        expect { adapter.public_send(level, "msg") }
          .to raise_error(NotImplementedError, /must implement ##{level}/)
      end
    end

    it "raises NotImplementedError when #measure is not overridden" do
      expect { adapter.measure("op") { :result } }
        .to raise_error(NotImplementedError, /must implement #measure/)
    end
  end
end
