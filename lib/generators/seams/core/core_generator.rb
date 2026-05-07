# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/dummy_app_writer"

module Seams
  module Generators
    # Generates a canonical Core engine on top of the generic engine
    # scaffold. Ships the seven primitive concerns + AuditLog model
    # other engines lean on:
    #
    #   - Core::Auditable          — records create/update/destroy in audit_logs
    #   - Core::SoftDeletable      — deleted_at column + default_scope
    #   - Core::Sluggable          — auto-generated URL slug from a configurable field
    #   - Core::TenantScoped       — scopes records to Current.team
    #   - Core::HasCurrentAttributes — Current.user / Current.team
    #   - Core::EventPublisher     — convenience wrapper around Seams::Events::Publisher
    #   - Core::EmailFormatValidator — custom validator
    #
    # Run with: bin/rails generate seams:core
    class CoreGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "core"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt", engine_path("lib/core/engine.rb"), force: true
        template "lib/core.rb.tt",   engine_path("lib/core.rb"),        force: true
      end

      def create_models
        template "app/models/application_record.rb.tt",
                 engine_path("app/models/core/application_record.rb")
        template "app/models/audit_log.rb.tt",
                 engine_path("app/models/core/audit_log.rb")
      end

      def create_concerns
        template "app/models/concerns/auditable.rb.tt",
                 engine_path("app/models/concerns/core/auditable.rb")
        template "app/models/concerns/soft_deletable.rb.tt",
                 engine_path("app/models/concerns/core/soft_deletable.rb")
        template "app/models/concerns/sluggable.rb.tt",
                 engine_path("app/models/concerns/core/sluggable.rb")
        template "app/models/concerns/tenant_scoped.rb.tt",
                 engine_path("app/models/concerns/core/tenant_scoped.rb")
        template "app/controllers/concerns/has_current_attributes.rb.tt",
                 engine_path("app/controllers/concerns/core/has_current_attributes.rb")
      end

      def create_services_and_validators
        template "app/services/event_publisher.rb.tt",
                 engine_path("app/services/core/event_publisher.rb")
        template "app/validators/email_format_validator.rb.tt",
                 engine_path("app/validators/core/email_format_validator.rb")
      end

      def create_current
        template "app/models/current.rb.tt",
                 engine_path("app/models/core/current.rb")
      end

      def create_migration
        template "db/migrate/create_core_audit_logs.rb.tt",
                 engine_path("db/migrate/#{timestamp}_create_core_audit_logs.rb")
      end

      def create_specs
        template "spec/models/audit_log_spec.rb.tt",
                 engine_path("spec/models/core/audit_log_spec.rb")
        template "spec/concerns/auditable_spec.rb.tt",
                 engine_path("spec/concerns/core/auditable_spec.rb")
        template "spec/concerns/sluggable_spec.rb.tt",
                 engine_path("spec/concerns/core/sluggable_spec.rb")
        template "spec/validators/email_format_validator_spec.rb.tt",
                 engine_path("spec/validators/core/email_format_validator_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents = File.read(rubocop_path)
        replacement = "  ExposedConcerns:\n    " \
                      "- Core::Auditable\n    " \
                      "- Core::SoftDeletable\n    " \
                      "- Core::Sluggable\n    " \
                      "- Core::TenantScoped\n    " \
                      "- Core::HasCurrentAttributes"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def create_dummy_app
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Core",
          schema: dummy_schema,
          host_user: dummy_host_user
        )
        template "spec/runtime/boot_spec.rb.tt",
                 engine_path("spec/runtime/core_boot_spec.rb")
      end

      def wire_into_host
        host_inject_mount(engine_class: "Core::Engine", at: "/")
      end

      def report_summary
        say ""
        say "  Core engine generated at engines/core/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. bin/rails db:migrate"
        say "    2. Mix concerns into your models as needed:"
        say "         include Core::Auditable, Core::SoftDeletable, Core::Sluggable, etc."
        say "    3. Run the engine specs: bin/rails seams:test[core]"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      def dummy_schema
        <<~SCHEMA
          create_table :core_audit_logs do |t|
            t.string  :action,         null: false
            t.string  :auditable_type
            t.bigint  :auditable_id
            t.bigint  :actor_id
            t.text    :payload,        null: false, default: "{}"
            t.timestamps
          end
          add_index :core_audit_logs, %i[auditable_type auditable_id]

          create_table :articles do |t|
            t.string   :title
            t.string   :slug
            t.datetime :deleted_at
            t.bigint   :team_id
            t.timestamps
          end
          add_index :articles, :slug, unique: true

          create_table :teams do |t|
            t.string :name
            t.string :slug
            t.timestamps
          end
          add_index :teams, :slug, unique: true
        SCHEMA
      end

      def dummy_host_user
        <<~RB
          # frozen_string_literal: true

          # Minimal host User for the engine's spec/dummy app.
          class User < ApplicationRecord
            include Core::Auditable
          end
        RB
      end

      # Core's migration sits AHEAD of the canonical engine offsets
      # (auth +0/+1, notifications +100, billing +200..+202, teams
      # +300..+302) so other engines' tables can reference audit_logs
      # if they ever need to.
      def timestamp
        base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        # Use a NEGATIVE offset (subtract 1000) so core migrates first
        # in the standard ordering. This is safe because timestamps are
        # just sortable strings.
        (base - 1000).to_s
      end
    end
  end
end
