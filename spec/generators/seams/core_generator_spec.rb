# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/core/core_generator"

RSpec.describe Seams::Generators::CoreGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/core_generator", __dir__) }

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
    it "registers record.audited.core in the engine initializer" do
      assert_file "engines/core/lib/core/engine.rb" do |content|
        expect(content).to include('"record.audited.core"')
        expect(content).to include("isolate_namespace Core")
      end
    end
  end

  describe "models" do
    it "creates Core::AuditLog with polymorphic auditable + ACTIONS" do
      assert_file "engines/core/app/models/core/audit_log.rb" do |content|
        expect(content).to include("class AuditLog < ApplicationRecord")
        expect(content).to include("polymorphic: true")
        expect(content).to include("ACTIONS")
      end
    end

    it "creates Core::Current with user / team / request_id" do
      assert_file "engines/core/app/models/core/current.rb" do |content|
        expect(content).to include("ActiveSupport::CurrentAttributes")
        expect(content).to include("attribute :user, :team, :request_id")
      end
    end
  end

  describe "concerns" do
    it "creates Core::Auditable with after_commit hooks (not after_create / after_update / after_destroy)" do
      assert_file "engines/core/app/models/concerns/core/auditable.rb" do |content|
        expect(content).to include("after_commit :record_audit_create,  on: :create")
        expect(content).to include("after_commit :record_audit_update,  on: :update")
        expect(content).to include("after_commit :record_audit_destroy, on: :destroy")
      end
    end

    it "creates Core::SoftDeletable with deleted_at default scope" do
      assert_file "engines/core/app/models/concerns/core/soft_deletable.rb" do |content|
        expect(content).to include("default_scope")
        expect(content).to include("def soft_delete!")
        expect(content).to include("scope :with_deleted")
      end
    end

    it "creates Core::Sluggable with collision suffixing" do
      assert_file "engines/core/app/models/concerns/core/sluggable.rb" do |content|
        expect(content).to include("def sluggable_from")
        expect(content).to include("counter += 1")
      end
    end

    it "creates Core::TenantScoped that auto-fills team_id from Current.team" do
      assert_file "engines/core/app/models/concerns/core/tenant_scoped.rb" do |content|
        expect(content).to include("Core::Current.team")
        expect(content).to include("default_scope")
      end
    end

    it "creates Core::HasCurrentAttributes for ApplicationController" do
      assert_file "engines/core/app/controllers/concerns/core/has_current_attributes.rb" do |content|
        expect(content).to include("before_action :populate_current_attributes")
        expect(content).to include("Core::Current.user")
      end
    end
  end

  describe "services + validators" do
    it "creates Core::EventPublisher that enriches the payload" do
      assert_file "engines/core/app/services/core/event_publisher.rb" do |content|
        expect(content).to include("module_function")
        expect(content).to include("actor_id")
        expect(content).to include("Seams::Events::Publisher.publish")
      end
    end

    it "creates Core::EmailFormatValidator extending ActiveModel::EachValidator" do
      assert_file "engines/core/app/validators/core/email_format_validator.rb" do |content|
        expect(content).to include("class EmailFormatValidator < ActiveModel::EachValidator")
        expect(content).to include("def validate_each")
      end
    end
  end

  describe "exposed concerns" do
    it "registers all five concerns in ExposedConcerns" do
      assert_file "engines/core/.rubocop.yml" do |content|
        expect(content).to include("Core::Auditable")
        expect(content).to include("Core::SoftDeletable")
        expect(content).to include("Core::Sluggable")
        expect(content).to include("Core::TenantScoped")
        expect(content).to include("Core::HasCurrentAttributes")
      end
    end
  end

  describe "migration" do
    it "creates core_audit_logs migration with What/Why/Risk block" do
      pattern = File.join(destination_root, "engines/core/db/migrate", "*_create_core_audit_logs.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("# What:")
      expect(content).to include("create_table :core_audit_logs")
      expect(content).to include("auditable_type")
      expect(content).to include("auditable_id")
    end
  end

  describe "specs" do
    it "creates audit_log + concerns + validator spec stubs" do
      assert_file "engines/core/spec/models/core/audit_log_spec.rb"
      assert_file "engines/core/spec/concerns/core/auditable_spec.rb"
      assert_file "engines/core/spec/concerns/core/sluggable_spec.rb"
      assert_file "engines/core/spec/validators/core/email_format_validator_spec.rb"
    end

    it "ships a dummy app + runtime boot spec" do
      assert_file "engines/core/spec/dummy/config/application.rb" do |content|
        expect(content).to include('require "core"')
      end
      assert_file "engines/core/spec/dummy/db/schema.rb" do |content|
        expect(content).to include("create_table :core_audit_logs")
      end
      assert_file "engines/core/spec/dummy/app/models/user.rb" do |content|
        expect(content).to include("include Core::Auditable")
      end
      assert_file "engines/core/spec/rails_helper.rb"
      assert_file "engines/core/spec/runtime/core_boot_spec.rb"
    end
  end

  describe "documentation" do
    it "rewrites README.md with the events + concerns tables" do
      assert_file "engines/core/README.md" do |content|
        expect(content).to include("record.audited.core")
        expect(content).to include("Core::Auditable")
        expect(content).to include("Core::TenantScoped")
      end
    end
  end
end
