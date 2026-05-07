# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "rails/generators/test_case"
require "yaml"

require "generators/seams/install/install_generator"
require "generators/seams/auth/auth_generator"
require "generators/seams/notifications/notifications_generator"
require "seams/cli/list"

# End-to-end Phase 2 integration test. Walks a host through the full
# install -> auth -> notifications flow and verifies that the two
# canonical engines coexist correctly with the boundary cops.
RSpec.describe "Phase 2 integration", type: :integration do
  let(:host_root) { File.expand_path("../../tmp/integration_phase_two", __dir__) }

  def prepare_host
    FileUtils.rm_rf(host_root)
    FileUtils.mkdir_p(File.join(host_root, "config/initializers"))
    FileUtils.mkdir_p(File.join(host_root, "lib/tasks"))
  end

  def run(generator, args = [])
    generator.start(args, destination_root: host_root)
  end

  before { prepare_host }
  after  { FileUtils.rm_rf(host_root) }

  it "scaffolds auth + notifications and wires their cross-engine boundary correctly" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)

    # Both engines exist
    expect(File.exist?(File.join(host_root, "engines/auth/lib/auth/engine.rb"))).to be(true)
    expect(File.exist?(File.join(host_root, "engines/notifications/lib/notifications/engine.rb"))).to be(true)

    # Each engine sees the other in OtherEngines
    auth_yml          = YAML.safe_load_file(File.join(host_root, "engines/auth/.rubocop.yml"))
    notifications_yml = YAML.safe_load_file(File.join(host_root, "engines/notifications/.rubocop.yml"))

    expect(auth_yml.dig("Seams/NoCrossEngineModelAccess", "OtherEngines"))
      .to eq(["Notifications"])
    expect(notifications_yml.dig("Seams/NoCrossEngineModelAccess", "OtherEngines"))
      .to eq(["Auth"])

    # Each engine's exposed concern survived the auto-population of OtherEngines
    expect(auth_yml.dig("Seams/NoCrossEngineModelAccess", "ExposedConcerns"))
      .to eq(["Auth::Authenticatable", "Auth::Authentication"])
    expect(notifications_yml.dig("Seams/NoCrossEngineModelAccess", "ExposedConcerns"))
      .to eq(["Notifications::Notifiable"])
  end

  it "auth subscriber + notifications subscriber together emit a welcome email on user.signed_up.auth" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)

    auth_subscriber = File.read(File.join(host_root,
                                          "engines/notifications/app/subscribers/notifications/auth_subscriber.rb"))
    expect(auth_subscriber).to include('attach_once(SUBSCRIBER_KEY, "user.signed_up.auth")')
    expect(auth_subscriber).to include("Notifications::CreateNotificationJob.perform_later")
  end

  it "auth migration + notifications migration both have leading comment blocks" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)

    Dir[File.join(host_root, "engines/*/db/migrate/*.rb")].each do |migration|
      content = File.read(migration)
      expect(content).to include("# What:"), "expected #{migration} to have a # What: comment"
      expect(content).to include("# Why:"),  "expected #{migration} to have a # Why: comment"
    end
  end

  it "registering both engines' events does not raise duplicate-event errors" do
    Seams::EventRegistry.reset!

    # Simulate Rails boot: each engine's engine.rb runs its register block.
    Seams::EventRegistry.register("user.signed_up.auth",                     emitted_by: "Auth")
    Seams::EventRegistry.register("user.signed_in.auth",                     emitted_by: "Auth")
    Seams::EventRegistry.register("user.signed_out.auth",                    emitted_by: "Auth")
    Seams::EventRegistry.register("session.expired.auth",                    emitted_by: "Auth")
    Seams::EventRegistry.register("notification.queued.notifications",       emitted_by: "Notifications")
    Seams::EventRegistry.register("notification.delivered.notifications",    emitted_by: "Notifications")
    Seams::EventRegistry.register("notification.failed.notifications",       emitted_by: "Notifications")

    expect(Seams::EventRegistry.all.size).to eq(7)
  end

  it "every generated Ruby file parses without syntax errors" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)

    failures = []
    Dir[File.join(host_root, "engines/**/*.rb")].each do |path|
      result = `ruby -c #{path.shellescape} 2>&1`
      failures << "#{path}: #{result.strip}" unless $CHILD_STATUS.success?
    end

    expect(failures).to be_empty, "expected all generated files to parse, got:\n#{failures.join("\n")}"
  end

  it "auth + notifications migrations get distinct timestamps" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)

    timestamps = Dir[File.join(host_root, "engines/*/db/migrate/*.rb")]
                 .map { |p| File.basename(p).split("_").first }

    expect(timestamps).to eq(timestamps.uniq), "migration timestamps collided: #{timestamps}"
  end
end
