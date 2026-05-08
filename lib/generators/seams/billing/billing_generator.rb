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
    # rubocop:disable Metrics/ClassLength
    class BillingGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME      = "billing"
      DEFAULT_GATEWAY  = "stripe"
      KNOWN_GATEWAYS   = %w[stripe paddle adyen].freeze

      class_option :gateway, type: :string, default: DEFAULT_GATEWAY,
                             desc: "Billing gateway: stripe (default), paddle, or adyen (stub)"

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
        template "app/models/lifetime_pass.rb.tt",
                 engine_path("app/models/billing/lifetime_pass.rb")
      end

      def create_gateways
        template "lib/gateways/abstract.rb.tt",
                 engine_path("lib/billing/gateways/abstract.rb")

        # Stripe ships unconditionally (it's the default + reference
        # implementation that sibling specs reference). Paddle / Adyen
        # are stubs — copied only when --gateway=paddle/adyen.
        template "lib/gateways/stripe.rb.tt",
                 engine_path("lib/billing/gateways/stripe.rb")
        template "lib/stripe/client.rb.tt",
                 engine_path("lib/billing/stripe/client.rb")
        template "lib/stripe/webhook_signature.rb.tt",
                 engine_path("lib/billing/stripe/webhook_signature.rb")

        return if gateway == "stripe"

        template "lib/gateways/#{gateway}.rb.tt",
                 engine_path("lib/billing/gateways/#{gateway}.rb")
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
        create_service_foundation
        create_session_services
        create_domain_services
      end

      def create_service_foundation
        # Phase 3 (1/4) — uniform service object foundation.
        template "app/services/service_result.rb.tt",
                 engine_path("app/services/billing/service_result.rb")
        template "app/services/stripe_service.rb.tt",
                 engine_path("app/services/billing/stripe_service.rb")
      end

      def create_session_services
        template "app/services/checkout_session_service.rb.tt",
                 engine_path("app/services/billing/checkout/create_session_service.rb")
        template "app/services/portal_session_service.rb.tt",
                 engine_path("app/services/billing/portal/create_session_service.rb")
      end

      def create_domain_services
        create_customer_and_subscription_services
        create_invoice_and_lifetime_services
      end

      def create_customer_and_subscription_services
        # Phase 3 (2/4) — Customers + Subscriptions service objects.
        template "app/services/customers/find_or_create_service.rb.tt",
                 engine_path("app/services/billing/customers/find_or_create_service.rb")
        template "app/services/subscriptions/cancel_service.rb.tt",
                 engine_path("app/services/billing/subscriptions/cancel_service.rb")
        template "app/services/subscriptions/change_plan_service.rb.tt",
                 engine_path("app/services/billing/subscriptions/change_plan_service.rb")
        template "app/services/subscriptions/reactivate_service.rb.tt",
                 engine_path("app/services/billing/subscriptions/reactivate_service.rb")
      end

      def create_invoice_and_lifetime_services
        template "app/services/invoices/sync_service.rb.tt",
                 engine_path("app/services/billing/invoices/sync_service.rb")
        # Lifetime Deal services — see issue #2 section 3A.LTD.
        template "app/services/lifetime/grant_pass_service.rb.tt",
                 engine_path("app/services/billing/lifetime/grant_pass_service.rb")
        template "app/services/lifetime/revoke_pass_service.rb.tt",
                 engine_path("app/services/billing/lifetime/revoke_pass_service.rb")
        template "app/services/lifetime/create_pass_from_checkout_service.rb.tt",
                 engine_path("app/services/billing/lifetime/create_pass_from_checkout_service.rb")
        template "app/services/lifetime/create_lifetime_session_service.rb.tt",
                 engine_path("app/services/billing/lifetime/create_lifetime_session_service.rb")
      end

      # Phase 3 (3/4) — webhook router + 13 handler classes.
      def create_webhook_router_and_handlers
        template "app/services/webhooks/handler.rb.tt",
                 engine_path("app/services/billing/webhooks/handler.rb")
        template "app/services/webhooks/event_router.rb.tt",
                 engine_path("app/services/billing/webhooks/event_router.rb")

        webhook_handler_templates.each do |basename|
          template "app/services/webhooks/handlers/#{basename}.rb.tt",
                   engine_path("app/services/billing/webhooks/handlers/#{basename}.rb")
        end
      end

      def create_webhook_process_event_job
        template "app/jobs/webhooks/process_event_job.rb.tt",
                 engine_path("app/jobs/billing/webhooks/process_event_job.rb")
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

      # Phase 3 (4/4) — self-service subscription management +
      # read-only billing history. Routes live in config/routes.rb.tt.
      def create_subscriptions_and_invoices_ui
        template "app/controllers/subscriptions_controller.rb.tt",
                 engine_path("app/controllers/billing/subscriptions_controller.rb")
        template "app/controllers/invoices_controller.rb.tt",
                 engine_path("app/controllers/billing/invoices_controller.rb")
        template "app/views/subscriptions/index.html.erb.tt",
                 engine_path("app/views/billing/subscriptions/index.html.erb")
        template "app/views/subscriptions/show.html.erb.tt",
                 engine_path("app/views/billing/subscriptions/show.html.erb")
        template "app/views/invoices/index.html.erb.tt",
                 engine_path("app/views/billing/invoices/index.html.erb")
        template "app/views/invoices/show.html.erb.tt",
                 engine_path("app/views/billing/invoices/show.html.erb")
      end

      # LTD admin controller + views (issue #2 section 3A.LTD). Kept
      # in its own generator method so create_controllers_and_views
      # stays under the AbcSize lint threshold.
      def create_lifetime_admin_controller_and_views
        template "app/controllers/admin/lifetime_passes_controller.rb.tt",
                 engine_path("app/controllers/billing/admin/lifetime_passes_controller.rb")
        template "app/views/admin/lifetime_passes/index.html.erb.tt",
                 engine_path("app/views/billing/admin/lifetime_passes/index.html.erb")
        template "app/views/admin/lifetime_passes/new.html.erb.tt",
                 engine_path("app/views/billing/admin/lifetime_passes/new.html.erb")
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
        template "db/migrate/create_billing_lifetime_passes.rb.tt",
                 engine_path("db/migrate/#{timestamp(4)}_create_billing_lifetime_passes.rb")
      end

      def create_specs
        template "spec/models/subscription_spec.rb.tt",
                 engine_path("spec/models/billing/subscription_spec.rb")
        template "spec/gateways/stripe_spec.rb.tt",
                 engine_path("spec/gateways/billing/stripe_spec.rb")
        # Phase 3 (1/4) — factories + Stripe webmock helpers + event fixtures.
        template "spec/factories/billing.rb.tt",
                 engine_path("spec/factories/billing.rb")
        template "spec/support/stripe_helpers.rb.tt",
                 engine_path("spec/support/stripe_helpers.rb")
        # Phase 3 (4/4) — gateway contract shared_examples.
        template "spec/support/shared_examples/a_billing_gateway.rb.tt",
                 engine_path("spec/support/shared_examples/a_billing_gateway.rb")
        template "spec/gateways/contract_spec.rb.tt",
                 engine_path("spec/gateways/billing/contract_spec.rb")
        create_stripe_event_fixtures
      end

      def create_stripe_event_fixtures
        %w[
          customer_subscription_created
          customer_subscription_updated
          customer_subscription_deleted
          customer_subscription_trial_will_end
          invoice_created
          invoice_paid
          invoice_payment_failed
          invoice_finalized
          invoice_voided
          payment_intent_succeeded
          payment_intent_payment_failed
          charge_refunded
          checkout_session_completed
        ].each do |name|
          template "spec/fixtures/stripe/#{name}.json.tt",
                   engine_path("spec/fixtures/stripe/#{name}.json")
        end
      end

      def create_helpers
        # Phase 3 (1/4) — currency formatter for the pricing page +
        # invoice views.
        template "app/helpers/currency_helper.rb.tt",
                 engine_path("app/helpers/billing/currency_helper.rb")
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
        # The Billing engine speaks Stripe via its own Faraday-based
        # client (lib/billing/stripe/client.rb) — the official `stripe`
        # gem uses Net::HTTP and is forbidden by the Faraday-only rule
        # (memory feedback_external_apis.md).
        host_inject_gem("faraday", "~> 2.0")
        host_inject_gem("factory_bot_rails", "~> 6.4", group: :test)
        host_inject_gem("webmock",           "~> 3.23", group: :test)
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

      # Resolved gateway choice from --gateway. Garbage / unknown
      # values fall back to stripe (no surprising half-installed
      # engine). Memoised so ERB conditionals stay consistent.
      def gateway
        @gateway ||= begin
          requested = options[:gateway].to_s.downcase.strip
          KNOWN_GATEWAYS.include?(requested) ? requested : DEFAULT_GATEWAY
        end
      end

      def gateway_class_name
        "Billing::Gateways::#{gateway.capitalize}"
      end

      def gateway_env_prefix
        gateway.upcase
      end

      def webhook_handler_templates
        %w[
          subscription_handler_base
          subscription_created_handler
          subscription_updated_handler
          subscription_deleted_handler
          subscription_trial_will_end_handler
          invoice_handler_base
          invoice_created_handler
          invoice_paid_handler
          invoice_payment_failed_handler
          invoice_finalized_handler
          invoice_voided_handler
          payment_succeeded_handler
          payment_failed_handler
          charge_refunded_handler
          checkout_session_completed_handler
        ]
      end

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
            t.string     :gateway_ref,      null: false
            t.string     :customer_ref,     null: false
            t.string     :subscription_ref
            t.integer    :amount_cents,     null: false
            t.string     :currency,         null: false, default: "USD"
            t.string     :status,           null: false, default: "open"
            t.datetime   :paid_at
            t.timestamps
          end
          add_index :billing_invoices, :gateway_ref, unique: true

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
            t.integer :max_lifetime_units
            t.timestamps
          end

          create_table :billing_lifetime_passes do |t|
            t.string   :customer_ref,        null: false
            t.string   :plan_ref,            null: false
            t.string   :gateway_ref
            t.bigint   :granted_by_user_id
            t.datetime :granted_at,          null: false
            t.datetime :revoked_at
            t.bigint   :revoked_by_user_id
            t.text     :notes
            t.timestamps
          end
          add_index :billing_lifetime_passes, %i[customer_ref plan_ref], unique: true,
                                                                         name: "index_billing_ltd_unique"

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
    # rubocop:enable Metrics/ClassLength
  end
end
