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

    it "creates config/initializers/seams_engines.rb that adds engines/* to autoload" do
      assert_file "config/initializers/seams_engines.rb" do |content|
        expect(content).to include("Rails.autoloaders.main.push_dir")
        expect(content).to include("engines/")
      end
    end
  end
end
