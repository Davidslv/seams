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

  describe "drop-table migration (Phase 1.7)" do
    let(:host_migrate_dir) { File.join(destination_root, "db/migrate") }

    def seed_engine_migration(filename, body)
      dir = File.join(engine_path, "db/migrate")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, filename), body)
    end

    def seed_two_billing_migrations
      seed_engine_migration("20250101000000_create_billing_plans.rb",
                            "class CreateBillingPlans < ActiveRecord::Migration[7.1]\n  " \
                            "def change\n    create_table :billing_plans\n  end\nend\n")
      seed_engine_migration("20250102000000_create_billing_subscriptions.rb",
                            "class CreateBillingSubscriptions < ActiveRecord::Migration[7.1]\n  " \
                            "def change\n    create_table :billing_subscriptions\n  end\nend\n")
    end

    it "generates a drop migration listing every table the engine created" do
      seed_two_billing_migrations
      run_generator(["billing", "--force"])

      generated = Dir.glob(File.join(host_migrate_dir, "*_drop_billing_tables.rb"))
      expect(generated.size).to eq(1)
      content = File.read(generated.first)

      [
        "class DropBillingTables < ActiveRecord::Migration",
        "drop_table :billing_plans, force: :cascade if table_exists?(:billing_plans)",
        "drop_table :billing_subscriptions, force: :cascade if table_exists?(:billing_subscriptions)",
        "ActiveRecord::IrreversibleMigration"
      ].each { |needle| expect(content).to include(needle) }
    end

    it "skips when the engine had no migrations" do
      run_generator(["billing", "--force"])
      expect(Dir.glob(File.join(host_migrate_dir, "*_drop_billing_tables.rb"))).to be_empty
    end

    it "skips when the engine never existed" do
      run_generator(["ghost", "--force"])
      generated = Dir.glob(File.join(host_migrate_dir, "*_drop_ghost_tables.rb"))
      expect(generated).to be_empty
    end
  end

  describe "post-remove bundle install (Phase 1.7 follow-up)" do
    it "runs `bundle install --quiet` from the host root when a Gemfile is present" do
      # prepare_destination_with_engine in the top-level before-block already
      # seeded engines/billing/, so the remove path runs end-to-end.
      File.write(File.join(destination_root, "Gemfile"), "# host Gemfile\n")
      generator = described_class.new(["billing"], ["--force"], destination_root: destination_root)
      allow(generator).to receive(:system).and_return(true)

      generator.invoke_all

      expect(generator).to have_received(:system).with("bundle", "install", "--quiet")
    end

    it "skips bundle install when the engine never existed (no-op remove)" do
      File.write(File.join(destination_root, "Gemfile"), "# host Gemfile\n")
      generator = described_class.new(["nonexistent"], ["--force"], destination_root: destination_root)
      allow(generator).to receive(:system)

      generator.invoke_all

      expect(generator).not_to have_received(:system).with("bundle", "install", anything)
    end

    it "skips bundle install when the host has no Gemfile" do
      generator = described_class.new(["billing"], ["--force"], destination_root: destination_root)
      allow(generator).to receive(:system)

      generator.invoke_all

      expect(generator).not_to have_received(:system).with("bundle", "install", anything)
    end
  end
end
