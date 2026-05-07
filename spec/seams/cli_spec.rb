# frozen_string_literal: true

require "stringio"
require "seams/cli"

RSpec.describe Seams::CLI do
  let(:io) { StringIO.new }

  describe ".list" do
    let(:list) { instance_spy(Seams::CLI::List) }

    before { allow(Seams::CLI::List).to receive(:new).and_return(list) }

    it "delegates to Seams::CLI::List#call and forwards the return value" do
      allow(list).to receive(:call).and_return(:list_result)

      expect(described_class.list(output: io)).to eq(:list_result)

      expect(Seams::CLI::List).to have_received(:new)
        .with(engines_root: "engines", output: io)
    end
  end

  describe ".test_changed" do
    let(:test_changed) { instance_spy(Seams::CLI::TestChanged) }

    before { allow(Seams::CLI::TestChanged).to receive(:new).and_return(test_changed) }

    it "delegates to Seams::CLI::TestChanged#call and forwards the result" do
      allow(test_changed).to receive(:call).and_return(false)

      expect(described_class.test_changed(base: "develop", output: io)).to be(false)

      expect(Seams::CLI::TestChanged).to have_received(:new)
        .with(base: "develop", engines_root: "engines", output: io)
    end

    it "defaults base to main" do
      allow(test_changed).to receive(:call).and_return(true)

      described_class.test_changed(output: io)

      expect(Seams::CLI::TestChanged).to have_received(:new).with(hash_including(base: "main"))
    end
  end

  describe ".quality" do
    let(:quality) { instance_spy(Seams::CLI::Quality) }

    before { allow(Seams::CLI::Quality).to receive(:new).and_return(quality) }

    it "delegates to Seams::CLI::Quality#call and forwards the result" do
      allow(quality).to receive(:call).and_return(true)

      expect(described_class.quality(output: io)).to be(true)

      expect(Seams::CLI::Quality).to have_received(:new)
        .with(engines_root: "engines", output: io)
    end
  end
end
