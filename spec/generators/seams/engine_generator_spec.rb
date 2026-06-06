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

    it "creates the namespaced ApplicationController with authentication enforced by default" do
      assert_file "engines/billing/app/controllers/billing/application_controller.rb" do |content|
        expect(content).to include("module Billing")
        expect(content).to include("class ApplicationController < ::ApplicationController")
        expect(content).to include("before_action :authenticate_identity!")
        expect(content).to include("skip_before_action :authenticate_identity!")
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

  describe "wire_into_host" do
    let(:routes_path)      { File.join(destination_root, "config/routes.rb") }
    let(:initializer_path) { File.join(destination_root, "config/initializers/reporting.rb") }

    it "mounts the engine into config/routes.rb when present" do
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(routes_path, "Rails.application.routes.draw do\nend\n")
      run_generator(["reporting"])

      expect(File.read(routes_path)).to include('mount Reporting::Engine, at: "/reporting"')
    end

    it "creates a host-side config/initializers/<name>.rb stub when initializers/ exists" do
      FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
      run_generator(["reporting"])

      expect(File.exist?(initializer_path)).to be(true)
      expect(File.read(initializer_path)).to include("Reporting")
    end

    it "leaves an existing initializer untouched (idempotent)" do
      FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
      File.write(initializer_path, "# host's own config\n")
      run_generator(["reporting"])

      expect(File.read(initializer_path)).to eq("# host's own config\n")
    end

    it "skips silently when the host has no config/initializers directory" do
      run_generator(["reporting"])
      expect(File.exist?(initializer_path)).to be(false)
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

  describe "Phase 1.6 — generic engine templates" do
    before { run_generator(["reporting"]) }

    it "ships an engine-scoped ApplicationRecord (abstract_class = true)" do
      assert_file "engines/reporting/app/models/reporting/application_record.rb" do |content|
        [
          "module Reporting",
          "class ApplicationRecord < ActiveRecord::Base",
          "self.abstract_class = true"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships an i18n stub under the engine's namespace key" do
      assert_file "engines/reporting/config/locales/en.yml" do |content|
        expect(content).to include("en:")
        expect(content).to include("reporting:")
        expect(content).to include("placeholder:")
      end
    end

    it "ships a standalone Gemfile that gemspec-resolves the engine" do
      assert_file "engines/reporting/Gemfile" do |content|
        [
          'source "https://rubygems.org"',
          "gemspec",
          'gem "rspec-rails"'
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships a Rakefile with the rspec default task" do
      assert_file "engines/reporting/Rakefile" do |content|
        expect(content).to include('require "rspec/core/rake_task"')
        expect(content).to include("RSpec::Core::RakeTask.new(:spec)")
        expect(content).to include("task default: :spec")
      end
    end

    it "ships a per-engine dummy app via DummyAppWriter" do
      %w[
        engines/reporting/spec/dummy/config/application.rb
        engines/reporting/spec/dummy/db/schema.rb
        engines/reporting/spec/dummy/app/controllers/application_controller.rb
        engines/reporting/spec/rails_helper.rb
      ].each do |path|
        full = File.join(destination_root, path)
        expect(File.exist?(full)).to be(true), "missing #{path}"
      end
    end
  end
end
