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

    it "does not print a misleading 'update' line when the remove was a no-op" do
      output = capture_stdout { run_generator(["nonexistent", "--force"]) }
      expect(output).not_to include("update")
    end

    def capture_stdout
      original = $stdout
      $stdout  = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end

    it "leaves the engines/ root intact even after removing the last engine" do
      run_generator(["billing", "--force"])
      expect(Dir.exist?(File.join(destination_root, "engines"))).to be(true)
    end

    it "prunes removed engine from surviving siblings' OtherEngines lists" do
      auth_path = File.join(destination_root, "engines", "auth")
      seed_sibling_with_billing_listed(auth_path)

      run_generator(["billing", "--force"])

      content = File.read(File.join(auth_path, ".rubocop.yml"))
      expect(content).not_to include("- Billing")
      expect(content).not_to include("- billing")
      expect(content).to include("OtherEngines: []")
    end

    def seed_sibling_with_billing_listed(auth_path)
      FileUtils.mkdir_p(auth_path)
      File.write(File.join(auth_path, ".rubocop.yml"), <<~YML)
        Seams/NoCrossEngineModelAccess:
          Enabled: true
          OwnEngine: Auth
          OtherEngines:
            - Billing
          ExposedConcerns: []

        Seams/NoCrossEngineDependency:
          Enabled: true
          OwnEngine: auth
          OtherEngines:
            - billing
      YML
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
