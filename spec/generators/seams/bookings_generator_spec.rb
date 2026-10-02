# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/bookings/bookings_generator"

BOOKINGS_REGISTERED_EVENTS = %w[
  occurrence.published.bookings
  booking.held.bookings
  booking.hold_expiring.bookings
  booking.balance_due.bookings
  booking.confirmed.bookings
  booking.rejected.bookings
  booking.cancelled.bookings
].freeze

BOOKINGS_ABILITIES = %w[
  offering.manage.bookings
  occurrence.manage.bookings
  booking.read.bookings
  booking.manage.bookings
].freeze

BOOKINGS_INSERTION_MARKERS = {
  "bookings.engine.events" => "engines/bookings/lib/bookings/engine.rb",
  "bookings.engine.abilities" => "engines/bookings/lib/bookings/engine.rb",
  "bookings.engine.initializers" => "engines/bookings/lib/bookings/engine.rb",
  "bookings.routes" => "engines/bookings/config/routes.rb",
  "bookings.configuration.attributes" => "engines/bookings/lib/bookings/configuration.rb"
}.freeze

RSpec.describe Seams::Generators::BookingsGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/bookings_generator", __dir__) }

  def prepare_destination(engines: %w[core auth])
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
    engines.each { |name| FileUtils.mkdir_p(File.join(destination_root, "engines", name)) }
    File.write(File.join(destination_root, "Gemfile"), "source \"https://rubygems.org\"\n")
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
  end

  def run_generator
    described_class.start([], destination_root: destination_root)
  end

  def assert_file(path)
    full = File.join(destination_root, path)
    expect(File.exist?(full)).to be(true), "expected #{path} to be created"
    yield(File.read(full)) if block_given?
  end

  # Executable lines only: comments may name a concept ("Billing
  # listens") to explain why the code does not reference it.
  def code_of(content)
    content.lines.reject { |line| line.lstrip.start_with?("#") }.join
  end

  def migration_matching(slug)
    pattern = File.join(destination_root, "engines/bookings/db/migrate", "*_#{slug}.rb")
    file    = Dir[pattern].first
    expect(file).not_to be_nil, "expected migration matching *_#{slug}.rb"
    File.read(file)
  end

  describe "dependency check" do
    it "refuses to run on a host without the auth engine" do
      prepare_destination(engines: %w[core])
      expect { run_generator }.to raise_error(Seams::GeneratorError, %r{bin/seams auth})
    end

    it "refuses to run on a host without the core engine" do
      prepare_destination(engines: %w[auth])
      expect { run_generator }.to raise_error(Seams::GeneratorError, %r{bin/seams core})
    end
  end

  context "with core and auth present" do
    before do
      prepare_destination
      run_generator
    end

    describe "engine entry point" do
      it "registers the seven bookings events" do
        assert_file "engines/bookings/lib/bookings/engine.rb" do |content|
          BOOKINGS_REGISTERED_EVENTS.each do |event|
            expect(content).to include("Seams::EventRegistry.register(\"#{event}\"")
          end
        end
      end

      it "registers the bookings ability catalogue" do
        assert_file "engines/bookings/lib/bookings/engine.rb" do |content|
          expect(content).to include('initializer "bookings.register_abilities"')
          BOOKINGS_ABILITIES.each { |code| expect(content).to include(%("#{code}")) }
        end
      end

      it "asserts Auth::Identity at boot so a host without auth fails loud" do
        assert_file "engines/bookings/lib/bookings/engine.rb" do |content|
          expect(content).to include("defined?(::Auth::Identity)")
          expect(content).to include("bin/rails generate seams:auth")
        end
      end

      it "appends the engine migrations to the host" do
        assert_file "engines/bookings/lib/bookings/engine.rb" do |content|
          expect(content).to include('initializer "bookings.append_migrations"')
        end
      end

      it "defines the engine error classes" do
        assert_file "engines/bookings/lib/bookings.rb" do |content|
          expect(content).to include("class Error               < StandardError; end")
          expect(content).to include("class ConfigurationError  < Error; end")
        end
      end
    end

    describe "configuration" do
      it "defaults hold_ttl to 30 minutes" do
        assert_file "engines/bookings/lib/bookings/configuration.rb" do |content|
          expect(content).to include("DEFAULT_HOLD_TTL = 30 * 60")
          expect(content).to include("@hold_ttl = DEFAULT_HOLD_TTL")
        end
      end

      it "refuses a hold_ttl above 24 hours" do
        assert_file "engines/bookings/lib/bookings/configuration.rb" do |content|
          expect(content).to include("MAX_HOLD_TTL     = 24 * 60 * 60")
          expect(content).to include("def hold_ttl=(value)")
          expect(content).to include("raise Bookings::ConfigurationError")
        end
      end

      it "writes a host initializer documenting hold_ttl" do
        assert_file "config/initializers/bookings.rb" do |content|
          expect(content).to include("Bookings.configure do |config|")
          expect(content).to include("config.hold_ttl")
          expect(content).to include("24 hours")
        end
      end
    end

    describe "models" do
      it "creates Bookings::Offering with confirmation + status + slug" do
        assert_file "engines/bookings/app/models/bookings/offering.rb" do |content|
          expect(content).to include("CONFIRMATIONS = %w[automatic manual].freeze")
          expect(content).to include("STATUSES      = %w[draft published].freeze")
          expect(content).to include("has_many :occurrences")
          expect(content).to include("def assign_slug")
          expect(content).to include("def manual?")
        end
      end

      it "creates Bookings::Occurrence with the three statuses and the places sum" do
        assert_file "engines/bookings/app/models/bookings/occurrence.rb" do |content|
          expect(content).to include("STATUSES = %w[draft published cancelled].freeze")
          expect(content).to include("def places_taken")
          expect(content).to include("def places_remaining")
          expect(content).to include("def publish!")
          expect(content).to include('"occurrence.published.bookings"')
        end
      end

      it "Bookings::Occurrence refuses a capacity cut below the current sum under the lock" do
        assert_file "engines/bookings/app/models/bookings/occurrence.rb" do |content|
          expect(content).to match(/validate\s+:capacity_covers_places_taken/)
          expect(content).to include("will_save_change_to_capacity?")
          expect(content).to include(".with_lock")
        end
      end

      it "creates Bookings::Booking with the six statuses and the counted set" do
        assert_file "engines/bookings/app/models/bookings/booking.rb" do |content|
          expect(content).to include("STATUSES         = %w[held pending_review confirmed rejected cancelled expired].freeze")
          expect(content).to include("COUNTED_STATUSES = %w[held pending_review confirmed].freeze")
          expect(content).to include("scope :counted")
          expect(content).to include("validates :identity_id, presence: true")
          expect(content).to include("def assign_reference")
        end
      end

      it "Bookings::Booking takes the occurrence lock before it takes a place" do
        assert_file "engines/bookings/app/models/bookings/booking.rb" do |content|
          expect(content).to match(/validate\s+:occurrence_has_capacity/)
          expect(content).to include("will_save_change_to_occurrence_id?")
          expect(content).to include(".with_lock")
          expect(content).to include("Bookings.configuration.hold_ttl")
        end
      end

      it "Bookings::Booking references the guest by id only (no cross-engine association)" do
        assert_file "engines/bookings/app/models/bookings/booking.rb" do |content|
          code = code_of(content)
          aggregate_failures do
            expect(code).not_to include("belongs_to :identity")
            expect(code).not_to include("Auth::")
            expect(code).to include("belongs_to :occurrence")
          end
        end
      end

      it "creates Bookings::Instalment with kinds, states, and a unique payable_ref" do
        assert_file "engines/bookings/app/models/bookings/instalment.rb" do |content|
          expect(content).to include("KINDS  = %w[deposit balance full].freeze")
          expect(content).to include("STATES = %w[due requested paid refunded].freeze")
          expect(content).to include("validates :payable_ref, presence: true, uniqueness: true")
          expect(content).to include("def assign_payable_ref")
        end
      end
    end

    describe "hold service" do
      it "locks the occurrence, inserts the booking and the deposit instalment, then publishes" do
        assert_file "engines/bookings/app/services/bookings/hold_service.rb" do |content|
          expect(content).to include("Bookings::Booking.transaction do")
          expect(content).to include(".with_lock")
          expect(content).to include("instalments.create!")
          expect(content).to include('"booking.held.bookings"')
        end
      end

      it "refuses a hold without a signed-in guest" do
        assert_file "engines/bookings/app/services/bookings/hold_service.rb" do |content|
          expect(content).to include("if identity_id.blank?")
          expect(content).to include("code: :unauthenticated")
        end
      end

      it "ships a uniform ServiceResult" do
        assert_file "engines/bookings/app/services/bookings/service_result.rb" do |content|
          expect(content).to include("ServiceResult = Struct.new(:ok, :value, :error, :code, keyword_init: true)")
        end
      end
    end

    describe "marking an instalment paid by hand" do
      it "takes the occurrence lock and confirms, or moves to pending_review for a manual offering" do
        assert_file "engines/bookings/app/services/bookings/instalments/mark_paid_service.rb" do |content|
          expect(content).to include(".with_lock")
          expect(content).to include('"pending_review"')
          expect(content).to include('"confirmed"')
          expect(content).to include('"booking.confirmed.bookings"')
          expect(content).to include("return ok(instalment) if instalment.paid?")
        end
      end
    end

    describe "hold sweep job" do
      it "publishes booking.hold_expiring.bookings for held rows past expires_at" do
        assert_file "engines/bookings/app/jobs/bookings/hold_sweep_job.rb" do |content|
          expect(content).to include("queue_as :bookings")
          expect(content).to include("Bookings::Booking.hold_expired.find_each")
          expect(content).to include('"booking.hold_expiring.bookings"')
        end
      end

      it "does not change the booking row" do
        assert_file "engines/bookings/app/jobs/bookings/hold_sweep_job.rb" do |content|
          code = code_of(content)
          aggregate_failures do
            expect(code).not_to include("update")
            expect(code).not_to include("save")
            expect(code).not_to include("destroy")
          end
        end
      end

      it "creates Bookings::ApplicationJob extending the host's ApplicationJob" do
        assert_file "engines/bookings/app/jobs/bookings/application_job.rb" do |content|
          expect(content).to include("class ApplicationJob < ::ApplicationJob")
        end
      end
    end

    describe "migrations" do
      it "creates the four tables with What / Why / Risk comments" do
        %w[create_booking_offerings create_booking_occurrences create_bookings create_booking_instalments].each do |slug|
          content = migration_matching(slug)
          expect(content).to include("# What:")
          expect(content).to include("# Why:")
          expect(content).to include("# Risk:")
        end
      end

      it "bookings carries identity_id as a bare bigint with no database foreign key" do
        content = migration_matching("create_bookings")
        aggregate_failures do
          expect(content).to include("t.bigint     :identity_id,   null: false")
          expect(content).not_to include("to_table: :auth_identities")
          expect(content).to include("add_index :bookings, :reference, unique: true")
          expect(content).to include("add_index :bookings, %i[occurrence_id status]")
          expect(content).to include("add_index :bookings, %i[status expires_at]")
        end
      end

      it "booking_instalments has a unique payable_ref and a nullable checkout URL" do
        content = migration_matching("create_booking_instalments")
        expect(content).to include("add_index :booking_instalments, :payable_ref, unique: true")
        expect(content).to include("t.string     :checkout_url")
      end

      it "booking_occurrences stores a nullable deposit and jsonb details" do
        content = migration_matching("create_booking_occurrences")
        expect(content).to include("t.integer    :deposit_cents")
        expect(content).to include("t.jsonb      :details,       null: false, default: {}")
        expect(content).to include("t.integer    :capacity,      null: false")
      end
    end

    describe "boundary" do
      it "never references a Billing constant in executable code" do
        offenders = Dir[File.join(destination_root, "engines/bookings/**/*.rb")].select do |path|
          code_of(File.read(path)).match?(/\bBilling(::|\.)/)
        end
        expect(offenders).to be_empty, "Billing referenced in: #{offenders.join(", ")}"
      end

      it "never names a Billing job or enqueues into Billing" do
        offenders = Dir[File.join(destination_root, "engines/bookings/**/*.rb")].select do |path|
          code_of(File.read(path)).match?(/Billing\w*Job|perform_later\(.*billing/i)
        end
        expect(offenders).to be_empty, "Billing job referenced in: #{offenders.join(", ")}"
      end
    end

    describe "specs + factories" do
      it "ships factories for every model" do
        assert_file "engines/bookings/spec/factories/bookings.rb" do |content|
          %w[bookings_offering bookings_occurrence booking booking_instalment].each do |name|
            expect(content).to include("factory :#{name}")
          end
        end
      end

      it "ships model, service, and job specs" do
        %w[
          spec/models/bookings/offering_spec.rb
          spec/models/bookings/occurrence_spec.rb
          spec/models/bookings/booking_spec.rb
          spec/models/bookings/instalment_spec.rb
          spec/services/bookings/hold_service_spec.rb
          spec/services/bookings/instalments/mark_paid_service_spec.rb
          spec/jobs/bookings/hold_sweep_job_spec.rb
          spec/runtime/bookings_boot_spec.rb
        ].each { |path| assert_file "engines/bookings/#{path}" }
      end

      it "the hold service spec races two threads for the last place" do
        assert_file "engines/bookings/spec/services/bookings/hold_service_spec.rb" do |content|
          expect(content).to include("self.use_transactional_tests = false")
          expect(content).to include("Thread.new")
          expect(content).to include("two threads")
        end
      end
    end

    describe "dummy app" do
      it "ships the bookings tables plus an auth_identities stub in the dummy schema" do
        assert_file "engines/bookings/spec/dummy/db/schema.rb" do |content|
          %w[auth_identities booking_offerings booking_occurrences bookings booking_instalments].each do |table|
            expect(content).to include("create_table :#{table}")
          end
        end
      end

      it "ships a slim Auth::Identity stub so the boot assertion passes" do
        assert_file "engines/bookings/spec/dummy/app/models/auth/identity.rb" do |content|
          expect(content).to include("class Identity < ApplicationRecord")
          expect(content).to include('self.table_name = "auth_identities"')
        end
      end
    end

    describe "engine lint config" do
      it "excludes spec files from Metrics/BlockLength like the gem's own config" do
        assert_file "engines/bookings/.rubocop.yml" do |content|
          expect(content).to include("Metrics/BlockLength:\n  Exclude:\n    - \"spec/**/*\"")
          expect(content).to include("OwnEngine: Bookings")
        end
      end
    end

    describe "host wiring" do
      it "mounts Bookings::Engine at /bookings" do
        assert_file "config/routes.rb" do |content|
          expect(content).to include('mount Bookings::Engine, at: "/bookings"')
        end
      end

      it "adds factory_bot_rails to the host test group" do
        assert_file "Gemfile" do |content|
          expect(content).to include('gem "factory_bot_rails"')
        end
      end
    end

    describe "documentation" do
      it "rewrites the README with the events table and the sweep schedule" do
        assert_file "engines/bookings/README.md" do |content|
          aggregate_failures do
            BOOKINGS_REGISTERED_EVENTS.each { |event| expect(content).to include(event) }
            expect(content).to include("hold_ttl")
            expect(content).to include("Bookings::HoldSweepJob")
            expect(content).to include("Bookings::Instalments::MarkPaidService")
          end
        end
      end
    end

    describe "insertion-point markers" do
      BOOKINGS_INSERTION_MARKERS.each do |marker, path|
        it "ships #{marker} in #{path}" do
          assert_file path do |content|
            expect(content).to include("# seams:insertion-point #{marker}")
          end
        end
      end
    end
  end

  context "when the host already has config/initializers/bookings.rb" do
    let(:initializer) { File.join(destination_root, "config/initializers/bookings.rb") }

    before do
      prepare_destination
      File.write(initializer, "# host-owned\n")
      run_generator
    end

    it "leaves the host's initializer alone" do
      expect(File.read(initializer)).to eq("# host-owned\n")
    end
  end
end
