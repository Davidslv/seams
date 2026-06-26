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
        expect(content).to include('"team.member_joined.teams"')
        expect(content).to include('"team.member_left.teams"')
        expect(content).to include('"invitation.sent.teams"')
        expect(content).to include('"invitation.accepted.teams"')
      end
    end

    it "registers the teams ability catalog (resource.action.engine)" do
      assert_file "engines/teams/lib/teams/engine.rb" do |content|
        expect(content).to include('initializer "teams.register_abilities"')
        expect(content).to include('owned_by: "Teams"')
        %w[
          team.read.teams team.manage.teams
          member.manage.teams invitation.manage.teams
        ].each do |code|
          expect(content).to include(%("#{code}"))
        end
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

    it "InvitationSubscriber consumes invitation.sent.teams via attach_class so reload picks up handler edits" do
      assert_file "engines/teams/app/subscribers/teams/invitation_subscriber.rb" do |content|
        expect(content).to include("attach_class(")
        expect(content).to include('"invitation.sent.teams"')
        expect(content).to include('class_name:  "Teams::InvitationSubscriber"')
        expect(content).to include("method_name: :handle_invitation_sent")
      end
    end

    it "InvitationSubscriber enqueues the mailer asynchronously and avoids legacy @attached flag" do
      assert_file "engines/teams/app/subscribers/teams/invitation_subscriber.rb" do |content|
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

    it "creates Teams::Membership with role inclusion + identity_id" do
      assert_file "engines/teams/app/models/teams/membership.rb" do |content|
        expect(content).to include("ROLES")
        expect(content).to include("def admin?")
        expect(content).to include("validates :identity_id")
      end
    end

    it "Teams::Membership has no belongs_to :identity / no user_id (Wave 9 bare-FK pattern)" do
      assert_file "engines/teams/app/models/teams/membership.rb" do |content|
        # Strip comments before asserting code-shape — explanatory
        # comments reference the concept by name to explain WHY
        # cross-engine references are absent.
        code = content.lines.reject { |line| line.lstrip.start_with?("#") }.join
        aggregate_failures do
          expect(code).not_to include("belongs_to :identity")
          expect(code).not_to include("Auth::Identity")
          expect(code).not_to include("Auth::User")
          expect(code).not_to include(":user_id")
        end
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
    it "creates TeamsController publishing team.created.teams with creator_identity_id" do
      assert_file "engines/teams/app/controllers/teams/teams_controller.rb" do |content|
        expect(content).to include('"team.created.teams"')
        expect(content).to include("creator_identity_id:")
        expect(content).not_to include("user_id:")
        expect(content).not_to include("owner_id:")
      end
    end

    it "creates MembershipsController publishing team.member_joined/left.teams with identity_id" do
      assert_file "engines/teams/app/controllers/teams/memberships_controller.rb" do |content|
        expect(content).to include('"team.member_joined.teams"')
        expect(content).to include('"team.member_left.teams"')
        expect(content).to include("identity_id: membership.identity_id")
        expect(content).not_to include("user_id: membership.user_id")
      end
    end

    it "creates InvitationsController with sent/accepted publishes + accept action" do
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include('"invitation.sent.teams"')
        expect(content).to include('"invitation.accepted.teams"')
        expect(content).to include("def accept")
        expect(content).to include("identity_id:   current_identity_id")
        expect(content).to include("invitation_id: @invitation.id")
      end
    end

    # Wave 9 regression: current_identity_id reads Auth::Current.identity,
    # not bare Current — without the qualified reference the lookup
    # silently 403s on every request.
    it "InvitationsController#current_identity_id reads Auth::Current.identity (not bare Current)" do
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include("Auth::Current")
        expect(content).not_to match(/(?<!Auth::)Current\.respond_to\?\(:identity\)/)
      end
    end

    # TeamsController delegates current_identity_id to Teams::Authorization,
    # which is the canonical source of Auth::Current resolution. The
    # controller itself no longer duplicates the resolver.
    it "TeamsController delegates current_identity_id to Teams::Authorization (no inline resolver)" do
      assert_file "engines/teams/app/controllers/teams/teams_controller.rb" do |content|
        expect(content).to include("include Teams::Authorization")
        expect(content).not_to include("def current_identity_id")
      end

      assert_file "engines/teams/lib/teams/concerns/authorization.rb" do |content|
        expect(content).to include("Auth::Current")
        expect(content).not_to match(/(?<!Auth::)Current\.respond_to\?\(:identity\)/)
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

    it "TeamsController includes Authorization and applies member/admin before_actions" do
      assert_file "engines/teams/app/controllers/teams/teams_controller.rb" do |content|
        expect(content).to include("include Teams::Authorization")
        expect(content).to include("before_action :require_team_member!,  only: %i[show]")
        expect(content).to include("before_action :require_team_admin!,   only: %i[edit update destroy]")
      end
    end

    it "InvitationsController#accept redirects unauthenticated requests to sign-in" do
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include("session[:pending_invitation_token] = params[:token]")
        expect(content).to include("main_app.new_session_path(return_to: request.url)")
      end
    end

    it "InvitationsController#accept verifies the accepting identity's email matches the invitation" do
      assert_file "engines/teams/app/controllers/teams/invitations_controller.rb" do |content|
        expect(content).to include("current_email == @invitation.email.to_s.downcase")
        expect(content).to include("This invitation was sent to a different email address.")
      end
    end
  end

  describe "concerns" do
    it "does NOT ship the host-User Teamable concern post-Wave-9" do
      teamable_path = File.join(destination_root, "engines/teams/lib/teams/concerns/teamable.rb")
      expect(File.exist?(teamable_path)).to be(false),
                                            "Teamable was removed in Wave 9 — host User model is gone"
    end

    it "creates Teams::Authorization with require_team_admin! and identity-based predicates" do
      assert_file "engines/teams/lib/teams/concerns/authorization.rb" do |content|
        expect(content).to include("def require_team_admin!")
        expect(content).to include("def require_team_member!")
        expect(content).to include("identity_id: current_identity_id")
        expect(content).to include("def current_identity_id")
        expect(content).not_to include("current_user_id")
      end
    end

    # Wave 9 regression: must reference the qualified Auth::Current.identity
    # (not bare Current.identity) so it resolves inside `module Teams`.
    # Pre-Wave-9 this silently no-op'd, 403'ing every team membership check.
    it "Teams::Authorization references Auth::Current.identity (not bare Current)" do
      assert_file "engines/teams/lib/teams/concerns/authorization.rb" do |content|
        expect(content).to include("Auth::Current")
        expect(content).not_to match(/(?<!Auth::)Current\.respond_to\?\(:identity\)/)
      end
    end

    it "registers AccountScoped + Authorization in ExposedConcerns (Teamable removed)" do
      assert_file "engines/teams/.rubocop.yml" do |content|
        expect(content).to include("Teams::AccountScoped")
        expect(content).to include("Teams::Authorization")
        expect(content).not_to include("Teams::Teamable")
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

    it "create_team_memberships uses identity_id (not user_id) and indexes accordingly" do
      pattern = File.join(destination_root, "engines/teams/db/migrate", "*_create_team_memberships.rb")
      content = File.read(Dir[pattern].first)
      expect(content).to include("t.bigint     :identity_id")
      expect(content).to include("add_index :team_memberships, %i[team_id identity_id], unique: true")
      expect(content).to include("add_index :team_memberships, :identity_id")
      expect(content).not_to include(":user_id")
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
        aggregate_failures do
          expect(content).to include("team.created.teams")
          expect(content).to include("creator_identity_id")
          expect(content).to include("identity_id")
          expect(content).to include("owner")
          expect(content).to include("admin")
          # README mentions Teamable in a "removed in Wave 9" note so
          # readers grepping for it find an explanation, not silence.
          expect(content).to include("removed")
        end
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
          # Wave 9: must reference the qualified Teams::Current.team
          # (not bare Current.team) so the default_scope actually
          # resolves inside `module Teams`.
          "Teams::Current.team",
          "before_validation :assign_current_team"
        ].each { |needle| expect(content).to include(needle) }
        # Regression: pre-Wave-9 the concern referenced bare `Current.team`,
        # which silently no-op'd inside `module Teams`. Reject that shape.
        expect(content).not_to match(/(?<!Teams::)Current\.team/)
      end
    end

    it "ships Teams::Current as a peer to Auth::Current and Accounts::Current" do
      assert_file "engines/teams/app/models/teams/current.rb" do |content|
        [
          "module Teams",
          "class Current < ActiveSupport::CurrentAttributes",
          "attribute :team"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "registers AccountScoped + Authorization in ExposedConcerns" do
      assert_file "engines/teams/.rubocop.yml" do |content|
        [
          "Teams::AccountScoped",
          "Teams::Authorization"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships FactoryBot factories for team, membership, invitation (no host User factory)" do
      assert_file "engines/teams/spec/factories/teams.rb" do |content|
        %w[
          team
          team_membership
          team_admin_membership
          team_invitation
        ].each { |name| expect(content).to include("factory :#{name}") }
        # Wave 9 dropped the host User; the factory file no longer
        # ships a `:teams_user` factory.
        expect(content).not_to include("factory :teams_user")
        expect(content).not_to include('class: "User"')
      end
    end

    it "wire_into_host adds factory_bot_rails to the test group and does NOT include in host User" do
      gen_path = File.expand_path(
        "../../../lib/generators/seams/teams/teams_generator.rb",
        __dir__
      )
      content = File.read(gen_path)
      expect(content).to include('host_inject_gem("factory_bot_rails"')
      expect(content).to include("group: :test")
      # Wave 9: host User is gone — the generator no longer CALLS
      # host_inject_include_in_user. Comments in the file may still
      # reference the helper by name (explaining its absence), so we
      # assert there's no executable call.
      executable = content.lines.reject { |line| line.lstrip.start_with?("#") }.join
      expect(executable).not_to include("host_inject_include_in_user")
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

  describe "Phase 4A (2/2) — views" do
    it "ships team list / show / new / edit views" do
      %w[index show new edit].each do |action|
        assert_file "engines/teams/app/views/teams/teams/#{action}.html.erb"
      end
    end

    it "ships members table view" do
      assert_file "engines/teams/app/views/teams/memberships/index.html.erb" do |content|
        expect(content).to include("Members of")
        expect(content).to include("team_membership_path")
      end
    end

    it "ships invitations management view when --with=invitations is enabled" do
      assert_file "engines/teams/app/views/teams/invitations/index.html.erb" do |content|
        expect(content).to include("Invitations")
        expect(content).to include("team_invitations_path")
        expect(content).to include("Send a new invitation")
      end
    end

    it "omits invitations view when --with=roles only" do
      flag_destination = File.expand_path("../../../tmp/teams_views_roles_only", __dir__)
      FileUtils.rm_rf(flag_destination)
      FileUtils.mkdir_p(File.join(flag_destination, "engines"))
      described_class.start(["--with=roles"], destination_root: flag_destination)

      expect(File.exist?(File.join(flag_destination,
                                   "engines/teams/app/views/teams/invitations/index.html.erb"))).to be(false)
      expect(File.exist?(File.join(flag_destination,
                                   "engines/teams/app/views/teams/teams/index.html.erb"))).to be(true)
    end
  end

  # Wave 10 Phase 2A: every catalogued insertion-point marker the teams
  # engine ships must appear in its target file. These assertions gate
  # against accidental marker removal in future template edits.
  # See doc/INSERTION_POINTS_CATALOGUE.md for the canonical list.
  describe "insertion-point markers (Wave 10)" do
    {
      "teams.engine.events" => "engines/teams/lib/teams/engine.rb",
      "teams.engine.abilities" => "engines/teams/lib/teams/engine.rb",
      "teams.engine.subscribers" => "engines/teams/lib/teams/engine.rb",
      "teams.routes.before_teams" => "engines/teams/config/routes.rb",
      "teams.routes.after_invitations" => "engines/teams/config/routes.rb",
      "teams.configuration.attributes" => "engines/teams/lib/teams/configuration.rb"
    }.each do |marker, path|
      it "ships #{marker} in #{path}" do
        assert_file path do |content|
          expect(content).to include("# seams:insertion-point #{marker}")
        end
      end
    end
  end
end
