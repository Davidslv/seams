# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "yaml"
require "generators/seams/admin/admin_generator"

# Phase 2 schema covers every table the twelve dashboards target.
ADMIN_PHASE_TWO_SCHEMA_TABLES = %w[
  auth_identities
  accounts
  accounts_memberships
  teams
  team_memberships
  team_invitations
  notifications
  notification_preferences
  notification_deliveries
  billing_plans
  billing_subscriptions
  billing_invoices
  billing_lifetime_passes
  billing_webhook_events
  core_audit_logs
].freeze

# Per-engine slim model stubs the dummy ships so Administrate's
# dashboard lookup can resolve `Auth::Identity`, `Accounts::Account`,
# `Billing::Plan`, etc. in the generated dummy app.
ADMIN_PHASE_TWO_DUMMY_MODEL_STUBS = {
  "engines/admin/spec/dummy/app/models/accounts/account.rb" => 'self.table_name = "accounts"',
  "engines/admin/spec/dummy/app/models/accounts/membership.rb" => 'self.table_name = "accounts_memberships"',
  "engines/admin/spec/dummy/app/models/teams/team.rb" => 'self.table_name = "teams"',
  "engines/admin/spec/dummy/app/models/teams/membership.rb" => 'self.table_name = "team_memberships"',
  "engines/admin/spec/dummy/app/models/teams/invitation.rb" => 'self.table_name = "team_invitations"',
  "engines/admin/spec/dummy/app/models/notifications/notification.rb" => 'self.table_name = "notifications"',
  "engines/admin/spec/dummy/app/models/notifications/notification_preference.rb" => 'self.table_name = "notification_preferences"',
  "engines/admin/spec/dummy/app/models/billing/plan.rb" => 'self.table_name = "billing_plans"',
  "engines/admin/spec/dummy/app/models/billing/subscription.rb" => 'self.table_name = "billing_subscriptions"',
  "engines/admin/spec/dummy/app/models/billing/invoice.rb" => 'self.table_name = "billing_invoices"',
  "engines/admin/spec/dummy/app/models/billing/lifetime_pass.rb" => 'self.table_name = "billing_lifetime_passes"'
}.freeze

# Phase 2 dashboard catalogue: [snake_case_basename, dashboard_class,
# model_class]. The dashboard class lives at app/dashboards/admin/
# <basename>_dashboard.rb; the controller at app/controllers/admin/
# <basename.pluralize>_controller.rb.
ADMIN_PHASE_TWO_DASHBOARD_TABLE = [
  ["identity",                "Admin::IdentityDashboard",                "Auth::Identity"],
  ["account",                 "Admin::AccountDashboard",                 "Accounts::Account"],
  ["accounts_membership",     "Admin::AccountsMembershipDashboard",      "Accounts::Membership"],
  ["team",                    "Admin::TeamDashboard",                    "Teams::Team"],
  ["teams_membership",        "Admin::TeamsMembershipDashboard",         "Teams::Membership"],
  ["invitation",              "Admin::InvitationDashboard",              "Teams::Invitation"],
  ["notification",            "Admin::NotificationDashboard",            "Notifications::Notification"],
  ["notification_preference", "Admin::NotificationPreferenceDashboard",  "Notifications::NotificationPreference"],
  ["plan",                    "Admin::PlanDashboard",                    "Billing::Plan"],
  ["subscription",            "Admin::SubscriptionDashboard",            "Billing::Subscription"],
  ["invoice",                 "Admin::InvoiceDashboard",                 "Billing::Invoice"],
  ["lifetime_pass",           "Admin::LifetimePassDashboard",            "Billing::LifetimePass"]
].freeze

ADMIN_PHASE_TWO_ROUTE_PLURALS = %w[
  identities
  accounts
  accounts_memberships
  teams
  teams_memberships
  invitations
  notifications
  notification_preferences
  plans
  subscriptions
  invoices
  lifetime_passes
].freeze

