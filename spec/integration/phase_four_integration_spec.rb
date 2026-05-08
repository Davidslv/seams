# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "rails/generators/test_case"
require "yaml"

require "generators/seams/install/install_generator"
require "generators/seams/auth/auth_generator"
require "generators/seams/notifications/notifications_generator"
require "generators/seams/billing/billing_generator"
require "generators/seams/teams/teams_generator"

RSpec.describe "Phase 4 integration", type: :integration do
  let(:host_root) { File.expand_path("../../tmp/integration_phase_four", __dir__) }

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

  it "scaffolds all four canonical engines and wires their cross-engine boundaries" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)
    run(Seams::Generators::BillingGenerator)
    run(Seams::Generators::TeamsGenerator)

    %w[auth notifications billing teams].each do |dir|
      engine_rb = File.join(host_root, "engines/#{dir}/lib/#{dir}/engine.rb")
      expect(File.exist?(engine_rb)).to be(true), "expected #{engine_rb}"
    end

    teams_yml = YAML.safe_load_file(File.join(host_root, "engines/teams/.rubocop.yml"))
    expect(teams_yml.dig("Seams/NoCrossEngineModelAccess", "OtherEngines"))
      .to match_array(%w[Auth Billing Notifications])
    # Wave 9 dropped Teams::Teamable along with the host User model;
    # the engine now exposes only AccountScoped + Authorization.
    expect(teams_yml.dig("Seams/NoCrossEngineModelAccess", "ExposedConcerns"))
      .to eq(["Teams::AccountScoped", "Teams::Authorization"])
  end

  it "every generated teams Ruby file parses without syntax errors" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::TeamsGenerator)

    failures = []
    Dir[File.join(host_root, "engines/teams/**/*.rb")].each do |path|
      result = `ruby -c #{path.shellescape} 2>&1`
      failures << "#{path}: #{result.strip}" unless $CHILD_STATUS.success?
    end

    expect(failures).to be_empty, "expected all teams files to parse:\n#{failures.join("\n")}"
  end

  it "all four canonical engines' migrations get distinct timestamps" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)
    run(Seams::Generators::BillingGenerator)
    run(Seams::Generators::TeamsGenerator)

    timestamps = Dir[File.join(host_root, "engines/*/db/migrate/*.rb")]
                 .map { |p| File.basename(p).split("_").first }

    expect(timestamps).to eq(timestamps.uniq), "migration timestamps collided: #{timestamps}"
  end

  it "registering all engines' events does not collide" do
    Seams::EventRegistry.reset!

    auth_events    = %w[identity.signed_up.auth identity.signed_in.auth identity.signed_out.auth session.expired.auth]
    notif_events   = %w[notification.queued.notifications notification.delivered.notifications notification.failed.notifications]
    billing_events = %w[subscription.created.billing subscription.updated.billing
                        subscription.canceled.billing invoice.paid.billing invoice.failed.billing]
    teams_events   = %w[team.created.teams team.member_joined.teams team.member_left.teams
                        invitation.sent.teams invitation.accepted.teams]

    auth_events.each    { |e| Seams::EventRegistry.register(e, emitted_by: "Auth") }
    notif_events.each   { |e| Seams::EventRegistry.register(e, emitted_by: "Notifications") }
    billing_events.each { |e| Seams::EventRegistry.register(e, emitted_by: "Billing") }
    teams_events.each   { |e| Seams::EventRegistry.register(e, emitted_by: "Teams") }

    expect(Seams::EventRegistry.all.size).to eq(17)
  end
end
