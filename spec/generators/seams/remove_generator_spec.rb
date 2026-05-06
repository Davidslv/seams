# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/remove/remove_generator"

RSpec.describe Seams::Generators::RemoveGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/remove_generator", __dir__) }
  let(:engine_path)      { File.join(destination_root, "engines", "billing") }

  def prepare_destination_with_engine
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(engine_path, "lib"))
    File.write(File.join(engine_path, "lib", "billing.rb"), "module Billing; end\n")
  end

  def run_generator(args)
    described_class.start(args, destination_root: destination_root)
  end

  before { prepare_destination_with_engine }

  describe "removing an engine" do
    it "deletes the engine's directory" do
      run_generator(["billing", "--force"])
      expect(File.exist?(engine_path)).to be(false)
    end

    it "is idempotent: re-running on a missing engine warns instead of raising" do
      run_generator(["billing", "--force"])
      expect { run_generator(["billing", "--force"]) }.not_to raise_error
    end

    it "warns instead of erroring when the engine never existed" do
      expect { run_generator(["nonexistent", "--force"]) }.not_to raise_error
    end

    it "leaves the engines/ root intact even after removing the last engine" do
      run_generator(["billing", "--force"])
      expect(Dir.exist?(File.join(destination_root, "engines"))).to be(true)
    end
  end

  describe "without --force" do
    it "does not delete anything when the user does not confirm" do
      generator = described_class.new(["billing"], [], destination_root: destination_root)
      allow(generator).to receive(:confirm_removal?).and_return(false)
      generator.invoke_all

      expect(File.exist?(engine_path)).to be(true)
    end
  end
end
