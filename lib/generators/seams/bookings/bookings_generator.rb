# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/eject_aware"
require "seams/generators/dummy_app_writer"

module Seams
  module Generators
    # Generates the Bookings engine on top of the generic engine
    # scaffold: an operator defines an offering and dated occurrences
    # with a fixed number of identical places, and a signed-in guest
    # holds places. The occurrence row is the lock, so two concurrent
    # holds cannot exceed capacity.
    #
    # Requires the core and auth engines. The guest is an Auth::Identity
    # referenced by id only. Payment is a later release: nothing here
    # names a Billing constant.
    #
    # Run with: bin/rails generate seams:bookings
    # rubocop:disable-next Metrics/ClassLength
    class BookingsGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector
      include Seams::Generators::EjectAware

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME      = "bookings"
      REQUIRED_ENGINES = { "core" => "bin/seams core", "auth" => "bin/seams auth" }.freeze

      # Bookings joins the guest by identity_id and leans on core's
      # conventions; refuse to write an engine that cannot boot.
      def check_dependencies
        missing = REQUIRED_ENGINES.reject do |name, _command|
          Dir.exist?(File.join(destination_root, "engines", name))
        end
        return if missing.empty?

        raise Seams::GeneratorError,
              "seams:bookings requires the #{missing.keys.join(" and ")} engine(s). Run " \
              "#{missing.values.join(" then ")} first, then re-run bin/seams bookings."
      end

      def create_base_engine
        # The host wiring (mount + initializer) is done below so the
        # initializer documents hold_ttl instead of the generic stub.
        EngineGenerator.start([ENGINE_NAME, "--skip-host-wiring"], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        # engine.rb / lib/bookings.rb stay framework-managed.
        template "lib/engine.rb.tt",   engine_path("lib/bookings/engine.rb"), force: true
        template "lib/bookings.rb.tt", engine_path("lib/bookings.rb"),        force: true
        template_unless_ejected "lib/configuration.rb.tt",
                                engine_path("lib/bookings/configuration.rb")
      end

      def overwrite_routes
        template_unless_ejected "config/routes.rb.tt", engine_path("config/routes.rb"), force: true
      end

      def create_models
        # The base scaffold already wrote an ApplicationRecord with a
        # different body; force so Thor never stops on a conflict prompt.
        template_unless_ejected "app/models/application_record.rb.tt",
                                engine_path("app/models/bookings/application_record.rb"), force: true
        template_unless_ejected "app/models/offering.rb.tt",
                                engine_path("app/models/bookings/offering.rb")
        template_unless_ejected "app/models/occurrence.rb.tt",
                                engine_path("app/models/bookings/occurrence.rb")
        template_unless_ejected "app/models/booking.rb.tt",
                                engine_path("app/models/bookings/booking.rb")
        template_unless_ejected "app/models/instalment.rb.tt",
                                engine_path("app/models/bookings/instalment.rb")
      end

      def create_services
        template_unless_ejected "app/services/service_result.rb.tt",
                                engine_path("app/services/bookings/service_result.rb")
        template_unless_ejected "app/services/hold_service.rb.tt",
                                engine_path("app/services/bookings/hold_service.rb")
        template_unless_ejected "app/services/instalments/mark_paid_service.rb.tt",
                                engine_path("app/services/bookings/instalments/mark_paid_service.rb")
      end

      def create_jobs
        template_unless_ejected "app/jobs/application_job.rb.tt",
                                engine_path("app/jobs/bookings/application_job.rb")
        template_unless_ejected "app/jobs/hold_sweep_job.rb.tt",
                                engine_path("app/jobs/bookings/hold_sweep_job.rb")
      end

      def create_migrations
        template "db/migrate/create_booking_offerings.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_booking_offerings.rb")
        template "db/migrate/create_booking_occurrences.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_booking_occurrences.rb")
        template "db/migrate/create_bookings.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_create_bookings.rb")
        template "db/migrate/create_booking_instalments.rb.tt",
                 engine_path("db/migrate/#{timestamp(3)}_create_booking_instalments.rb")
      end

      def create_specs
        template_unless_ejected "spec/factories/bookings.rb.tt",
                                engine_path("spec/factories/bookings.rb")
        %w[offering occurrence booking instalment].each do |model|
          template_unless_ejected "spec/models/#{model}_spec.rb.tt",
                                  engine_path("spec/models/bookings/#{model}_spec.rb")
        end
        template_unless_ejected "spec/services/hold_service_spec.rb.tt",
                                engine_path("spec/services/bookings/hold_service_spec.rb")
        template_unless_ejected "spec/services/instalments/mark_paid_service_spec.rb.tt",
                                engine_path("spec/services/bookings/instalments/mark_paid_service_spec.rb")
        template_unless_ejected "spec/jobs/hold_sweep_job_spec.rb.tt",
                                engine_path("spec/jobs/bookings/hold_sweep_job_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      # RSpec example groups are long by nature; the gem's own config
      # makes the same exception for its specs.
      def exclude_specs_from_block_length
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        File.open(rubocop_path, "a") do |f|
          f.puts
          f.puts "Metrics/BlockLength:"
          f.puts "  Exclude:"
          f.puts '    - "spec/**/*"'
        end
      end

      def create_dummy_app
        # No host User. The dummy ships a slim Auth::Identity stub at
        # app/models/auth/identity.rb so the boot-time dependency
        # assertion (defined? ::Auth::Identity) passes without the full
        # auth engine, and so specs can create a real guest row when
        # they want one.
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Bookings",
          mount_at: "/bookings",
          schema: dummy_schema,
          host_user: dummy_host_identity,
          host_user_path: "app/models/auth/identity.rb"
        )
        template "spec/runtime/boot_spec.rb.tt",
                 engine_path("spec/runtime/bookings_boot_spec.rb")
      end

      def wire_into_host
        # factory_bot_rails powers spec/factories/bookings.rb. Test group only.
        host_inject_gem("factory_bot_rails", "~> 6.4", group: :test)
        host_inject_mount(engine_class: "Bookings::Engine", at: "/bookings")
        write_host_initializer
      end

      def report_summary
        say ""
        say "  Bookings engine generated at engines/bookings/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. bundle install   (picks up factory_bot_rails for the engine specs)"
        say "    2. bin/rails db:migrate"
        say "    3. Set hold_ttl in config/initializers/bookings.rb (default 30 minutes)"
        say "    4. Schedule Bookings::HoldSweepJob every minute (see engines/bookings/README.md)"
        say "    5. Run the engine specs: bin/rails seams:test[bookings]"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      # Only on first run: a host that has edited its initializer keeps it.
      def write_host_initializer
        initializer = File.join(destination_root, "config/initializers/bookings.rb")
        if File.exist?(initializer)
          say "  exist   config/initializers/bookings.rb (kept)", :blue
        elsif File.directory?(File.dirname(initializer))
          template "host_initializer.rb.tt", "config/initializers/bookings.rb"
        end
      end

      # Offset by 400 to avoid collisions with the other canonical
      # engines (auth +0/+1, accounts +50, notifications +100,
      # billing +200.., teams +300..).
      def timestamp(offset)
        base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        (base + 400 + offset).to_s
      end

      # Slim Auth::Identity stub for the dummy app. Matches the auth
      # engine's table so a spec that wants a real guest row can
      # create one; Bookings itself only ever stores the id.
      def dummy_host_identity
        <<~RB
          # frozen_string_literal: true
          module Auth
            class Identity < ApplicationRecord
              self.table_name = "auth_identities"
              has_secure_password
            end
          end
        RB
      end

      # Mirrors the four migrations plus the auth_identities table the
      # stub above reads. No database foreign key from bookings to
      # auth_identities, in the dummy or in the host.
      def dummy_schema
        <<~SCHEMA
          create_table :auth_identities do |t|
            t.text    :email,            null: false
            t.string  :password_digest,  null: false
            t.boolean :staff,            null: false, default: false
            t.timestamps
          end
          add_index :auth_identities, :email, unique: true

          create_table :booking_offerings do |t|
            t.string :name,         null: false
            t.string :slug,         null: false
            t.string :kind,         null: false
            t.string :confirmation, null: false, default: "automatic"
            t.string :status,       null: false, default: "draft"
            t.timestamps
          end
          add_index :booking_offerings, :slug, unique: true

          create_table :booking_occurrences do |t|
            t.references :offering,      null: false
            t.datetime   :starts_at,     null: false
            t.datetime   :ends_at,       null: false
            t.integer    :capacity,      null: false
            t.integer    :price_cents,   null: false
            t.integer    :deposit_cents
            t.string     :currency,      null: false, default: "gbp"
            t.jsonb      :details,       null: false, default: {}
            t.string     :status,        null: false, default: "draft"
            t.timestamps
          end
          add_index :booking_occurrences, %i[status starts_at]

          create_table :bookings do |t|
            t.bigint     :identity_id,   null: false
            t.references :occurrence,    null: false, index: false
            t.integer    :quantity,      null: false, default: 1
            t.string     :status,        null: false, default: "held"
            t.datetime   :expires_at
            t.string     :reference,     null: false
            t.text       :reason
            t.string     :customer_ref
            t.timestamps
          end
          add_index :bookings, :reference, unique: true
          add_index :bookings, :identity_id
          add_index :bookings, %i[occurrence_id status]
          add_index :bookings, %i[status expires_at]

          create_table :booking_instalments do |t|
            t.references :booking,       null: false
            t.string     :kind,          null: false
            t.integer    :amount_cents,  null: false
            t.date       :due_on,        null: false
            t.string     :state,         null: false, default: "due"
            t.string     :payable_ref,   null: false
            t.string     :checkout_url
            t.datetime   :paid_at
            t.timestamps
          end
          add_index :booking_instalments, :payable_ref, unique: true
        SCHEMA
      end
    end
  end
end
