# frozen_string_literal: true

require "logger"
require "stringio"
require "seams/observability/adapters/rails_logger"

RSpec.describe Seams::Observability::Adapters::RailsLogger do
  subject(:adapter) { described_class.new(logger: logger) }

  let(:io)     { StringIO.new }
  let(:logger) { Logger.new(io).tap { |l| l.level = Logger::DEBUG } }

  describe "log levels" do
    %i[debug info warn error].each do |level|
      it "writes a tagged ##{level} message to the underlying logger" do
        adapter.public_send(level, "hello world", engine: "billing")

        expect(io.string).to include("[seams]", "[billing]", "hello world")
      end
    end

    it "serialises hash context as key=value pairs" do
      adapter.info("did the thing", engine: "billing", actor_id: 42, plan: "pro")

      expect(io.string).to include("actor_id=42", "plan=pro")
    end
  end

  describe "#measure" do
    it "returns the block's value" do
      result = adapter.measure("billing.charge.attempt") { 99 }
      expect(result).to eq(99)
    end

    it "logs the operation name and the duration in milliseconds" do
      adapter.measure("billing.charge.attempt", engine: "billing") { sleep 0.001 }

      expect(io.string).to include("billing.charge.attempt", "duration_ms=")
    end

    it "logs and re-raises when the block raises" do
      expect do
        adapter.measure("billing.charge.attempt", engine: "billing") { raise "boom" }
      end.to raise_error(RuntimeError, "boom")

      expect(io.string).to include("error=", "RuntimeError", "boom")
    end
  end

  describe "default logger" do
    it "falls back to a stdout Logger when no logger is provided and Rails is undefined" do
      hide_const("Rails") if defined?(Rails)
      expect { described_class.new }.not_to raise_error
    end
  end
end