# Phase 3 — every entry in DASHBOARD_MODELS templates two policy
# files: one platform, one tenant. The tuple is [basename,
# platform_class, tenant_class]; the generator expands those into
# files under app/policies/admin/{platform,tenant}/.
ADMIN_PHASE_THREE_POLICY_TABLE = [
  ["identity",                "Admin::Platform::IdentityPolicy",                "Admin::Tenant::IdentityPolicy"],
  ["account",                 "Admin::Platform::AccountPolicy",                 "Admin::Tenant::AccountPolicy"],
  ["accounts_membership",     "Admin::Platform::AccountsMembershipPolicy",      "Admin::Tenant::AccountsMembershipPolicy"],
  ["team",                    "Admin::Platform::TeamPolicy",                    "Admin::Tenant::TeamPolicy"],
  ["teams_membership",        "Admin::Platform::TeamsMembershipPolicy",         "Admin::Tenant::TeamsMembershipPolicy"],
  ["invitation",              "Admin::Platform::InvitationPolicy",              "Admin::Tenant::InvitationPolicy"],
  ["notification",            "Admin::Platform::NotificationPolicy",            "Admin::Tenant::NotificationPolicy"],
  ["notification_preference", "Admin::Platform::NotificationPreferencePolicy",  "Admin::Tenant::NotificationPreferencePolicy"],
  ["plan",                    "Admin::Platform::PlanPolicy",                    "Admin::Tenant::PlanPolicy"],
  ["subscription",            "Admin::Platform::SubscriptionPolicy",            "Admin::Tenant::SubscriptionPolicy"],
  ["invoice",                 "Admin::Platform::InvoicePolicy",                 "Admin::Tenant::InvoicePolicy"],
  ["lifetime_pass",           "Admin::Platform::LifetimePassPolicy",            "Admin::Tenant::LifetimePassPolicy"]
].freeze

