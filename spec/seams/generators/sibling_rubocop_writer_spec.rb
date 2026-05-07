# frozen_string_literal: true

require "fileutils"
require "yaml"
require "seams/generators/sibling_rubocop_writer"

RSpec.describe Seams::Generators::SiblingRubocopWriter do
  let(:engines_root) { File.expand_path("../../tmp/sibling_rubocop", __dir__) }

  def write_engine(name:, other_engines:, exposed_concerns:)
    FileUtils.mkdir_p(File.join(engines_root, name))
    File.write(File.join(engines_root, name, ".rubocop.yml"),
               build_rubocop_yaml(name, other_engines, exposed_concerns))
  end

  def yaml_list(values)
    return "[]" if values.empty?

    "\n    - #{values.join("\n    - ")}"
  end

  def build_rubocop_yaml(name, other_engines, exposed_concerns)
    module_others = other_engines.map { |d| d.split("_").map(&:capitalize).join }

    <<~YML
      inherit_from:
        - ../../.rubocop.yml

      Seams/NoCrossEngineModelAccess:
        Enabled: true
        OwnEngine: #{name.split("_").map(&:capitalize).join}
        OtherEngines: #{yaml_list(module_others)}
        ExposedConcerns: #{yaml_list(exposed_concerns)}

      Seams/NoCrossEngineDependency:
        Enabled: true
        OwnEngine: #{name}
        OtherEngines: #{yaml_list(other_engines)}

      Seams/KnownQueueNames:
        Enabled: true
        KnownQueues:
          - default
    YML
  end

  def yaml_for(engine)
    YAML.safe_load_file(File.join(engines_root, engine, ".rubocop.yml"))
  end

  before { FileUtils.rm_rf(engines_root) }
  after  { FileUtils.rm_rf(engines_root) }

  describe ".rewrite!" do
    it "preserves ExposedConcerns when rewriting OtherEngines" do
      write_engine(name: "auth", other_engines: [], exposed_concerns: %w[Some::PreciousConcern])

      described_class.rewrite!(engines_root: engines_root, dirs: %w[auth billing])

      auth = yaml_for("auth")
      expect(auth.dig("Seams/NoCrossEngineModelAccess", "OtherEngines")).to eq(["Billing"])
      expect(auth.dig("Seams/NoCrossEngineModelAccess", "ExposedConcerns")).to eq(["Some::PreciousConcern"])
    end

    it "preserves the KnownQueueNames block that follows the dependency cop" do
      write_engine(name: "auth", other_engines: [], exposed_concerns: [])

      described_class.rewrite!(engines_root: engines_root, dirs: %w[auth billing])

      auth = yaml_for("auth")
      expect(auth.dig("Seams/KnownQueueNames", "KnownQueues")).to eq(["default"])
    end

    it "rewrites both module-name and directory-name lists" do
      write_engine(name: "auth",    other_engines: [], exposed_concerns: [])
      write_engine(name: "billing", other_engines: [], exposed_concerns: [])

      described_class.rewrite!(engines_root: engines_root, dirs: %w[auth billing])

      auth    = yaml_for("auth")
      billing = yaml_for("billing")

      expect(auth.dig("Seams/NoCrossEngineModelAccess", "OtherEngines")).to eq(["Billing"])
      expect(auth.dig("Seams/NoCrossEngineDependency",  "OtherEngines")).to eq(["billing"])
      expect(billing.dig("Seams/NoCrossEngineModelAccess", "OtherEngines")).to eq(["Auth"])
      expect(billing.dig("Seams/NoCrossEngineDependency",  "OtherEngines")).to eq(["auth"])
    end

    it "writes [] when an engine has no remaining siblings" do
      write_engine(name: "auth", other_engines: %w[billing], exposed_concerns: [])

      described_class.rewrite!(engines_root: engines_root, dirs: %w[auth])

      auth = yaml_for("auth")
      expect(auth.dig("Seams/NoCrossEngineModelAccess", "OtherEngines")).to eq([])
      expect(auth.dig("Seams/NoCrossEngineDependency",  "OtherEngines")).to eq([])
    end

    it "leaves engines without a .rubocop.yml file untouched" do
      FileUtils.mkdir_p(File.join(engines_root, "no_config"))

      expect do
        described_class.rewrite!(engines_root: engines_root, dirs: %w[no_config auth])
      end.not_to raise_error
    end

    it "raises a clear error when a hand-edited config has no writable OtherEngines block" do
      FileUtils.mkdir_p(File.join(engines_root, "auth"))
      File.write(File.join(engines_root, "auth", ".rubocop.yml"), <<~YML)
        Seams/NoCrossEngineModelAccess: { OtherEngines: [Billing] }
        Seams/NoCrossEngineDependency: { OtherEngines: [billing] }
      YML

      expect do
        described_class.rewrite!(engines_root: engines_root, dirs: %w[auth billing])
      end.to raise_error(ArgumentError, /OtherEngines/)
    end
  end
end
