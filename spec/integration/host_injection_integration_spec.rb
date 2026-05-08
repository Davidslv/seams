# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "rails/generators/test_case"

require "generators/seams/install/install_generator"
require "generators/seams/auth/auth_generator"
require "generators/seams/notifications/notifications_generator"
require "generators/seams/billing/billing_generator"
require "generators/seams/teams/teams_generator"
require "generators/seams/remove/remove_generator"

# End-to-end test that the canonical generators auto-edit the host's
# Gemfile / routes / User / ApplicationController and that the remove
# generator reverses those edits.
RSpec.describe "Host injection integration", type: :integration do
  let(:host_root) { File.expand_path("../../tmp/integration_host_injection", __dir__) }

  let(:host_files) do
    {
      "Gemfile" => %(source "https://rubygems.org"\ngem "rails"\n),
      "config/routes.rb" => "Rails.application.routes.draw do\nend\n",
      "app/models/user.rb" => "class User < ApplicationRecord\nend\n",
      "app/controllers/application_controller.rb" => "class ApplicationController < ActionController::Base\nend\n"
    }
  end

  let(:host_dirs) { %w[config/initializers config lib/tasks app/models app/controllers] }

  def prepare_host
    FileUtils.rm_rf(host_root)
    host_dirs.each  { |d| FileUtils.mkdir_p(File.join(host_root, d)) }
    host_files.each { |path, content| File.write(File.join(host_root, path), content) }
  end

  def run(generator, args = [])
    generator.start(args, destination_root: host_root)
  end

  def gemfile
    File.read(File.join(host_root, "Gemfile"))
  end

  def routes
    File.read(File.join(host_root, "config/routes.rb"))
  end

  def user_model
    File.read(File.join(host_root, "app/models/user.rb"))
  end

  def app_controller
    File.read(File.join(host_root, "app/controllers/application_controller.rb"))
  end

  before { prepare_host }
  after  { FileUtils.rm_rf(host_root) }

  it "seams:auth wires bcrypt + mount + Authenticatable + Authentication into the host" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)

    expect(gemfile).to        include('gem "bcrypt"')
    expect(routes).to         include('mount Auth::Engine, at: "/auth"')
    expect(user_model).to     include("include Auth::Authenticatable")
    expect(app_controller).to include("include Auth::Authentication")
  end

  it "seams:billing wires the official stripe gem + mount but no User edit (Wave 9: Billable lives on Account)" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::BillingGenerator)

    # Billing speaks Stripe via the official `stripe` Ruby gem
    # (https://github.com/stripe/stripe-ruby). Wave 8's earlier
    # Faraday-only decision was reversed — see
    # feedback_external_apis.md for the policy.
    expect(gemfile).to include('gem "stripe"')
    expect(routes).to  include('mount Billing::Engine, at: "/billing"')
    # Post-Wave-9: Billing addresses an Accounts::Account (the
    # tenant), not a User (the human). The engine includes
    # Billing::Billable into Billing.configuration.billable_class
    # (default "Accounts::Account") at boot via a config.to_prepare
    # hook — there is no host User edit. Hosts on a different
    # tenant model override the config knob.
    expect(user_model).not_to include("include Billing::Billable")
  end

  it "seams:notifications wires mount + initializer into the host (Wave 9: no auto-include into a host User)" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::NotificationsGenerator)

    expect(routes).to include('mount Notifications::Engine, at: "/notifications"')

    # Wave 9 dropped the auto-include of Notifications::Notifiable into
    # app/models/user.rb. The canonical demo no longer has a host User —
    # the "human" is Auth::Identity. Hosts opt in by uncommenting one of
    # the include patterns documented in the initializer template.
    expect(user_model).not_to include("include Notifications::Notifiable")

    initializer = File.join(host_root, "config/initializers/notifications.rb")
    expect(File.exist?(initializer)).to be(true)

    initializer_body = File.read(initializer)
    expect(initializer_body).to include("Auth::Identity.include(Notifications::Notifiable)")
    expect(initializer_body).to include("Notifications.configure")
  end

  it "seams:teams wires mount but no Teamable include (Wave 9: host User is gone)" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::TeamsGenerator)

    expect(routes).to         include('mount Teams::Engine, at: "/teams"')
    # Wave 9 removed Teams::Teamable along with the canonical demo's
    # host User model. The teams generator no longer touches
    # app/models/user.rb — hosts that DO maintain a User model are
    # responsible for any team-membership query helpers themselves.
    expect(user_model).not_to include("Teams::Teamable")
  end

  it "all four canonical generators stack their edits without overwriting each other" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)
    run(Seams::Generators::BillingGenerator)
    run(Seams::Generators::TeamsGenerator)

    %w[Auth::Engine Notifications::Engine Billing::Engine Teams::Engine].each do |klass|
      expect(routes).to include("mount #{klass}")
    end

    # Wave 9: Teams::Teamable, Notifications::Notifiable AND
    # Billing::Billable auto-includes into the host User are gone.
    # - notifications: ships an initializer documenting the optional
    #   include against Auth::Identity.
    # - teams: no longer touches the host User at all.
    # - billing: includes Billable into Accounts::Account (the
    #   tenant) at boot via a config.to_prepare hook.
    # Only Auth still injects its host User concern.
    expect(user_model).to     include("include Auth::Authenticatable")
    expect(user_model).not_to include("Billing::Billable")
    expect(user_model).not_to include("Teams::Teamable")
    expect(user_model).not_to include("Notifications::Notifiable")

    %w[bcrypt faraday].each { |name| expect(gemfile).to include(%(gem "#{name}")) }
  end

  it "running a canonical generator twice does not duplicate host edits" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    # Auth refuses to regenerate over an existing engine; that's fine —
    # the host edits should already be present and not duplicated by
    # any further canonical generator that might mention the same gem.
    run(Seams::Generators::NotificationsGenerator)

    expect(routes.scan("mount Auth::Engine").size).to eq(1)
    expect(user_model.scan("include Auth::Authenticatable").size).to eq(1)
  end

  it "seams:remove auth unwires the auth host edits" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::RemoveGenerator, ["auth", "--force"])

    expect(routes).not_to         include("mount Auth::Engine")
    expect(user_model).not_to     include("include Auth::Authenticatable")
    expect(app_controller).not_to include("include Auth::Authentication")
  end

  it "seams:remove notifications keeps unrelated host edits intact" do
    run(Seams::Generators::InstallGenerator)
    run(Seams::Generators::AuthGenerator)
    run(Seams::Generators::NotificationsGenerator)
    run(Seams::Generators::RemoveGenerator, ["notifications", "--force"])

    expect(routes).not_to include("mount Notifications::Engine")
    # Wave 9: the notifications generator no longer auto-injects
    # Notifications::Notifiable into the host User, so there's nothing
    # to assert removed there. (The user_model line below would always
    # pass post-Wave-9, but we keep it as a safety net.)
    expect(user_model).not_to include("include Notifications::Notifiable")
    # auth edits survived
    expect(routes).to         include("mount Auth::Engine")
    expect(user_model).to     include("include Auth::Authenticatable")
  end
end
