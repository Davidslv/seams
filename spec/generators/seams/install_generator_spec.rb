# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/install/install_generator"

RSpec.describe Seams::Generators::InstallGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/install_generator", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
    FileUtils.mkdir_p(File.join(destination_root, "lib/tasks"))
  end

  def run_generator(args = [])
    described_class.start(args, destination_root: destination_root)
  end

  def assert_file(path)
    full = File.join(destination_root, path)
    expect(File.exist?(full)).to be(true), "expected #{path} to be created"
    yield(File.read(full)) if block_given?
  end

  before { prepare_destination }

  describe "#create_initializer" do
    before { run_generator }

    it "creates config/initializers/seams.rb" do
      assert_file "config/initializers/seams.rb" do |content|
        expect(content).to include("Seams.configure")
        expect(content).to include("config.event_bus_adapter")
        expect(content).to include("config.observability_adapter")
      end
    end
  end

  describe "#create_engines_directory" do
    before { run_generator }

    it "creates an engines/ directory with a .keep file" do
      assert_file "engines/.keep"
    end
  end

  describe "#create_rake_tasks" do
    before { run_generator }

    it "creates lib/tasks/seams.rake" do
      assert_file "lib/tasks/seams.rake" do |content|
        expect(content).to include("namespace :seams")
        expect(content).to include("task list:")
      end
    end
  end

  describe "#append_engines_to_eager_load" do
    before { run_generator }

    it "creates config/seams_engines.rb that requires every engine" do
      assert_file "config/seams_engines.rb" do |content|
        expect(content).to include("$LOAD_PATH.unshift")
        expect(content).to include('require engine_name')
        expect(content).to include("engines/")
      end
    end
  end

  describe "#wire_engines_into_application_rb" do
    let(:application_rb) do
      <<~RB
        require_relative "boot"

        require "rails"
        Bundler.require(*Rails.groups)

        module Host
          class Application < Rails::Application
          end
        end
      RB
    end

    before do
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, "config/application.rb"), application_rb)
      run_generator
    end

    it "injects require_relative \"seams_engines\" after Bundler.require" do
      assert_file "config/application.rb" do |content|
        expect(content).to match(/Bundler\.require\(\*Rails\.groups\)\n+require_relative "seams_engines"/)
      end
    end
  end

  describe "#create_ci_workflow" do
    before { run_generator }

    it "creates .github/workflows/ci.yml with engine-matrix testing" do
      assert_file ".github/workflows/ci.yml" do |content|
        expect(content).to include("name: CI")
        expect(content).to include("test_engine")
        expect(content).to include("matrix:")
        expect(content).to include("brakeman")
        expect(content).to include("bundle-audit")
      end
    end
  end

  describe "#create_bin_seams" do
    before { run_generator }

    it "creates an executable bin/seams wrapper" do
      assert_file "bin/seams" do |content|
        expect(content).to include("Usage: bin/seams")
        expect(content).to include("seams:engine")
      end

      full = File.join(destination_root, "bin/seams")
      expect(File.executable?(full)).to be(true)
    end
  end

  describe "#create_host_rubocop" do
    it "creates .rubocop.yml so generated engines' inherit_from resolves" do
      run_generator
      assert_file ".rubocop.yml" do |content|
        expect(content).to include("AllCops:")
        expect(content).to include("Exclude:")
      end
    end

    it "does not overwrite an existing host .rubocop.yml" do
      File.write(File.join(destination_root, ".rubocop.yml"), "# host's own config\n")
      run_generator
      content = File.read(File.join(destination_root, ".rubocop.yml"))
      expect(content).to eq("# host's own config\n")
    end
  end

  describe "#create_deployment_templates" do
    before { run_generator }

    it "creates a Dockerfile that references engines/" do
      assert_file "Dockerfile" do |content|
        expect(content).to include("FROM ruby:")
        expect(content).to include("engines/")
      end
    end

    it "creates bin/docker-entrypoint that runs db:prepare" do
      assert_file "bin/docker-entrypoint" do |content|
        expect(content).to include("db:prepare")
      end
    end

    it "creates a Procfile with web + worker entries" do
      assert_file "Procfile" do |content|
        expect(content).to include("web:")
        expect(content).to include("worker:")
      end
    end

    it "creates a Kamal deploy.yml skeleton" do
      assert_file "config/deploy.yml" do |content|
        expect(content).to include("service:")
        expect(content).to include("STRIPE_SECRET_KEY")
      end
    end

    it "marks bin/docker-entrypoint as executable" do
      full = File.join(destination_root, "bin/docker-entrypoint")
      expect(File.executable?(full)).to be(true)
    end
  end

  describe "#create_deployment_templates idempotence" do
    it "skips files the host already has (Rails 8 ships its own)" do
      FileUtils.mkdir_p(File.join(destination_root, "bin"))
      File.write(File.join(destination_root, "Dockerfile"), "# my Dockerfile\n")
      File.write(File.join(destination_root, "bin/docker-entrypoint"), "# my entrypoint\n")

      run_generator

      expect(File.read(File.join(destination_root, "Dockerfile"))).to eq("# my Dockerfile\n")
      expect(File.read(File.join(destination_root, "bin/docker-entrypoint"))).to eq("# my entrypoint\n")
    end
  end
end
