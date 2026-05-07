# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/dummy_app_writer"

module Seams
  module Generators
    # Generates a canonical Billing engine on top of the generic engine
    # scaffold. Wires Stripe by default through a swappable Gateway
    # adapter, ships subscription + invoice models, a webhook
    # controller with signature verification, and a Billable concern
    # the host's user model can include.
    #
    # Run with: bin/rails generate seams:billing
    class BillingGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "billing"

      def create_base_engine
        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      def overwrite_engine_entry_point
        template "lib/engine.rb.tt",         engine_path("lib/billing/engine.rb"),        force: true
        template "lib/billing.rb.tt",        engine_path("lib/billing.rb"),               force: true
        template "lib/configuration.rb.tt",  engine_path("lib/billing/configuration.rb")
      end

      def overwrite_routes
        template "config/routes.rb.tt", engine_path("config/routes.rb"), force: true
      end

      def create_models
        template "app/models/application_record.rb.tt",
                 engine_path("app/models/billing/application_record.rb")
        template "app/models/subscription.rb.tt",
                 engine_path("app/models/billing/subscription.rb")
        template "app/models/invoice.rb.tt",
                 engine_path("app/models/billing/invoice.rb")
        template "app/models/webhook_event.rb.tt",
                 engine_path("app/models/billing/webhook_event.rb")
        template "app/models/plan.rb.tt",
                 engine_path("app/models/billing/plan.rb")
      end

      def create_gateways
        template "lib/gateways/abstract.rb.tt",
                 engine_path("lib/billing/gateways/abstract.rb")
        template "lib/gateways/stripe.rb.tt",
                 engine_path("lib/billing/gateways/stripe.rb")
      end

      def create_concern
        template "lib/concerns/billable.rb.tt",
                 engine_path("lib/billing/concerns/billable.rb")
      end

      def create_jobs
        template "app/jobs/application_job.rb.tt",
                 engine_path("app/jobs/billing/application_job.rb")
        template "app/jobs/start_subscription_job.rb.tt",
                 engine_path("app/jobs/billing/start_subscription_job.rb")
        template "app/jobs/cancel_subscription_job.rb.tt",
                 engine_path("app/jobs/billing/cancel_subscription_job.rb")
      end

      def create_services
        template "app/services/checkout_session_service.rb.tt",
                 engine_path("app/services/billing/checkout/create_session_service.rb")
        template "app/services/portal_session_service.rb.tt",
                 engine_path("app/services/billing/portal/create_session_service.rb")
      end

      def create_controllers_and_views
        template "app/controllers/webhooks_controller.rb.tt",
                 engine_path("app/controllers/billing/webhooks_controller.rb")
        template "app/controllers/checkout_controller.rb.tt",
                 engine_path("app/controllers/billing/checkout_controller.rb")
        template "app/controllers/portal_controller.rb.tt",
                 engine_path("app/controllers/billing/portal_controller.rb")
        template "app/controllers/plans_controller.rb.tt",
                 engine_path("app/controllers/billing/plans_controller.rb")
        template "app/views/checkout/success.html.erb.tt",
                 engine_path("app/views/billing/checkout/success.html.erb")
        template "app/views/plans/index.html.erb.tt",
                 engine_path("app/views/billing/plans/index.html.erb")
      end

      def create_migrations
        template "db/migrate/create_billing_subscriptions.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_billing_subscriptions.rb")
        template "db/migrate/create_billing_invoices.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_billing_invoices.rb")
        template "db/migrate/create_billing_webhook_events.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_create_billing_webhook_events.rb")
        template "db/migrate/create_billing_plans.rb.tt",
                 engine_path("db/migrate/#{timestamp(3)}_create_billing_plans.rb")
      end

      def create_specs
        template "spec/models/subscription_spec.rb.tt",
                 engine_path("spec/models/billing/subscription_spec.rb")
        template "spec/gateways/stripe_spec.rb.tt",
                 engine_path("spec/gateways/billing/stripe_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      def update_exposed_concerns
        rubocop_path = engine_path(".rubocop.yml")
        return unless File.exist?(rubocop_path)

        contents = File.read(rubocop_path)
        replacement = "  ExposedConcerns:\n    - Billing::Billable"
        contents.sub!(/^  ExposedConcerns: \[\]$/, replacement)
        File.write(rubocop_path, contents)
      end

      def create_dummy_app
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", ENGINE_NAME),
          engine_module: "Billing",
          mount_at: "/billing",
          schema: dummy_schema,
          host_user: dummy_host_user
        )
        template "spec/runtime/boot_spec.rb.tt",
                 engine_path("spec/runtime/billing_boot_spec.rb")
      end

      def wire_into_host
        host_inject_gem("stripe", "~> 12.0")
        host_inject_mount(engine_class: "Billing::Engine", at: "/billing")
        host_inject_include_in_user("Billing::Billable")
      end

      def report_summary
        say ""
        say "  Billing engine generated at engines/billing/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. bundle install   (picks up stripe + Billing::Engine)"
        say "    2. Set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET in your env"
        say "    3. Configure your Stripe webhook to POST to /billing/webhooks/stripe"
        say "    4. bin/rails db:migrate"
        say ""
      end

      private

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      def timestamp(offset)
        base = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        (base + 200 + offset).to_s
      end

      def dummy_schema
        <<~SCHEMA
          create_table :billing_subscriptions do |t|
            t.string   :customer_ref,       null: false
            t.string   :plan_ref,           null: false
            t.string   :gateway_ref,        null: false
            t.string   :status,             null: false, default: "incomplete"
            t.datetime :current_period_end
            t.timestamps
          end
          add_index :billing_subscriptions, :gateway_ref, unique: true

          create_table :billing_invoices do |t|
            t.references :subscription
            t.string     :gateway_ref,  null: false
            t.integer    :amount_cents, null: false
            t.string     :currency,     null: false, default: "usd"
            t.string     :status,       null: false, default: "open"
            t.datetime   :paid_at
            t.timestamps
          end

          create_table :billing_webhook_events do |t|
            t.string   :gateway,           null: false
            t.string   :gateway_event_id,  null: false
            t.string   :event_type,        null: false
            t.boolean  :livemode,          null: false, default: false
            t.timestamps
          end
          add_index :billing_webhook_events, %i[gateway gateway_event_id], unique: true

          create_table :billing_plans do |t|
            t.string  :gateway_ref,       null: false
            t.string  :name,              null: false
            t.text    :description
            t.integer :amount_cents,      null: false, default: 0
            t.string  :currency,          null: false, default: "usd"
            t.string  :interval,          null: false, default: "month"
            t.integer :trial_period_days
            t.boolean :active,            null: false, default: true
            t.jsonb   :features,          null: false, default: {}
            t.timestamps
          end

          create_table :users do |t|
            t.string :email
            t.string :stripe_customer_id
            t.timestamps
          end
        SCHEMA
      end

      def dummy_host_user
        <<~RB
          # frozen_string_literal: true

          class User < ApplicationRecord
            include Billing::Billable
          end
        RB
      end
    end
  end
end
