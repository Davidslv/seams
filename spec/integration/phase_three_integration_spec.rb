# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "rails/generators/test_case"
require "yaml"

require "generators/seams/install/install_generator"
require "generators/seams/auth/auth_generator"
require "generators/seams/notifications/notifications_generator"
require "generators/seams/billing/billing_generator"

RSpec.describe "Phase 3 integration", type: :integration do
  let(:host_root) { File.expand_path("../../tmp/integration_phase_three", __dir__) }

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

  it "billing engine coexists with auth + notifications and wires its sibling cops correctly" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)
    run(Seams::Generators::BillingGenerator)

    %w[auth notifications billing].each do |dir|
      expect(File.exist?(File.join(host_root, "engines/#{dir}/lib/#{dir}/engine.rb"))).to be(true)
    end

    billing_yml = YAML.safe_load_file(File.join(host_root, "engines/billing/.rubocop.yml"))
    expect(billing_yml.dig("Seams/NoCrossEngineModelAccess", "OtherEngines"))
      .to match_array(%w[Auth Notifications])
    expect(billing_yml.dig("Seams/NoCrossEngineModelAccess", "ExposedConcerns"))
      .to eq(["Billing::Billable"])
  end

  it "every Stripe API call cited in the gateway template references docs.stripe.com" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::BillingGenerator)

    gateway = File.read(File.join(host_root, "engines/billing/lib/billing/gateways/stripe.rb"))

    %w[
      docs.stripe.com/api/subscriptions/create
      docs.stripe.com/api/subscriptions/cancel
      docs.stripe.com/api/subscriptions/retrieve
      docs.stripe.com/webhooks/signatures
    ].each do |url|
      expect(gateway).to include(url), "expected gateway to cite #{url}"
    end
  end

  it "every generated billing Ruby file parses without syntax errors" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::BillingGenerator)

    failures = []
    Dir[File.join(host_root, "engines/billing/**/*.rb")].each do |path|
      result = `ruby -c #{path.shellescape} 2>&1`
      failures << "#{path}: #{result.strip}" unless $CHILD_STATUS.success?
    end

    expect(failures).to be_empty, "expected all billing files to parse:\n#{failures.join("\n")}"
  end

  it "all three engines' migrations get distinct timestamps" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)
    run(Seams::Generators::BillingGenerator)

    timestamps = Dir[File.join(host_root, "engines/*/db/migrate/*.rb")]
                 .map { |p| File.basename(p).split("_").first }

    expect(timestamps).to eq(timestamps.uniq), "migration timestamps collided: #{timestamps}"
  end

  it "registering all engines' events does not collide" do
    Seams::EventRegistry.reset!

    auth_events = %w[identity.signed_up.auth identity.signed_in.auth identity.signed_out.auth session.expired.auth]
    notif_events = %w[notification.queued.notifications notification.delivered.notifications notification.failed.notifications]
    billing_events = %w[subscription.created.billing subscription.updated.billing
                        subscription.canceled.billing invoice.paid.billing invoice.failed.billing]

    auth_events.each    { |e| Seams::EventRegistry.register(e, emitted_by: "Auth") }
    notif_events.each   { |e| Seams::EventRegistry.register(e, emitted_by: "Notifications") }
    billing_events.each { |e| Seams::EventRegistry.register(e, emitted_by: "Billing") }

    expect(Seams::EventRegistry.all.size).to eq(12)
  end
end
