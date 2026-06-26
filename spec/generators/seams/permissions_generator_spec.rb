# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/permissions/permissions_generator"

RSpec.describe Seams::Generators::PermissionsGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/permissions_generator", __dir__) }
  let(:initializer) { "config/initializers/seams_permissions.rb" }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
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

    it "writes config/initializers/seams_permissions.rb" do
      assert_file initializer
    end

    it "assigns the grant map through Seams.configure { |c| c.permission_grants = {...} }" do
      assert_file initializer do |content|
        expect(content).to include("Seams.configure do |config|")
        expect(content).to include("config.permission_grants = {")
      end
    end

    it "spells out the member + admin roles with %w[] ability lists" do
      assert_file initializer do |content|
        expect(content).to include('"member" => %w[')
        expect(content).to include('"admin" => %w[')
      end
    end

    it "renders a readable copy of every DEFAULT_GRANTS ability code" do
      assert_file initializer do |content|
        Seams::Permissions::DEFAULT_GRANTS.each_value do |abilities|
          abilities.each { |code| expect(content).to include(code) }
        end
      end
    end

    it "does NOT spell out owner or system (they resolve via the hierarchy / bypass)" do
      assert_file initializer do |content|
        # owner inherits admin; system bypasses every check — neither
        # needs its own entry, and shipping one would be misleading.
        expect(content).not_to include('"owner" => %w[')
        expect(content).not_to include('"system" => %w[')
      end
    end

    it "carries the editing guidance comments" do
      assert_file initializer do |content|
        [
          "host-editable",
          "inherit",
          "engine-owned",
          "Seams::PermissionRegistry.all",
          "Deny-by-default",
          "system"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "is frozen_string_literal and valid Ruby" do
      assert_file initializer do |content|
        expect(content).to start_with("# frozen_string_literal: true")
      end
      full = File.join(destination_root, initializer)
      expect(system("ruby", "-c", full, out: File::NULL, err: File::NULL)).to be(true)
    end
  end

  describe "ejection" do
    it "is eject-aware: a file carrying the eject header is left untouched on re-run" do
      full = File.join(destination_root, initializer)
      run_generator
      File.write(full, "# seams:ejected from permissions.config/initializers/seams_permissions.rb\n# mine\n")

      run_generator

      expect(File.read(full)).to eq(
        "# seams:ejected from permissions.config/initializers/seams_permissions.rb\n# mine\n"
      )
    end
  end

  describe "generator surface" do
    let(:gen_path) do
      File.expand_path("../../../lib/generators/seams/permissions/permissions_generator.rb", __dir__)
    end

    it "includes EjectAware + HostInjector and templates the one initializer" do
      content = File.read(gen_path)
      expect(content).to include("include Seams::Generators::EjectAware")
      expect(content).to include("include Seams::Generators::HostInjector")
      expect(content).to include("template_unless_ejected")
    end
  end
end