RSpec.describe Seams::Generators::AdminGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/admin_generator", __dir__) }

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

  # Pulled out of the README spec body so the example stays under
  # the RSpec/ExampleLength threshold.
  def readme_needles
    %w[
      Administrate
      Pundit
      Seams::Admin
      authenticator
      tenancy_scope
      theme_css_path
      before_admin_action
      platform
      tenant
      staff?
      AdminUser
      Ejecting
    ]
  end

  describe "engine entry point" do
    it "places the engine under the Seams::Admin namespace" do
      assert_file "engines/admin/lib/admin/engine.rb" do |content|
        expect(content).to include("module Seams")
        expect(content).to include("module Admin")
        expect(content).to include("class Engine < ::Rails::Engine")
        expect(content).to include("isolate_namespace Seams::Admin")
      end
    end

    it "asserts Auth::Identity + Administrate are present at boot" do
      assert_file "engines/admin/lib/admin/engine.rb" do |content|
        expect(content).to include("config.after_initialize")
        expect(content).to include("Auth::Identity")
        expect(content).to include("Administrate")
        expect(content).to include("seams:auth")
      end
    end

    it "exposes Seams::Admin.configure / configuration / config", :aggregate_failures do
      assert_file "engines/admin/lib/admin.rb" do |content|
        expect(content).to include("module Seams")
        expect(content).to include("module Admin")
        expect(content).to include("def configure")
        expect(content).to include("def configuration")
        expect(content).to include("def config")
        expect(content).to include('require "admin/configuration"')
        expect(content).to include('require "admin/engine"')
        expect(content).to include('require "admin/concerns/authenticator"')
      end
    end
  end

  describe "configuration" do
    it "ships the documented knobs as attr_accessor", :aggregate_failures do
      assert_file "engines/admin/lib/admin/configuration.rb" do |content|
        expect(content).to include("module Seams")
        expect(content).to include("module Admin")
        expect(content).to include("class Configuration")
        expect(content).to include("attr_accessor")
        expect(content).to include(":authenticator")
        expect(content).to include(":tenancy_scope")
        expect(content).to include(":theme_css_path")
        expect(content).to include(":before_admin_action")
        # Phase 4 knob — configurable resolver for the active
        # Accounts::Membership; hosts override the default
        # `Accounts::Current.membership` lookup here without ejecting
        # the controller.
        expect(content).to include(":current_membership_resolver")
      end
    end

    it "defaults the authenticator to staff? on current_identity" do
      assert_file "engines/admin/lib/admin/configuration.rb" do |content|
        expect(content).to include("@authenticator")
        expect(content).to include("staff?")
        expect(content).to include("current_identity")
      end
    end

    it "defaults tenancy_scope to :platform" do
      assert_file "engines/admin/lib/admin/configuration.rb" do |content|
        expect(content).to include("@tenancy_scope = :platform")
      end
    end

    it "defaults theme_css_path and before_admin_action to nil" do
      assert_file "engines/admin/lib/admin/configuration.rb" do |content|
        expect(content).to include("@theme_css_path = nil")
        expect(content).to include("@before_admin_action = nil")
      end
    end
  end

  describe "authenticator concern" do
    it "creates Seams::Admin::Authenticator with before_action gates", :aggregate_failures do
      assert_file "engines/admin/lib/admin/concerns/authenticator.rb" do |content|
        expect(content).to include("module Seams")
        expect(content).to include("module Admin")
        expect(content).to include("module Authenticator")
        expect(content).to include('require "active_support/concern"')
        expect(content).to include("extend ActiveSupport::Concern")
        expect(content).to include("before_action :authenticate_admin!")
        expect(content).to include("before_action :run_before_admin_action_hook")
        expect(content).to include("Seams::Admin.config.authenticator")
        expect(content).to include("Seams::Admin.config.before_admin_action")
        expect(content).to include(":forbidden")
      end
    end

    it "fails closed when the gate is unconfigured" do
      assert_file "engines/admin/lib/admin/concerns/authenticator.rb" do |content|
        # Defensive: a host that nils the gate must lock admin
        # closed, not open. The spec locks this in.
        expect(content).to include("respond_to?(:call)")
      end
    end
  end

  describe "application controller" do
    it "subclasses Administrate::ApplicationController and includes the Authenticator concern" do
      assert_file "engines/admin/app/controllers/seams/admin/application_controller.rb" do |content|
        expect(content).to include("module Seams")
        expect(content).to include("module Admin")
        expect(content).to include("class ApplicationController < ::Administrate::ApplicationController")
        expect(content).to include("include ::Seams::Admin::Authenticator")
      end
    end

    it "wires Phase 3's audit-log auto-write" do
      assert_file "engines/admin/app/controllers/seams/admin/application_controller.rb" do |content|
        expect(content).to include("Phase 3")
        expect(content).to include("after_action :record_admin_audit")
        expect(content).to include("Core::AuditLog").or include("Core::Auditable")
      end
    end

    it "exposes seams_admin_tenancy_scope as a helper for dashboards" do
      assert_file "engines/admin/app/controllers/seams/admin/application_controller.rb" do |content|
        expect(content).to include("helper_method :seams_admin_tenancy_scope")
        expect(content).to include("def seams_admin_tenancy_scope")
      end
    end

    it "ships a pundit_user hook returning the current Identity" do
      assert_file "engines/admin/app/controllers/seams/admin/application_controller.rb" do |content|
        expect(content).to include("def pundit_user")
        expect(content).to include("Auth::Current")
      end
    end
  end

  describe "routes" do
    it "draws the engine routes under the Seams::Admin namespace" do
      assert_file "engines/admin/config/routes.rb" do |content|
        expect(content).to include("Seams::Admin::Engine.routes.draw do")
      end
    end
  end

  describe "documentation" do
    it "rewrites README with the canonical configuration + ejection notes" do
      assert_file "engines/admin/README.md" do |content|
        readme_needles.each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "factories" do
    it "ships a placeholder factory file Phase 2 fills in" do
      assert_file "engines/admin/spec/factories/admin.rb" do |content|
        expect(content).to include("FactoryBot.define do")
        expect(content).to include("Phase 2")
      end
    end
  end

  describe "runtime spec" do
    it "ships a boot spec covering engine load, configuration knobs, and the default authenticator" do
      assert_file "engines/admin/spec/runtime/admin_boot_spec.rb" do |content|
        [
          "Seams::Admin engine boot",
          "Seams::Admin::Engine",
          "Seams::Admin::Configuration",
          "Seams::Admin::Authenticator",
          ":platform",
          "staff: true",
          "staff: false",
          "Seams::Admin.configure"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    # Phase 2: the runtime spec asserts the real Administrate gem is
    # loaded (no longer the Phase 1 stub) and every dashboard class
    # is reachable.
    it "asserts the real Administrate ancestor and every Phase 2 dashboard loads" do
      assert_file "engines/admin/spec/runtime/admin_boot_spec.rb" do |content|
        expect(content).to include("::Administrate::ApplicationController")
        expect(content).to include("::Administrate::BaseDashboard")
        expect(content).to include("Admin::IdentityDashboard")
        expect(content).to include("Admin::LifetimePassDashboard")
        expect(content).to include("ATTRIBUTE_TYPES")
      end
    end

    it "asserts the engine routes contain a mount point for each dashboard" do
      assert_file "engines/admin/spec/runtime/admin_boot_spec.rb" do |content|
        expect(content).to include("Seams::Admin::Engine.routes.routes")
        expect(content).to include("/identities")
        expect(content).to include("/lifetime_passes")
      end
    end
  end

  describe "Phase 2 generator surface" do
    let(:gen_path) do
      File.expand_path("../../../lib/generators/seams/admin/admin_generator.rb", __dir__)
    end

    # Every canonical model the DASHBOARD_MODELS constant should
    # cover. Pulled out to keep the assertion under the example-length
    # rubocop threshold.
    let(:dashboard_models) do
      ADMIN_PHASE_TWO_DASHBOARD_TABLE.map { |entry| entry[2] }
    end

    it "declares a DASHBOARD_MODELS constant covering the twelve canonical models" do
      content = File.read(gen_path)
      expect(content).to include("DASHBOARD_MODELS")
      dashboard_models.each { |model| expect(content).to include(model) }
    end

    it "exposes a create_dashboards method that templates each dashboard + controller" do
      content = File.read(gen_path)
      expect(content).to include("def create_dashboards")
      expect(content).to include("DASHBOARD_MODELS.each")
      expect(content).to include("template_unless_ejected")
      expect(content).to include("app/dashboards/admin/")
      expect(content).to include("app/controllers/admin/")
    end

    it "no longer writes a Phase 1 Administrate stub initializer" do
      content = File.read(gen_path)
      expect(content).not_to include("write_administrate_stub")
      expect(content).not_to include("administrate_stub.rb")
    end
  end

  describe "dummy app" do
    it "writes a schema with the pgcrypto extension and a UUID accounts table" do
      assert_file "engines/admin/spec/dummy/db/schema.rb" do |content|
        [
          "create_table :auth_identities",
          "create_table :accounts, id: :uuid",
          "create_table :accounts_memberships, id: :uuid",
          'enable_extension "pgcrypto"'
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    ADMIN_PHASE_TWO_SCHEMA_TABLES.each do |table|
      it "writes create_table for #{table}" do
        assert_file "engines/admin/spec/dummy/db/schema.rb" do |content|
          expect(content).to include("create_table :#{table}")
        end
      end
    end

    it "mounts Seams::Admin::Engine at /admin in the dummy routes" do
      assert_file "engines/admin/spec/dummy/config/routes.rb" do |content|
        expect(content).to include('mount Admin::Engine, at: "/admin"')
          .or include('mount Seams::Admin::Engine, at: "/admin"')
      end
    end

    it "ships an Auth::Identity stub so the boot spec can construct an Identity" do
      assert_file "engines/admin/spec/dummy/app/models/auth/identity.rb" do |content|
        expect(content).to include("class Identity < ApplicationRecord")
        expect(content).to include('self.table_name = "auth_identities"')
        expect(content).to include("has_secure_password")
      end
    end

    it "ships an Auth::Current stub" do
      assert_file "engines/admin/spec/dummy/app/models/auth/current.rb" do |content|
        expect(content).to include("class Current < ActiveSupport::CurrentAttributes")
        expect(content).to include("attribute :identity")
      end
    end

    ADMIN_PHASE_TWO_DUMMY_MODEL_STUBS.each do |path, table_name_assertion|
      it "ships a slim model stub at #{path}" do
        assert_file path do |content|
          expect(content).to include(table_name_assertion)
          expect(content).to include("< ApplicationRecord")
        end
      end
    end

    it "amends spec/dummy/config/application.rb to require the model stubs at boot" do
      assert_file "engines/admin/spec/dummy/config/application.rb" do |content|
        expect(content).to include("seams:admin dummy stubs")
        expect(content).to include('Dir[File.expand_path("../app/models/**/*.rb", __dir__)]')
      end
    end

    # Phase 2 deletes Phase 1's Administrate stub initializer.
    it "does NOT ship a Phase 1 Administrate stub initializer" do
      stub_path = File.join(destination_root,
                            "engines/admin/spec/dummy/config/initializers/administrate_stub.rb")
      expect(File.exist?(stub_path)).to be(false), "Phase 2 must remove the Phase 1 stub initializer"
    end
  end

  # Phase 2 — twelve dashboard templates, twelve controller templates.
  # Each dashboard subclasses Administrate::BaseDashboard and ships
  # ATTRIBUTE_TYPES / COLLECTION_ATTRIBUTES / SHOW_PAGE_ATTRIBUTES /
  # FORM_ATTRIBUTES per Administrate convention.
  describe "Phase 2 dashboards" do
    ADMIN_PHASE_TWO_DASHBOARD_TABLE.each do |basename, dashboard_class, model_class|
      describe dashboard_class do
        let(:dashboard_path)  { "engines/admin/app/dashboards/admin/#{basename}_dashboard.rb" }
        # ActiveSupport's String#pluralize handles the irregular cases
        # ("identity" -> "identities", "lifetime_pass" -> "lifetime_passes")
        # so the spec doesn't need a per-name lookup table.
        let(:plural)          { basename.pluralize }
        let(:controller_path) { "engines/admin/app/controllers/admin/#{plural}_controller.rb" }
        let(:short_dashboard) { dashboard_class.split("::").last }

        it "creates the dashboard file and subclasses Administrate::BaseDashboard" do
          assert_file dashboard_path do |content|
            expect(content).to include("class #{short_dashboard} < Administrate::BaseDashboard")
            expect(content).to include("ATTRIBUTE_TYPES")
            expect(content).to include("COLLECTION_ATTRIBUTES")
            expect(content).to include("SHOW_PAGE_ATTRIBUTES")
            expect(content).to include("FORM_ATTRIBUTES")
          end
        end

        it "creates the controller file and subclasses Seams::Admin::ApplicationController" do
          assert_file controller_path do |content|
            expect(content).to include("class #{plural.camelize}Controller < ::Seams::Admin::ApplicationController")
            expect(content).to include(model_class)
          end
        end
      end
    end
  end

  describe "Phase 2 routes" do
    let(:routes_path) { "engines/admin/config/routes.rb" }

    ADMIN_PHASE_TWO_ROUTE_PLURALS.each do |plural|
      it "splices a `resources :#{plural}` declaration" do
        assert_file routes_path do |content|
          expect(content).to include("resources :#{plural}")
          expect(content).to include(%(controller: "admin/#{plural}"))
        end
      end
    end

    it "sets the engine root to admin/identities#index" do
      assert_file routes_path do |content|
        expect(content).to include('root to: "admin/identities#index"')
      end
    end
  end

  describe "Phase 2 engine Gemfile" do
    it "appends `gem \"administrate\"` so the engine's standalone specs can require it" do
      assert_file "engines/admin/Gemfile" do |content|
        expect(content).to include('gem "administrate", "~> 1.0"')
      end
    end
  end

  describe "wiring into host" do
    let(:gen_path) do
      File.expand_path("../../../lib/generators/seams/admin/admin_generator.rb", __dir__)
    end

    it "wire_into_host adds administrate ~> 1.0" do
      content = File.read(gen_path)
      expect(content).to include('host_inject_gem("administrate", "~> 1.0")')
    end

    it "wire_into_host adds pundit ~> 2.4" do
      content = File.read(gen_path)
      expect(content).to include('host_inject_gem("pundit",       "~> 2.4")')
        .or include('host_inject_gem("pundit", "~> 2.4")')
    end

    it "wire_into_host mounts Seams::Admin::Engine at /admin" do
      content = File.read(gen_path)
      expect(content).to include('host_inject_mount(engine_class: "Seams::Admin::Engine", at: "/admin")')
    end

    it "the generator includes EjectAware so templates can be skipped after eject" do
      content = File.read(gen_path)
      expect(content).to include("include Seams::Generators::EjectAware")
      expect(content).to include("template_unless_ejected")
    end

    it "the generator includes HostInjector for host-side edits" do
      content = File.read(gen_path)
      expect(content).to include("include Seams::Generators::HostInjector")
    end
  end

  # Wave 10 Phase 2A: every catalogued insertion-point marker the
  # admin engine ships must appear in its target file. Phase 1 ships
  # five markers; the catalogue (doc/INSERTION_POINTS_CATALOGUE.md)
  # is updated alongside this generator.
  describe "insertion-point markers (Wave 10 convention)" do
    {
      "admin.engine.events" => "engines/admin/lib/admin/engine.rb",
      "admin.routes.before_resources" => "engines/admin/config/routes.rb",
      "admin.routes.after_resources" => "engines/admin/config/routes.rb",
      "admin.configuration.attributes" => "engines/admin/lib/admin/configuration.rb",
      "admin.configuration.defaults" => "engines/admin/lib/admin/configuration.rb"
    }.each do |marker, path|
      it "ships #{marker} in #{path}" do
        assert_file path do |content|
          expect(content).to include("# seams:insertion-point #{marker}")
        end
      end
    end
  end

  # Phase 3 — Pundit policies. Two namespaces (Admin::Platform,
  # Admin::Tenant) each shipping an ApplicationPolicy base + one
  # policy per DASHBOARD_MODELS entry.
  describe "Phase 3 Pundit policies" do
    describe "Admin::Platform::ApplicationPolicy" do
      it "creates the platform base policy with the documented predicates", :aggregate_failures do
        assert_file "engines/admin/app/policies/admin/platform/application_policy.rb" do |content|
          expect(content).to include("module Admin")
          expect(content).to include("module Platform")
          expect(content).to include("class ApplicationPolicy")
          %w[index? show? new? create? edit? update? destroy?].each do |predicate|
            expect(content).to include("def #{predicate}")
          end
          expect(content).to include("class Scope")
          expect(content).to include("scope.all")
          expect(content).to include("staff?")
        end
      end
    end

    describe "Admin::Tenant::ApplicationPolicy" do
      it "creates the tenant base policy with the documented predicates", :aggregate_failures do
        assert_file "engines/admin/app/policies/admin/tenant/application_policy.rb" do |content|
          expect(content).to include("module Admin")
          expect(content).to include("module Tenant")
          expect(content).to include("class ApplicationPolicy")
          %w[index? show? new? create? edit? update? destroy?].each do |predicate|
            expect(content).to include("def #{predicate}")
          end
          expect(content).to include("class Scope")
          expect(content).to include("scope.none")
          expect(content).to include("permitted?")
          # Phase 3: tenant policies resolve through the gem's
          # permission registry, not a hardcoded role literal. The
          # shared resolver defers to Seams::Permissions.can? with the
          # membership role; the role == "admin" literal must be gone.
          expect(content).to include("permission_ability")
          expect(content).to include("Seams::Permissions.can?")
          expect(content).not_to match(/%w\[owner admin\]\.include\?/)
          # Phase 4: per-record tenant guard — show?/update?/destroy?
          # also assert the record's own account_id matches the
          # caller's account_id, so a tenant-admin can't load
          # `/admin/accounts/<other_id>` via id-tampering.
          expect(content).to include("record_in_tenant_scope?")
        end
      end

      it "the Scope helper detects whether the model carries an account_id column" do
        assert_file "engines/admin/app/policies/admin/tenant/application_policy.rb" do |content|
          # Phase 4: tenant policies that filter by `account_id` first
          # check the column exists. Without the guard a host whose
          # schema differs from the canonical seams shape would crash
          # with `PG::UndefinedColumn` instead of getting
          # `scope.none`. The helper lives on Scope itself so all
          # subclasses share the check.
          expect(content).to include("account_id_column_present?")
        end
      end
    end

    ADMIN_PHASE_THREE_POLICY_TABLE.each do |basename, platform_class, tenant_class|
      describe platform_class do
        it "creates the platform policy file inheriting from Admin::Platform::ApplicationPolicy" do
          assert_file "engines/admin/app/policies/admin/platform/#{basename}_policy.rb" do |content|
            short = platform_class.split("::").last
            expect(content).to include("module Admin")
            expect(content).to include("module Platform")
            expect(content).to include("class #{short} < ApplicationPolicy")
          end
        end
      end

      describe tenant_class do
        it "creates the tenant policy file inheriting from Admin::Tenant::ApplicationPolicy" do
          assert_file "engines/admin/app/policies/admin/tenant/#{basename}_policy.rb" do |content|
            short = tenant_class.split("::").last
            expect(content).to include("module Admin")
            expect(content).to include("module Tenant")
            expect(content).to include("class #{short} < ApplicationPolicy")
          end
        end
      end
    end

    describe "Admin::Tenant::AccountPolicy::Scope" do
      it "filters by id (tenant Account is identified by id, not account_id)" do
        assert_file "engines/admin/app/policies/admin/tenant/account_policy.rb" do |content|
          expect(content).to include("class Scope")
          expect(content).to include("where(id: account_id)")
        end
      end
    end

    describe "Admin::Tenant::IdentityPolicy::Scope" do
      it "filters via subquery on accounts_memberships (Identity has no :memberships association in canonical seams)" do
        # The previous shape relied on `joins(:memberships)`, which
        # required `Auth::Identity` to declare
        # `has_many :memberships, class_name: "Accounts::Membership"`.
        # The canonical seams `Auth::Identity` does NOT declare that
        # association (the auth engine deliberately doesn't reach
        # across the engine boundary), so a join-form policy raised
        # `ActiveRecord::ConfigurationError` on a fresh install. The
        # subquery form below works against the schema alone.
        assert_file "engines/admin/app/policies/admin/tenant/identity_policy.rb" do |content|
          expect(content).to include("Accounts::Membership")
          expect(content).to include("where(account_id: account_id)")
          expect(content).to include("select(:identity_id)")
          expect(content).not_to include("joins(:memberships)")
        end
      end
    end

    describe "tenant policies that filter by account_id" do
      %w[
        accounts_membership
        team
        teams_membership
        invitation
        notification
        notification_preference
        subscription
        invoice
        lifetime_pass
      ].each do |basename|
        it "Admin::Tenant::#{basename.camelize}Policy::Scope filters by account_id" do
          assert_file "engines/admin/app/policies/admin/tenant/#{basename}_policy.rb" do |content|
            expect(content).to include("where(account_id: account_id)")
          end
        end
      end
    end

    # Phase 3 — each tenant policy names the owning engine's ability
    # code so the shared resolver (`permitted_to?`) can decide via
    # Seams::Permissions.can?. The mapping is the single point where a
    # dashboard resource is bound to a registered ability; it must
    # stay in lock-step with the engine catalogs + DEFAULT_GRANTS.
    describe "tenant policies bind each resource to a registered ability code" do
      {
        "identity" => "identity.manage.auth",
        "account" => "account.manage.accounts",
        "accounts_membership" => "membership.manage.accounts",
        "team" => "team.manage.teams",
        "teams_membership" => "member.manage.teams",
        "invitation" => "invitation.manage.teams",
        "notification" => "notification.manage.notifications",
        "notification_preference" => "preference.manage.notifications",
        "plan" => "plan.manage.billing",
        "subscription" => "subscription.manage.billing",
        "invoice" => "invoice.manage.billing",
        "lifetime_pass" => "lifetime.manage.billing"
      }.each do |basename, ability|
        it "Admin::Tenant::#{basename.camelize}Policy resolves through #{ability}" do
          assert_file "engines/admin/app/policies/admin/tenant/#{basename}_policy.rb" do |content|
            expect(content).to include("def permission_ability")
            expect(content).to include(%("#{ability}"))
          end
        end
      end
    end

    describe "Admin::Tenant::PlanPolicy" do
      it "treats Plan as a global catalogue (Scope returns scope.all)" do
        assert_file "engines/admin/app/policies/admin/tenant/plan_policy.rb" do |content|
          expect(content).to include("scope.all")
          # Writes still gated on staff? — tenant admins should not
          # mutate the global plan catalogue.
          expect(content).to include("def create?")
          expect(content).to include("staff?")
        end
      end
    end

    describe "Seams::Admin::Context" do
      it "ships the pundit_user wrapper Struct", :aggregate_failures do
        assert_file "engines/admin/lib/admin/context.rb" do |content|
          expect(content).to include("module Seams")
          expect(content).to include("module Admin")
          expect(content).to include("Context = Struct.new(:identity, :membership)")
          expect(content).to include("def staff?")
          expect(content).to include("def role")
          expect(content).to include("def account_id")
        end
      end

      it "is required from lib/admin.rb" do
        assert_file "engines/admin/lib/admin.rb" do |content|
          expect(content).to include('require "admin/context"')
        end
      end
    end
  end

  describe "Phase 3 ApplicationController" do
    let(:controller_path) { "engines/admin/app/controllers/seams/admin/application_controller.rb" }

    it "includes Administrate::Punditize (the canonical Pundit integration)" do
      # `Administrate::Punditize` is the thoughtbot-shipped concern that
      # wires Pundit into Administrate's `authorized_action?` and
      # `scoped_resource` hooks. Without it, defining policies has no
      # effect — Administrate's default `authorized_action?` returns
      # true unconditionally. Punditize itself includes
      # `Pundit::Authorization`, so the policy DSL is still available.
      assert_file controller_path do |content|
        expect(content).to include("include ::Administrate::Punditize")
      end
    end

    it "defines a pundit_user method returning a Seams::Admin::Context" do
      assert_file controller_path do |content|
        expect(content).to include("def pundit_user")
        expect(content).to include("Seams::Admin::Context.new")
        expect(content).to include("Auth::Current")
      end
    end

    it "defines a policy_namespace method that switches on tenancy_scope" do
      assert_file controller_path do |content|
        expect(content).to include("def policy_namespace")
        expect(content).to include("Seams::Admin.config.tenancy_scope")
        expect(content).to include("Admin::Platform")
        expect(content).to include("Admin::Tenant")
      end
    end

    it "wires the audit-log auto-write as an after_action" do
      assert_file controller_path do |content|
        expect(content).to include("after_action :record_admin_audit")
        expect(content).to include("only: %i[create update destroy]")
        expect(content).to include("def record_admin_audit")
        expect(content).to include("Core::AuditLog")
        expect(content).to include("requested_resource")
      end
    end

    it "guards the audit-log path on Core::AuditLog being defined" do
      assert_file controller_path do |content|
        expect(content).to include("defined?(::Core::AuditLog)")
      end
    end

    it "rescue_from Pundit::NotAuthorizedError so policy denials render 403" do
      # Pundit raises `NotAuthorizedError` from inside its
      # `authorize` call; without an explicit rescue the host
      # Rails app inherits the exception and renders a 500. Pin
      # the rescue_from down so this never regresses.
      assert_file controller_path do |content|
        expect(content).to include("rescue_from ::Pundit::NotAuthorizedError")
        expect(content).to include("respond_with_admin_unauthorised")
      end
    end

    it "wires verify_authorized + verify_policy_scoped after_actions" do
      # Pundit's standard recommendation: catch any future controller
      # action that forgets `authorize` / `policy_scope`. Administrate's
      # standard actions all call them, so this is purely a safety net
      # for subclasses that add custom actions.
      assert_file controller_path do |content|
        expect(content).to include("after_action :verify_authorized")
        expect(content).to include("after_action :verify_policy_scoped")
      end
    end

    it "delegates membership resolution to a configurable resolver" do
      # `current_membership_for_admin` calls
      # `Seams::Admin.config.current_membership_resolver` so hosts
      # using a non-canonical membership shape can override without
      # ejecting the controller.
      assert_file controller_path do |content|
        expect(content).to include("current_membership_resolver")
      end
    end

    it "does NOT redefine scoped_resource (Punditize already overrides it)" do
      # Defining `scoped_resource` ourselves shadows Punditize's
      # version, breaking the policy_scope wiring. The override Phase 3
      # originally added is now redundant — Punditize's own
      # `scoped_resource` calls `policy_scope!` with the array-form
      # namespace.
      assert_file controller_path do |content|
        expect(content).not_to include("def scoped_resource")
      end
    end
  end

  describe "Phase 3 generator surface" do
    let(:gen_path) do
      File.expand_path("../../../lib/generators/seams/admin/admin_generator.rb", __dir__)
    end

    it "exposes a create_policies method that templates each platform + tenant policy" do
      content = File.read(gen_path)
      expect(content).to include("def create_policies")
      expect(content).to include("DASHBOARD_MODELS.each")
      expect(content).to include("app/policies/admin/")
      expect(content).to include("platform")
      expect(content).to include("tenant")
    end

    it "exposes a create_context method that templates the pundit_user wrapper" do
      content = File.read(gen_path)
      expect(content).to include("def create_context")
      expect(content).to include("lib/admin/context.rb")
    end

    it "appends gem \"pundit\" to the engine's standalone Gemfile" do
      content = File.read(gen_path)
      expect(content).to include("def append_pundit_to_engine_gemfile")
      assert_file "engines/admin/Gemfile" do |gemfile|
        expect(gemfile).to include('gem "pundit", "~> 2.4"')
      end
    end

    it "writes the Accounts::Current stub for tenant-mode pundit_user" do
      assert_file "engines/admin/spec/dummy/app/models/accounts/current.rb" do |content|
        expect(content).to include("class Current < ActiveSupport::CurrentAttributes")
        expect(content).to include("attribute :membership")
      end
    end

    it "writes a Core::AuditLog stub so the audit-log spec can exercise the path" do
      assert_file "engines/admin/spec/dummy/app/models/core/audit_log.rb" do |content|
        expect(content).to include("module Core")
        expect(content).to include("class AuditLog")
        expect(content).to include('self.table_name = "core_audit_logs"')
      end
    end
  end

  describe "Phase 3 runtime spec assertions" do
    it "asserts Pundit + the policy classes load" do
      assert_file "engines/admin/spec/runtime/admin_boot_spec.rb" do |content|
        expect(content).to include("Pundit::Authorization")
        expect(content).to include("Admin::Platform::IdentityPolicy")
        expect(content).to include("Admin::Tenant::IdentityPolicy")
        expect(content).to include("Admin::Tenant::AccountPolicy::Scope")
        expect(content).to include("Seams::Admin::Context")
      end
    end

    it "asserts the audit-log auto-write fires on update/destroy" do
      assert_file "engines/admin/spec/runtime/admin_boot_spec.rb" do |content|
        expect(content).to include("Core::AuditLog")
        expect(content).to include("record_admin_audit")
        expect(content).to include("change(Core::AuditLog, :count)")
      end
    end
  end

  describe "single-namespace cleanup" do
    # The base EngineGenerator creates Admin::ApplicationController +
    # Admin::ApplicationRecord under app/controllers/admin/ and
    # app/models/admin/. Because the admin engine uses the
    # Seams::Admin two-segment namespace instead, the base files are
    # removed during generation.
    it "removes the leftover Admin::ApplicationController" do
      full = File.join(destination_root, "engines/admin/app/controllers/admin/application_controller.rb")
      expect(File.exist?(full)).to be(false)
    end

    it "removes the leftover Admin::ApplicationRecord" do
      full = File.join(destination_root, "engines/admin/app/models/admin/application_record.rb")
      expect(File.exist?(full)).to be(false)
    end
  end
end
