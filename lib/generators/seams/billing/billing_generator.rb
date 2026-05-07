# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"

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

      def create_webhooks
        template "app/controllers/webhooks_controller.rb.tt",
                 engine_path("app/controllers/billing/webhooks_controller.rb")
      end

      def create_migrations
        template "db/migrate/create_billing_subscriptions.rb.tt",
                 engine_path("db/migrate/#{timestamp(0)}_create_billing_subscriptions.rb")
        template "db/migrate/create_billing_invoices.rb.tt",
                 engine_path("db/migrate/#{timestamp(1)}_create_billing_invoices.rb")
        template "db/migrate/create_billing_webhook_events.rb.tt",
                 engine_path("db/migrate/#{timestamp(2)}_create_billing_webhook_events.rb")
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

      def report_summary
        say ""
        say "  Billing engine generated at engines/billing/", :green
        say ""
        say "  Next steps:", :yellow
        say "    1. Add `gem \"stripe\"` to your host Gemfile and bundle install"
        say "    2. Add `mount Billing::Engine, at: \"/billing\"` to config/routes.rb"
        say "    3. Set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET in your env"
        say "    4. Configure your Stripe webhook endpoint to point to /billing/webhooks/stripe"
        say "    5. `bin/rails db:migrate`"
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
    end
  end
end
