# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/billing/billing_generator"

RSpec.describe Seams::Generators::BillingGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/billing_generator", __dir__) }

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
    it "registers the five canonical billing events" do
      assert_file "engines/billing/lib/billing/engine.rb" do |content|
        expect(content).to include('"subscription.created.billing"')
        expect(content).to include('"subscription.updated.billing"')
        expect(content).to include('"subscription.canceled.billing"')
        expect(content).to include('"invoice.paid.billing"')
        expect(content).to include('"invoice.failed.billing"')
      end
    end
  end

  describe "configuration" do
    it "creates Billing::Configuration with gateway + api_key + webhook_secret" do
      assert_file "engines/billing/lib/billing/configuration.rb" do |content|
        expect(content).to include("attr_accessor :gateway, :api_key, :webhook_secret, :default_currency")
      end
    end
  end

  describe "gateways" do
    let(:gateway_needles) do
      %w[
        ::Stripe::Subscription.create
        ::Stripe::Subscription.cancel
        ::Stripe::Subscription.retrieve
        ::Stripe::Webhook.construct_event
        docs.stripe.com/api/subscriptions/create
        docs.stripe.com/api/subscriptions/cancel
        docs.stripe.com/api/subscriptions/retrieve
        docs.stripe.com/webhooks/signatures
        Billing::GatewayError
        Billing::WebhookError
      ]
    end

    it "creates the abstract gateway with the four contract methods" do
      assert_file "engines/billing/lib/billing/gateways/abstract.rb" do |content|
        expect(content).to include("def create_subscription")
        expect(content).to include("def cancel_subscription")
        expect(content).to include("def fetch_subscription")
        expect(content).to include("def verify_webhook")
      end
    end

    it "creates the Stripe gateway with documented Stripe API calls + doc URLs" do
      assert_file "engines/billing/lib/billing/gateways/stripe.rb" do |content|
        gateway_needles.each do |needle|
          expect(content).to include(needle), "expected gateway to include #{needle}"
        end
      end
    end
  end

  describe "concern" do
    it "creates Billing::Billable with start/cancel subscription helpers" do
      assert_file "engines/billing/lib/billing/concerns/billable.rb" do |content|
        expect(content).to include("def start_subscription!")
        expect(content).to include("def cancel_subscription!")
        expect(content).to include('require "active_support/concern"')
      end
    end

    it "registers Billing::Billable in ExposedConcerns" do
      assert_file "engines/billing/.rubocop.yml" do |content|
        expect(content).to include("Billing::Billable")
      end
    end
  end

  describe "models" do
    it "creates Billing::Subscription with status validation" do
      assert_file "engines/billing/app/models/billing/subscription.rb" do |content|
        expect(content).to include("STATUSES")
        expect(content).to include("def active?")
      end
    end

    it "creates Billing::Invoice with status validation" do
      assert_file "engines/billing/app/models/billing/invoice.rb" do |content|
        expect(content).to include("def paid?")
        expect(content).to include("amount_cents")
      end
    end

    it "creates Billing::WebhookEvent with unique gateway_event_id" do
      assert_file "engines/billing/app/models/billing/webhook_event.rb" do |content|
        expect(content).to include("class WebhookEvent")
        expect(content).to include("uniqueness: { scope: :gateway }")
      end
    end
  end

  describe "jobs" do
    it "creates Billing::ApplicationJob extending the host's ApplicationJob" do
      assert_file "engines/billing/app/jobs/billing/application_job.rb" do |content|
        expect(content).to include("class ApplicationJob < ::ApplicationJob")
      end
    end

    it "creates StartSubscriptionJob and CancelSubscriptionJob with queue + event publishing" do
      assert_file "engines/billing/app/jobs/billing/start_subscription_job.rb" do |content|
        expect(content).to include("queue_as :billing")
        expect(content).to include('"subscription.created.billing"')
      end

      assert_file "engines/billing/app/jobs/billing/cancel_subscription_job.rb" do |content|
        expect(content).to include("queue_as :billing")
        expect(content).to include('"subscription.canceled.billing"')
      end
    end
  end

  describe "webhooks" do
    it "creates WebhooksController#stripe with signature verification + event dispatch" do
      assert_file "engines/billing/app/controllers/billing/webhooks_controller.rb" do |content|
        expect(content).to include("def stripe")
        expect(content).to include("verify_webhook")
        expect(content).to include("Stripe-Signature")
        expect(content).to include("EVENT_MAP")
      end
    end

    it "dedupes Stripe retries via Billing::WebhookEvent" do
      assert_file "engines/billing/app/controllers/billing/webhooks_controller.rb" do |content|
        expect(content).to include("Billing::WebhookEvent.create!")
        expect(content).to include("ActiveRecord::RecordNotUnique")
        expect(content).to include("billing.webhook.duplicate")
      end
    end

    it "draws the stripe webhook route" do
      assert_file "engines/billing/config/routes.rb" do |content|
        expect(content).to include('post "/webhooks/stripe"')
      end
    end
  end

  describe "migrations" do
    it "creates billing_subscriptions migration with What/Why/Risk block" do
      pattern = File.join(destination_root, "engines/billing/db/migrate", "*_create_billing_subscriptions.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("# What:")
      expect(content).to include("# Why:")
      expect(content).to include("create_table :billing_subscriptions")
    end

    it "creates billing_invoices migration referencing subscriptions" do
      pattern = File.join(destination_root, "engines/billing/db/migrate", "*_create_billing_invoices.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :billing_invoices")
      expect(content).to include("to_table: :billing_subscriptions")
    end

    it "creates billing_webhook_events migration with unique gateway_event_id index" do
      pattern = File.join(destination_root,
                          "engines/billing/db/migrate",
                          "*_create_billing_webhook_events.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :billing_webhook_events")
      expect(content).to include("unique: true")
    end
  end

  describe "documentation + specs" do
    it "rewrites README with events table + Stripe API URL list" do
      assert_file "engines/billing/README.md" do |content|
        expect(content).to include("subscription.created.billing")
        expect(content).to include("docs.stripe.com")
      end
    end

    it "creates subscription + stripe gateway specs" do
      assert_file "engines/billing/spec/models/billing/subscription_spec.rb"
      assert_file "engines/billing/spec/gateways/billing/stripe_spec.rb"
    end
  end
end
