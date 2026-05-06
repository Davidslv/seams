# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "rails/generators/test_case"
require "stringio"

require "generators/seams/install/install_generator"
require "generators/seams/engine/engine_generator"
require "generators/seams/remove/remove_generator"
require "seams/cli/list"

# End-to-end Phase 1 integration test. Walks through the full lifecycle
# a host application would experience:
#
#   1. seams:install         -> initializer + engines dir + rake tasks
#   2. seams:engine billing  -> a fully-isolated engine
#   3. seams:engine auth     -> another engine
#   4. Seams::CLI::List      -> sees both engines
#   5. seams:remove auth     -> auth is gone, billing remains
#
# We don't boot a real Rails application here — generators are run
# against a tmp host directory and the output files are inspected
# directly. The point is to prove the pieces fit together, not to
# re-test each generator.
RSpec.describe "Phase 1 integration", type: :integration do
  let(:host_root) { File.expand_path("../../tmp/integration_host", __dir__) }

  def prepare_host
    FileUtils.rm_rf(host_root)
    FileUtils.mkdir_p(File.join(host_root, "config/initializers"))
    FileUtils.mkdir_p(File.join(host_root, "lib/tasks"))
  end

  def run(generator, args)
    generator.start(args, destination_root: host_root)
  end

  before do
    prepare_host
    Seams::EventRegistry.reset!
  end

  after { FileUtils.rm_rf(host_root) }

  it "walks a host through the full install -> engine -> list -> remove lifecycle" do
    # 1. Install
    run(Seams::Generators::InstallGenerator, [])
    expect(File.exist?(File.join(host_root, "config/initializers/seams.rb"))).to be(true)
    expect(File.exist?(File.join(host_root, "engines/.keep"))).to be(true)
    expect(File.exist?(File.join(host_root, "lib/tasks/seams.rake"))).to be(true)

    # 2. Generate the billing engine
    run(Seams::Generators::EngineGenerator, ["billing"])
    expect(File.exist?(File.join(host_root, "engines/billing/billing.gemspec"))).to be(true)
    expect(File.exist?(File.join(host_root, "engines/billing/lib/billing/engine.rb"))).to be(true)
    expect(File.exist?(File.join(host_root, "engines/billing/.rubocop.yml"))).to be(true)

    # 3. Generate the auth engine
    run(Seams::Generators::EngineGenerator, ["auth"])
    expect(File.exist?(File.join(host_root, "engines/auth/auth.gemspec"))).to be(true)

    # 4. Simulate Rails boot by registering each engine's events
    Seams::EventRegistry.register("subscription.created.billing", emitted_by: "Billing")
    Seams::EventRegistry.register("user.signed_up.auth",          emitted_by: "Auth")

    # 5. List sees both engines and their events
    output = StringIO.new
    Seams::CLI::List.new(engines_root: File.join(host_root, "engines"), output: output).call
    listed = output.string

    expect(listed).to match(/\bauth\b/)
    expect(listed).to match(/\bbilling\b/)
    expect(listed).to include("subscription.created.billing")
    expect(listed).to include("user.signed_up.auth")

    # 6. Remove auth — billing should still be listed afterwards
    run(Seams::Generators::RemoveGenerator, ["auth", "--force"])
    expect(File.exist?(File.join(host_root, "engines/auth"))).to be(false)
    expect(File.exist?(File.join(host_root, "engines/billing"))).to be(true)

    output_after = StringIO.new
    Seams::CLI::List.new(engines_root: File.join(host_root, "engines"), output: output_after).call
    expect(output_after.string).to match(/\bbilling\b/)
    expect(output_after.string).not_to include("engines/auth")
  end

  it "engine's generated .rubocop.yml is valid YAML and references the seams plugin" do
    run(Seams::Generators::InstallGenerator, [])
    run(Seams::Generators::EngineGenerator, ["billing"])

    require "yaml"
    config_path = File.join(host_root, "engines/billing/.rubocop.yml")
    parsed = YAML.safe_load_file(config_path, aliases: true, permitted_classes: [Symbol])

    expect(parsed["plugins"]).to include("seams/cops")
    expect(parsed.dig("Seams/NoCrossEngineModelAccess", "OwnEngine")).to eq("Billing")
    expect(parsed.dig("Seams/NoCrossEngineDependency", "OwnEngine")).to eq("billing")
  end
end
