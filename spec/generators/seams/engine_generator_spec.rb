# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/engine/engine_generator"

RSpec.describe Seams::Generators::EngineGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/engine_generator", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
  end

  def run_generator(args)
    described_class.start(args, destination_root: destination_root)
  end

  def assert_file(path)
    full = File.join(destination_root, path)
    expect(File.exist?(full)).to be(true), "expected #{path} to be created"
    yield(File.read(full)) if block_given?
  end

  before { prepare_destination }

  describe "generating engine 'billing'" do
    before { run_generator(["billing"]) }

    it "creates a gemspec at engines/billing/billing.gemspec" do
      assert_file "engines/billing/billing.gemspec" do |content|
        expect(content).to include("Gem::Specification.new")
        expect(content).to include("billing")
      end
    end

    it "creates the engine entry point with isolate_namespace" do
      assert_file "engines/billing/lib/billing/engine.rb" do |content|
        expect(content).to include("module Billing")
        expect(content).to include("class Engine < ::Rails::Engine")
        expect(content).to include("isolate_namespace Billing")
      end
    end

    it "creates a version constant" do
      assert_file "engines/billing/lib/billing/version.rb" do |content|
        expect(content).to include("module Billing")
        expect(content).to include("VERSION = ")
      end
    end

    it "creates routes.rb" do
      assert_file "engines/billing/config/routes.rb" do |content|
        expect(content).to include("Billing::Engine.routes.draw")
      end
    end

    it "creates the namespaced ApplicationController" do
      assert_file "engines/billing/app/controllers/billing/application_controller.rb" do |content|
        expect(content).to include("module Billing")
        expect(content).to include("class ApplicationController < ::ApplicationController")
      end
    end

    it "creates an engine-scoped .rubocop.yml with the boundary cops pre-wired" do
      assert_file "engines/billing/.rubocop.yml" do |content|
        expect(content).to include("Seams/NoCrossEngineModelAccess")
        expect(content).to include("OwnEngine: Billing")
        expect(content).to include("Seams/NoCrossEngineDependency")
      end
    end

    it "creates a spec_helper for the engine" do
      assert_file "engines/billing/spec/spec_helper.rb" do |content|
        expect(content).to include("require \"billing\"")
        expect(content).to include("RSpec.configure")
      end
    end

    it "creates a sample spec proving the engine boots" do
      assert_file "engines/billing/spec/billing_spec.rb" do |content|
        expect(content).to include("RSpec.describe Billing")
        expect(content).to include("Billing::VERSION")
      end
    end

    it "creates a LICENSE file" do
      assert_file "engines/billing/LICENSE" do |content|
        expect(content).to include("MIT License")
      end
    end

    it "creates a README.md describing the engine" do
      assert_file "engines/billing/README.md" do |content|
        expect(content).to include("# Billing")
        expect(content).to include("## Events emitted")
        expect(content).to include("## Events consumed")
      end
    end
  end

  describe "sibling engine cop config auto-update" do
    it "rewrites OtherEngines in every existing engine's .rubocop.yml when adding a new one" do
      run_generator(["auth"])
      run_generator(["billing"])

      assert_file "engines/auth/.rubocop.yml" do |content|
        expect(content).to match(%r{Seams/NoCrossEngineModelAccess:.*?OtherEngines:\s*\n\s*-\s*Billing}m)
        expect(content).to match(%r{Seams/NoCrossEngineDependency:.*?OtherEngines:\s*\n\s*-\s*billing}m)
      end

      assert_file "engines/billing/.rubocop.yml" do |content|
        expect(content).to match(%r{Seams/NoCrossEngineModelAccess:.*?OtherEngines:\s*\n\s*-\s*Auth}m)
        expect(content).to match(%r{Seams/NoCrossEngineDependency:.*?OtherEngines:\s*\n\s*-\s*auth}m)
      end
    end
  end

  describe "engine name validation" do
    it "rejects names that aren't valid Ruby module names" do
      expect { run_generator(["123billing"]) }
        .to raise_error(Seams::GeneratorError, /name/i)
    end

    it "rejects names that are already in use" do
      run_generator(["billing"])
      expect { run_generator(["billing"]) }
        .to raise_error(Seams::GeneratorError, /already exists/)
    end
  end
end
