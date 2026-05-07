# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/teams/teams_generator"

RSpec.describe Seams::Generators::TeamsGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/teams_generator", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
  end

  def run_generator
    described_class.start([], destination_root: destination_root)
  end

  def assert_file(path)
    full = File.join(destination_root, path)
    expect(File.exist?(full)).to be(true), "expected #{path} to be created"
    yield(File.read(full)) if block_given?
  end

  before do
    prepare_destination
    run_generator
  end

  describe "engine entry point" do
    it "registers the five canonical team events" do
      assert_file "engines/teams/lib/teams/engine.rb" do |content|
        expect(content).to include('"team.created.teams"')
        expect(content).to include('"team.member_added.teams"')
        expect(content).to include('"team.member_removed.teams"')
        expect(content).to include('"invitation.sent.teams"')
        expect(content).to include('"invitation.accepted.teams"')
      end
    end
  end

  describe "configuration" do
    it "creates Teams::Configuration with invitation_ttl + max_members_per_team" do
      assert_file "engines/teams/lib/teams/configuration.rb" do |content|
        expect(content).to include("invitation_ttl")
        expect(content).to include("max_members_per_team")
      end
    end

    it "exposes invitation_mailer_from + host_url for the InvitationMailer" do
      assert_file "engines/teams/lib/teams/configuration.rb" do |content|
        expect(content).to include("invitation_mailer_from")
        expect(content).to include("host_url")
      end
    end
  end

  describe "InvitationMailer + subscriber" do
    it "ships an InvitationMailer that sends to the invitation.email" do
      assert_file "engines/teams/app/mailers/teams/invitation_mailer.rb" do |content|
        expect(content).to include("class InvitationMailer < ActionMailer::Base")
        expect(content).to include("def invite(invitation_id)")
        expect(content).to include("Teams.configuration.invitation_mailer_from")
        expect(content).to include("Teams.configuration.host_url")
      end
    end

    it "ships a default invite.text.erb body the host can override" do
      assert_file "engines/teams/app/views/teams/invitation_mailer/invite.text.erb"
    end

    it "InvitationSubscriber consumes invitation.sent.teams via attach_once and enqueues the mailer" do
      assert_file "engines/teams/app/subscribers/teams/invitation_subscriber.rb" do |content|
        expect(content).to include('attach_once(SUBSCRIBER_KEY, "invitation.sent.teams")')
        expect(content).to include("Teams::InvitationMailer.invite(invitation_id).deliver_later")
        expect(content).not_to include("@attached =")
      end
    end

    it "engine.rb attaches the subscriber after_initialize" do
      assert_file "engines/teams/lib/teams/engine.rb" do |content|
        expect(content).to include("Teams::InvitationSubscriber.attach!")
      end
    end

    it "InvitationsController#create publishes invitation_id + token" do
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include("invitation_id: invitation.id")
        expect(content).to include("token:         invitation.token")
      end
    end
  end

  describe "models" do
    it "creates Teams::Team with slug + memberships association" do
      assert_file "engines/teams/app/models/teams/team.rb" do |content|
        expect(content).to include("has_many :memberships")
        expect(content).to include("has_many :invitations")
        expect(content).to include("def assign_slug")
      end
    end

    it "creates Teams::Membership with role inclusion" do
      assert_file "engines/teams/app/models/teams/membership.rb" do |content|
        expect(content).to include("ROLES")
        expect(content).to include("def admin?")
      end
    end

    it "creates Teams::Invitation with token + expiry assignment" do
      assert_file "engines/teams/app/models/teams/invitation.rb" do |content|
        expect(content).to include("SecureRandom.urlsafe_base64(32)")
        expect(content).to include("def expired?")
        expect(content).to include("Teams.configuration.invitation_ttl")
      end
    end
  end

  describe "controllers" do
    it "creates TeamsController publishing team.created.teams" do
      assert_file "engines/teams/app/controllers/teams/teams_controller.rb" do |content|
        expect(content).to include('"team.created.teams"')
      end
    end

    it "creates MembershipsController publishing team.member_added/removed.teams" do
      assert_file "engines/teams/app/controllers/teams/memberships_controller.rb" do |content|
        expect(content).to include('"team.member_added.teams"')
        expect(content).to include('"team.member_removed.teams"')
      end
    end

    it "creates InvitationsController with sent/accepted publishes + accept action" do
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include('"invitation.sent.teams"')
        expect(content).to include('"invitation.accepted.teams"')
        expect(content).to include("def accept")
      end
    end

    it "InvitationsController#accept reads token from params and locks the row" do
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include("Teams::Invitation.lock.find_by!(token: params[:token])")
        expect(content).to include("@invitation.accepted?")
        expect(content).to include("ActiveRecord::RecordNotUnique")
      end
    end

    it "controllers include Teams::Authorization for require_team_admin!" do
      assert_file "engines/teams/app/controllers/teams/memberships_controller.rb" do |content|
        expect(content).to include("include Teams::Authorization")
        expect(content).to include("require_team_admin!")
      end

      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include("include Teams::Authorization")
        expect(content).to include("require_team_admin!")
      end
    end
  end

  describe "concerns" do
    it "creates Teams::Teamable with member_of?, admin_of?, owner_of?" do
      assert_file "engines/teams/lib/teams/concerns/teamable.rb" do |content|
        expect(content).to include('require "active_support/concern"')
        expect(content).to include("def member_of?")
        expect(content).to include("def admin_of?")
        expect(content).to include("def owner_of?")
      end
    end

    it "creates Teams::Authorization with require_team_admin!" do
      assert_file "engines/teams/lib/teams/concerns/authorization.rb" do |content|
        expect(content).to include("def require_team_admin!")
        expect(content).to include("def require_team_member!")
      end
    end

    it "registers both concerns in ExposedConcerns" do
      assert_file "engines/teams/.rubocop.yml" do |content|
        expect(content).to include("Teams::Teamable")
        expect(content).to include("Teams::Authorization")
      end
    end
  end

  describe "migrations" do
    it "creates teams + team_memberships + team_invitations migrations" do
      %w[create_teams create_team_memberships create_team_invitations].each do |slug|
        pattern = File.join(destination_root, "engines/teams/db/migrate", "*_#{slug}.rb")
        file    = Dir[pattern].first
        expect(file).not_to be_nil, "expected migration matching *_#{slug}.rb"

        content = File.read(file)
        expect(content).to include("# What:"), "expected #{file} to have a What: comment"
      end
    end
  end

  describe "routes" do
    it "draws nested teams + memberships + invitations" do
      assert_file "engines/teams/config/routes.rb" do |content|
        expect(content).to include("resources :teams")
        expect(content).to include("resources :memberships")
        expect(content).to include("resources :invitations")
      end
    end

    it "exposes a top-level token-keyed accept route (no team_id needed)" do
      assert_file "engines/teams/config/routes.rb" do |content|
        expect(content).to include('"/invitations/accept/:token"')
        expect(content).to include("as: :accept_invitation")
      end
    end
  end

  describe "documentation + specs" do
    it "rewrites README with the canonical events table + role rubric" do
      assert_file "engines/teams/README.md" do |content|
        expect(content).to include("team.created.teams")
        expect(content).to include("Teams::Teamable")
        expect(content).to include("owner")
        expect(content).to include("admin")
      end
    end

    it "creates per-model spec stubs" do
      assert_file "engines/teams/spec/models/teams/team_spec.rb"
      assert_file "engines/teams/spec/models/teams/membership_spec.rb"
      assert_file "engines/teams/spec/models/teams/invitation_spec.rb"
    end
  end

  describe "Phase 4A — AccountScoped concern + factories" do
    it "ships the AccountScoped concern with belongs_to :team + default_scope" do
      assert_file "engines/teams/lib/teams/concerns/account_scoped.rb" do |content|
        [
          "module AccountScoped",
          'belongs_to :team, class_name: "Teams::Team"',
          "default_scope",
          "Current.team",
          "before_validation :assign_current_team"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "registers AccountScoped + Teamable + Authorization in ExposedConcerns" do
      assert_file "engines/teams/.rubocop.yml" do |content|
        [
          "Teams::Teamable",
          "Teams::AccountScoped",
          "Teams::Authorization"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships FactoryBot factories for team, membership, invitation, host User" do
      assert_file "engines/teams/spec/factories/teams.rb" do |content|
        %w[
          teams_user
          team
          team_membership
          team_admin_membership
          team_invitation
        ].each { |name| expect(content).to include("factory :#{name}") }
      end
    end

    it "wire_into_host adds factory_bot_rails to the test group" do
      gen_path = File.expand_path(
        "../../../lib/generators/seams/teams/teams_generator.rb",
        __dir__
      )
      content = File.read(gen_path)
      expect(content).to include('host_inject_gem("factory_bot_rails"')
      expect(content).to include("group: :test")
    end
  end

  describe "Phase 4A — --with generator flag" do
    let(:flag_destination) { File.expand_path("../../../tmp/teams_with_flag", __dir__) }

    def run_with(features)
      FileUtils.rm_rf(flag_destination)
      FileUtils.mkdir_p(flag_destination)
      FileUtils.mkdir_p(File.join(flag_destination, "engines"))
      described_class.start(["--with=#{features}"], destination_root: flag_destination)
    end

    it "default ships invitations + roles" do
      assert_file "engines/teams/app/models/teams/invitation.rb"
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb"
      assert_file "engines/teams/app/mailers/teams/invitation_mailer.rb"
      assert_file "engines/teams/lib/teams/concerns/authorization.rb"
    end

    it "--with=invitations omits the Authorization concern" do
      run_with("invitations")

      invitation_path    = File.join(flag_destination, "engines/teams/app/models/teams/invitation.rb")
      authorization_path = File.join(flag_destination, "engines/teams/lib/teams/concerns/authorization.rb")
      expect(File.exist?(invitation_path)).to be(true)
      expect(File.exist?(authorization_path)).to be(false)
    end

    it "--with=roles omits the Invitation model + mailer + subscriber" do
      run_with("roles")

      paths = {
        authorization: "engines/teams/lib/teams/concerns/authorization.rb",
        invitation: "engines/teams/app/models/teams/invitation.rb",
        mailer: "engines/teams/app/mailers/teams/invitation_mailer.rb",
        subscriber: "engines/teams/app/subscribers/teams/invitation_subscriber.rb"
      }
      expect(File.exist?(File.join(flag_destination, paths[:authorization]))).to be(true)
      expect(File.exist?(File.join(flag_destination, paths[:invitation]))).to    be(false)
      expect(File.exist?(File.join(flag_destination, paths[:mailer]))).to        be(false)
      expect(File.exist?(File.join(flag_destination, paths[:subscriber]))).to    be(false)
    end

    it "--with=garbage falls back to all features (no surprising half-installed engine)" do
      run_with("garbage")
      expect(File.exist?(File.join(flag_destination,
                                   "engines/teams/app/models/teams/invitation.rb"))).to be(true)
      expect(File.exist?(File.join(flag_destination,
                                   "engines/teams/lib/teams/concerns/authorization.rb"))).to be(true)
    end
  end
end
