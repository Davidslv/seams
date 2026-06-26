# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "yaml"
require "generators/seams/accounts/accounts_generator"

ACCOUNTS_AUTHORIZATION_NEEDLES = [
  "module Authorization",
  'require "active_support/concern"',
  "before_action :ensure_account_access",
  "def disallow_account_scope",
  "def require_access_without_membership",
  "def ensure_admin",
  "def ensure_staff",
  "def authorize_permission!",
  "def current_permission_role",
  "Seams::Permissions.can?",
  "Accounts::Current.account",
  "Accounts::Current.membership"
].freeze

RSpec.describe Seams::Generators::AccountsGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/accounts_generator", __dir__) }

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

  # Pulled out of the README spec body so the spec example stays
  # under the RSpec/ExampleLength threshold.
  def readme_needles
    %w[
      Accounts
      account.created.accounts
      account.cancelled.accounts
      membership.created.accounts
      membership.role_changed.accounts
      membership.removed.accounts
      Accounts::AccountScoped
      Accounts::Authorization
      system
      owner
      admin
      member
      staff
    ]
  end

  describe "engine entry point" do
    it "registers the five canonical accounts events in the engine initializer" do
      assert_file "engines/accounts/lib/accounts/engine.rb" do |content|
        expect(content).to include('Seams::EventRegistry.register("account.created.accounts"')
        expect(content).to include('Seams::EventRegistry.register("account.cancelled.accounts"')
        expect(content).to include('Seams::EventRegistry.register("membership.created.accounts"')
        expect(content).to include('Seams::EventRegistry.register("membership.role_changed.accounts"')
        expect(content).to include('Seams::EventRegistry.register("membership.removed.accounts"')
      end
    end

    it "registers the accounts ability catalog (resource.action.engine)" do
      assert_file "engines/accounts/lib/accounts/engine.rb" do |content|
        expect(content).to include('initializer "accounts.register_abilities"')
        expect(content).to include('owned_by: "Accounts"')
        %w[
          account.read.accounts account.manage.accounts
          membership.read.accounts membership.manage.accounts
        ].each do |code|
          expect(content).to include(%("#{code}"))
        end
      end
    end

    it "uses isolate_namespace Accounts" do
      assert_file "engines/accounts/lib/accounts/engine.rb" do |content|
        expect(content).to include("isolate_namespace Accounts")
      end
    end

    it "rewrites lib/accounts.rb to expose Accounts.configure" do
      assert_file "engines/accounts/lib/accounts.rb" do |content|
        expect(content).to include("def configure")
        expect(content).to include("def configuration")
        expect(content).to include('require "accounts/concerns/account_scoped"')
        expect(content).to include('require "accounts/concerns/authorization"')
      end
    end
  end

  describe "models" do
    it "creates Accounts::Account with table mapping + UUID PK + create_with_owner", :aggregate_failures do
      assert_file "engines/accounts/app/models/accounts/account.rb" do |content|
        expect(content).to include("class Account < ApplicationRecord")
        expect(content).to include('self.table_name        = "accounts"')
        expect(content).to include("def self.create_with_owner(account:, owner:)")
        expect(content).to include('role:        "system"')
        expect(content).to include('role:        "owner"')
        expect(content).to include("verified_at: Time.current")
      end
    end

    it "Account publishes account.created.accounts on create" do
      assert_file "engines/accounts/app/models/accounts/account.rb" do |content|
        expect(content).to include('"account.created.accounts"')
        expect(content).to include('"account.cancelled.accounts"')
      end
    end

    it "creates Accounts::Membership with role enum + system actor support", :aggregate_failures do
      assert_file "engines/accounts/app/models/accounts/membership.rb" do |content|
        expect(content).to include("class Membership < ApplicationRecord")
        expect(content).to include('self.table_name           = "accounts_memberships"')
        expect(content).to include("ROLES = %w[owner admin member system].freeze")
        expect(content).to include("def admin?")
        expect(content).to include("def system?")
        expect(content).to include("def can_administer?(other)")
        expect(content).to include("def can_change?(other)")
      end
    end

    it "Membership publishes the three lifecycle events" do
      assert_file "engines/accounts/app/models/accounts/membership.rb" do |content|
        expect(content).to include('"membership.created.accounts"')
        expect(content).to include('"membership.role_changed.accounts"')
        expect(content).to include('"membership.removed.accounts"')
      end
    end

    it "creates Accounts::ApplicationRecord as an abstract class" do
      assert_file "engines/accounts/app/models/accounts/application_record.rb" do |content|
        expect(content).to include("self.abstract_class = true")
      end
    end

    it "creates Accounts::Current with :account and :membership attributes" do
      assert_file "engines/accounts/app/models/accounts/current.rb" do |content|
        expect(content).to include("class Current < ActiveSupport::CurrentAttributes")
        expect(content).to include("attribute :account, :membership")
        # Setter cascades from account= to derive membership from
        # the current Auth::Identity.
        expect(content).to include("def account=(value)")
        expect(content).to include("Auth::Current.identity")
      end
    end
  end

  describe "concerns" do
    it "creates Accounts::AccountScoped with belongs_to :account + default_scope + presence validation" do
      assert_file "engines/accounts/lib/accounts/concerns/account_scoped.rb" do |content|
        [
          "module AccountScoped",
          'require "active_support/concern"',
          'belongs_to :account, class_name: "Accounts::Account"',
          "default_scope",
          "Accounts::Current.account",
          "validates :account, presence: true",
          "before_validation :assign_current_account"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "creates Accounts::Authorization with the default-on access check + opt-out helpers" do
      assert_file "engines/accounts/lib/accounts/concerns/authorization.rb" do |content|
        ACCOUNTS_AUTHORIZATION_NEEDLES.each { |needle| expect(content).to include(needle) }
      end
    end

    it "registers both concerns in ExposedConcerns" do
      assert_file "engines/accounts/.rubocop.yml" do |content|
        expect(content).to include("Accounts::AccountScoped")
        expect(content).to include("Accounts::Authorization")
      end
    end
  end

  describe "configuration" do
    it "creates Accounts::Configuration with the documented knobs" do
      assert_file "engines/accounts/lib/accounts/configuration.rb" do |content|
        expect(content).to include("attr_accessor")
        expect(content).to include("incineration_grace_period")
        expect(content).to include("after_account_create_url")
      end
    end
  end

  describe "migrations" do
    it "creates the accounts migration with UUID PK + comment block + cancelled_at", :aggregate_failures do
      pattern = File.join(destination_root, "engines/accounts/db/migrate", "*_create_accounts.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("# What:")
      expect(content).to include("# Why:")
      expect(content).to include("create_table :accounts, id: :uuid")
      expect(content).to include("enable_extension \"pgcrypto\"")
      expect(content).to include(":external_account_id")
      expect(content).to include(":cancelled_at")
      expect(content).to include(":incinerated_at")
    end

    it "creates the accounts_memberships migration with FK + nullable identity_id + indexes", :aggregate_failures do
      pattern = File.join(destination_root, "engines/accounts/db/migrate", "*_create_accounts_memberships.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("# What:")
      expect(content).to include("create_table :accounts_memberships, id: :uuid")
      expect(content).to include("foreign_key: { to_table: :accounts }")
      # bigint to match auth_identities' default integer PK; same
      # convention every other engine (billing, teams) follows.
      expect(content).to include("t.bigint     :identity_id,  null: true")
      expect(content).to include(":role")
      expect(content).to include('default: "member"')
      expect(content).to include("add_index :accounts_memberships, %i[account_id identity_id], unique: true")
      expect(content).to include("add_index :accounts_memberships, %i[account_id role]")
    end
  end

  describe "routes" do
    it "mounts the memberships role-picker resource (index + update)" do
      assert_file "engines/accounts/config/routes.rb" do |content|
        expect(content).to include("Accounts::Engine.routes.draw do")
        expect(content).to include("resources :memberships, only: %i[index update]")
      end
    end

    it "ships the routes insertion-point markers around the resource" do
      assert_file "engines/accounts/config/routes.rb" do |content|
        expect(content).to include("# seams:insertion-point accounts.routes.before_memberships")
        expect(content).to include("# seams:insertion-point accounts.routes.after_memberships")
      end
    end
  end

  describe "controllers + views (Phase 4)" do
    it "ships the tenant-facing memberships controller guarded by the ability" do
      assert_file "engines/accounts/app/controllers/accounts/memberships_controller.rb" do |content|
        [
          "class MembershipsController < ApplicationController",
          "include Accounts::Authorization",
          'authorize_permission!("membership.manage.accounts")',
          "def index",
          "def update",
          # The three escalation safeguards.
          "if own_membership?(@membership)",
          "if @membership.owner?",
          "unless actor_can_assign?(requested_role)",
          "ASSIGNABLE_ROLES = %w[admin member].freeze"
        ].each { |needle| expect(content).to include(needle) }
        # Scoped to the current account, never global.
        expect(content).to include("Accounts::Current.account.memberships")
      end
    end

    it "ships a design-independent index view (plain ERB, no ui_* helpers)" do
      assert_file "engines/accounts/app/views/accounts/memberships/index.html.erb" do |content|
        expect(content).to include('name="membership[role]"')
        expect(content).to include("assignable_roles.each")
        expect(content).to include("button")
        # MUST NOT hard-depend on the opt-in design engine.
        expect(content).not_to match(/\bui_[a-z_]+/)
      end
    end
  end

  describe "documentation + specs" do
    it "rewrites README with the canonical events table + Identity/Account/Membership rubric" do
      assert_file "engines/accounts/README.md" do |content|
        readme_needles.each { |needle| expect(content).to include(needle) }
      end
    end

    it "creates per-model spec stubs (Account + Membership)" do
      assert_file "engines/accounts/spec/models/accounts/account_spec.rb"
      assert_file "engines/accounts/spec/models/accounts/membership_spec.rb"
    end

    it "ships FactoryBot factories for account, membership, owner_membership, admin_membership, system_membership" do
      assert_file "engines/accounts/spec/factories/accounts.rb" do |content|
        %w[
          account
          membership
          owner_membership
          admin_membership
          system_membership
        ].each { |name| expect(content).to include("factory :#{name}") }
        # Depends on auth_identity from the auth engine's factory file.
        expect(content).to include("factory: :auth_identity")
      end
    end
  end

  describe "runtime spec" do
    it "ships a boot spec that asserts schema + events + create_with_owner" do
      assert_file "engines/accounts/spec/runtime/accounts_boot_spec.rb" do |content|
        [
          "Accounts engine boot",
          "Accounts::Account.create_with_owner",
          "%i[accounts accounts_memberships auth_identities]",
          "Seams::EventRegistry.registered?",
          "account.created.accounts",
          "Accounts::Current"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships the memberships behavioural spec covering the happy path + three safeguards" do
      assert_file "engines/accounts/spec/runtime/accounts_memberships_flow_spec.rb" do |content|
        [
          "Accounts memberships role picker",
          "type: :request",
          "happy path",
          "safeguard 1: the owner role cannot be changed",
          "safeguard 2: a user cannot change their own role",
          "safeguard 3: a user cannot assign a role senior to their own"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships the authorization permission-tiers spec (deny/allow/staff bypass + cross-tenant)" do
      assert_file "engines/accounts/spec/runtime/accounts_authorization_spec.rb" do |content|
        [
          "Accounts::Authorization permission tiers",
          "type: :request",
          "tier 1: deny-by-role",
          "tier 2: allow-by-role",
          "tier 3: staff bypass",
          "cross-tenant isolation: the active membership decides, not the identity"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "dummy app" do
    it "writes a schema that includes auth_identities, accounts, accounts_memberships" do
      assert_file "engines/accounts/spec/dummy/db/schema.rb" do |content|
        [
          "create_table :auth_identities",
          "create_table :accounts, id: :uuid",
          "create_table :accounts_memberships, id: :uuid",
          'enable_extension "pgcrypto"'
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "mounts Accounts::Engine at /accounts in the dummy routes" do
      assert_file "engines/accounts/spec/dummy/config/routes.rb" do |content|
        expect(content).to include('mount Accounts::Engine, at: "/accounts"')
      end
    end

    it "ships an Auth::Identity stub so accounts specs can build an owner" do
      # Wave 9: accounts specs reference Auth::Identity directly (a
      # Membership without an Identity to point at is meaningless).
      # The engine ships a slim stub the same way notifications does.
      assert_file "engines/accounts/spec/dummy/app/models/auth/identity.rb" do |content|
        expect(content).to include("class Identity < ApplicationRecord")
        expect(content).to include('self.table_name = "auth_identities"')
        expect(content).to include("has_secure_password")
      end
    end

    it "ships an Auth::Current stub so accounts specs can wire Current.identity" do
      assert_file "engines/accounts/spec/dummy/app/models/auth/current.rb" do |content|
        expect(content).to include("class Current < ActiveSupport::CurrentAttributes")
        expect(content).to include("attribute :identity")
      end
    end
  end

  describe "wiring into host" do
    let(:gen_path) do
      File.expand_path("../../../lib/generators/seams/accounts/accounts_generator.rb", __dir__)
    end

    it "wire_into_host adds factory_bot_rails to the test group" do
      content = File.read(gen_path)
      expect(content).to include('host_inject_gem("factory_bot_rails"')
      expect(content).to include("group: :test")
    end

    it "wire_into_host mounts Accounts::Engine but does NOT include in host User" do
      content = File.read(gen_path)
      expect(content).to include('host_inject_mount(engine_class: "Accounts::Engine", at: "/accounts")')
      # No actual call to host_inject_include_in_user — only a
      # documenting comment referencing the helper by name.
      expect(content).not_to match(/^\s*host_inject_include_in_user\(/)
    end
  end

  # Wave 10 Phase 2A: every catalogued insertion-point marker the
  # accounts engine ships must appear in its target file. These
  # assertions gate against accidental marker removal in future
  # template edits. See doc/INSERTION_POINTS_CATALOGUE.md for the
  # canonical list.
  describe "insertion-point markers (Wave 10)" do
    {
      "accounts.engine.events" => "engines/accounts/lib/accounts/engine.rb",
      "accounts.engine.abilities" => "engines/accounts/lib/accounts/engine.rb",
      "accounts.engine.initializers" => "engines/accounts/lib/accounts/engine.rb",
      "accounts.configuration.attributes" => "engines/accounts/lib/accounts/configuration.rb",
      "accounts.configuration.defaults" => "engines/accounts/lib/accounts/configuration.rb"
    }.each do |marker, path|
      it "ships #{marker} in #{path}" do
        assert_file path do |content|
          expect(content).to include("# seams:insertion-point #{marker}")
        end
      end
    end
  end
end
