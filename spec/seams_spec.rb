# frozen_string_literal: true

RSpec.describe Seams do
  it "has a version number" do
    expect(Seams::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe ".configuration" do
    it "returns the same instance across calls" do
      first  = described_class.configuration
      second = described_class.configuration
      expect(first).to be(second)
    end

    it "exposes default adapters" do
      expect(described_class.configuration.event_bus_adapter)
        .to eq("Seams::Events::Adapters::ActiveSupport")
      expect(described_class.configuration.observability_adapter)
        .to eq("Seams::Observability::Adapters::RailsLogger")
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      described_class.configure do |config|
        config.host_app_name = "my_app"
      end

      expect(described_class.configuration.host_app_name).to eq("my_app")
    end
  end

  describe ".reset_configuration!" do
    it "discards mutations and returns to defaults" do
      described_class.configure { |c| c.host_app_name = "changed" }
      described_class.reset_configuration!

      expect(described_class.configuration.host_app_name).to be_nil
    end
  end
end
