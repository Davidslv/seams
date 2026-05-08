# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/billing/billing_generator"

BILLING_SUBSCRIPTION_LEAF_HANDLERS = {
  "subscription_created_handler" => "subscription.created.billing",
  "subscription_updated_handler" => "subscription.updated.billing",
  "subscription_deleted_handler" => "subscription.canceled.billing",
  "subscription_trial_will_end_handler" => "subscription.trial_will_end.billing"
}.freeze

BILLING_INVOICE_LEAF_HANDLERS = {
  "invoice_created_handler" => ["invoice.created.billing", "draft"],
  "invoice_paid_handler" => ["invoice.paid.billing", "paid"],
  "invoice_payment_failed_handler" => ["invoice.failed.billing", "open"],
  "invoice_finalized_handler" => ["invoice.finalized.billing", "open"],
  "invoice_voided_handler" => ["invoice.voided.billing", "void"]
}.freeze

BILLING_STANDALONE_HANDLERS = {
  "payment_succeeded_handler" => "payment.succeeded.billing",
  "payment_failed_handler" => "payment.failed.billing",
  "charge_refunded_handler" => "charge.refunded.billing",
  "checkout_session_completed_handler" => "checkout.session_completed.billing"
}.freeze

BILLING_REGISTERED_EVENTS = %w[
  subscription.created.billing subscription.updated.billing
  subscription.canceled.billing subscription.trial_will_end.billing
  invoice.created.billing invoice.paid.billing invoice.failed.billing
  invoice.finalized.billing invoice.voided.billing
  payment.succeeded.billing payment.failed.billing charge.refunded.billing
  checkout.session_completed.billing
  lifetime.granted.billing lifetime.purchased.billing lifetime.revoked.billing
].freeze

BILLING_STRIPE_CLIENT_NEEDLES = [
  'require "stripe"',
  "::Stripe::StripeClient.new(api_key)",
  "sdk.v1.customers.create",
  "sdk.v1.customers.search",
  "sdk.v1.subscriptions.create",
  "sdk.v1.subscriptions.cancel",
  "sdk.v1.subscriptions.retrieve",
  "sdk.v1.subscriptions.update",
  "sdk.v1.invoices.retrieve",
  "sdk.v1.checkout.sessions.create",
  "sdk.v1.billing_portal.sessions.create",
  "idempotency_key:"
].freeze

BILLING_HANDLER_RUNTIME_NEEDLES = %w[
  Billing::Webhooks::Handlers::SubscriptionCreatedHandler
  Billing::Webhooks::Handlers::SubscriptionUpdatedHandler
  Billing::Webhooks::Handlers::SubscriptionDeletedHandler
  Billing::Webhooks::Handlers::SubscriptionTrialWillEndHandler
  Billing::Webhooks::Handlers::InvoiceCreatedHandler
  Billing::Webhooks::Handlers::InvoicePaidHandler
  Billing::Webhooks::Handlers::InvoicePaymentFailedHandler
  Billing::Webhooks::Handlers::InvoiceFinalizedHandler
  Billing::Webhooks::Handlers::InvoiceVoidedHandler
  Billing::Webhooks::Handlers::PaymentSucceededHandler
  Billing::Webhooks::Handlers::PaymentFailedHandler
  Billing::Webhooks::Handlers::ChargeRefundedHandler
  Billing::Webhooks::Handlers::CheckoutSessionCompletedHandler
  Seams::Events::Publisher.subscribe
  stripe_event_fixture
  Billing::Subscription.find_by
  Billing::Invoice.find_by
  Billing::LifetimePass
].freeze

BILLING_EVENT_ROUTER_NEEDLES = %w[
  customer.subscription.created customer.subscription.trial_will_end
  invoice.created invoice.finalized invoice.voided
  payment_intent.succeeded payment_intent.payment_failed
  charge.refunded
  checkout.session.completed checkout.session.async_payment_succeeded
].freeze

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

    it "ships a billable_class knob defaulting to Accounts::Account" do
      # Post-Wave-9: Billing::Billable is included into the
      # configured tenant class at boot rather than injected into
      # a host User model. The default `Accounts::Account` matches
      # the canonical accounts engine.
      assert_file "engines/billing/lib/billing/configuration.rb" do |content|
        expect(content).to include(":billable_class")
        expect(content).to include('@billable_class         = "Accounts::Account"')
      end
    end
  end

  describe "gateways" do
    let(:gateway_needles) do
      %w[
        Billing::Stripe::Client
        Billing::Stripe::WebhookSignature
        docs.stripe.com/api/customers/create
        docs.stripe.com/api/subscriptions/create
        docs.stripe.com/api/subscriptions/cancel
        docs.stripe.com/api/subscriptions/retrieve
        docs.stripe.com/api/checkout/sessions/create
        docs.stripe.com/api/customer_portal/sessions/create
        docs.stripe.com/webhooks/signatures
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

    it "creates the Stripe gateway that delegates to the Stripe SDK Client + WebhookSignature" do
      assert_file "engines/billing/lib/billing/gateways/stripe.rb" do |content|
        gateway_needles.each do |needle|
          expect(content).to include(needle), "expected gateway to include #{needle}"
        end
      end
    end

    it "ships the Stripe::StripeClient-backed Client facade" do
      assert_file "engines/billing/lib/billing/stripe/client.rb" do |content|
        BILLING_STRIPE_CLIENT_NEEDLES.each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships the SDK-backed WebhookSignature wrapper" do
      assert_file "engines/billing/lib/billing/stripe/webhook_signature.rb" do |content|
        [
          'require "stripe"',
          "::Stripe::Webhook.construct_event",
          "::Stripe::SignatureVerificationError",
          "DEFAULT_TOLERANCE = 300",
          "Billing::WebhookError"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "host_inject_gem adds the official `stripe` gem (not faraday for Stripe)" do
      gen_path = File.expand_path("../../../lib/generators/seams/billing/billing_generator.rb", __dir__)
      content  = File.read(gen_path)
      expect(content).to include('host_inject_gem("stripe"')
      expect(content).not_to match(/host_inject_gem\("faraday"/)
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

    it "Billable concern keys associations off account_id (Account-as-customer)" do
      assert_file "engines/billing/lib/billing/concerns/billable.rb" do |content|
        # Wave 9 contract: the tenant model gets the concern, and
        # has_many associations are keyed on account_id. There is
        # no stripe_customer_id reference here because the Stripe
        # customer is per-Account, not per-Identity.
        expect(content).to include("foreign_key: :account_id")
        expect(content).to include("class_name: \"Billing::Subscription\"")
        expect(content).to include("class_name: \"Billing::LifetimePass\"")
        expect(content).not_to include("stripe_customer_id")
      end
    end

    it "Billable#start_subscription! takes plan_ref + email (no host User assumed)" do
      assert_file "engines/billing/lib/billing/concerns/billable.rb" do |content|
        expect(content).to match(/def start_subscription!\(plan_ref:, email:\)/)
      end
    end

    it "registers Billing::Billable in ExposedConcerns" do
      assert_file "engines/billing/.rubocop.yml" do |content|
        expect(content).to include("Billing::Billable")
      end
    end

    it "engine.rb auto-includes Billable into the configured billable_class" do
      assert_file "engines/billing/lib/billing/engine.rb" do |content|
        expect(content).to include("config.to_prepare")
        expect(content).to include("Billing.configuration.billable_class")
        expect(content).to include("include(Billing::Billable)")
      end
    end

    it "wire_into_host does NOT inject Billing::Billable into the host User" do
      gen_path = File.expand_path("../../../lib/generators/seams/billing/billing_generator.rb", __dir__)
      content  = File.read(gen_path)
      # Pre-Wave-9 the generator called host_inject_include_in_user("Billing::Billable").
      # Post-Wave-9 the engine wires Billable via Billing.configuration.billable_class
      # at boot, so there is no host User edit.
      expect(content).not_to match(/host_inject_include_in_user\(["']Billing::Billable["']\)/)
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

    it "creates Billing::Plan with INTERVALS + free?/has_trial?" do
      assert_file "engines/billing/app/models/billing/plan.rb" do |content|
        expect(content).to include("INTERVALS")
        expect(content).to include("def free?")
        expect(content).to include("def has_trial?")
      end
    end
  end

  describe "checkout + portal" do
    it "creates Billing::Checkout::CreateSessionService" do
      assert_file "engines/billing/app/services/billing/checkout/create_session_service.rb" do |content|
        expect(content).to include("module CreateSessionService")
        expect(content).to include("Billing.gateway.create_checkout_session")
      end
    end

    it "creates Billing::Portal::CreateSessionService" do
      assert_file "engines/billing/app/services/billing/portal/create_session_service.rb" do |content|
        expect(content).to include("module CreateSessionService")
        expect(content).to include("Billing.gateway.create_billing_portal_session")
      end
    end

    it "creates CheckoutController + PortalController + PlansController" do
      assert_file "engines/billing/app/controllers/billing/checkout_controller.rb" do |content|
        expect(content).to include("def create")
        expect(content).to include("def success")
        expect(content).to include("Billing::Checkout::CreateSessionService.call")
      end
      assert_file "engines/billing/app/controllers/billing/portal_controller.rb" do |content|
        expect(content).to include("Billing::Portal::CreateSessionService.call")
      end
      assert_file "engines/billing/app/controllers/billing/plans_controller.rb" do |content|
        expect(content).to include("Billing::Plan.active")
      end
    end

    it "creates plans index + checkout success views" do
      assert_file "engines/billing/app/views/billing/plans/index.html.erb"
      assert_file "engines/billing/app/views/billing/checkout/success.html.erb"
    end

    it "draws checkout, portal, and plans routes" do
      assert_file "engines/billing/config/routes.rb" do |content|
        expect(content).to include("resources :plans")
        expect(content).to include('"/checkout"')
        expect(content).to include('"/portal"')
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
        expect(content).to include("Billing::Webhooks::EventRouter.handler_for")
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

    it "billing_subscriptions has account_id (uuid) and indexes it" do
      # Post-Wave-9: account_id (UUID) is the local FK to
      # Accounts::Account. No DB-level FK because the engines may
      # live in different schemas / databases — application-layer
      # integrity only.
      pattern = File.join(destination_root, "engines/billing/db/migrate", "*_create_billing_subscriptions.rb")
      content = File.read(Dir[pattern].first)
      expect(content).to match(/t\.uuid\s+:account_id,\s+null: false/)
      expect(content).to include("add_index :billing_subscriptions, :account_id")
      expect(content).not_to include(":user_id")
      expect(content).not_to include(":host_user_id")
    end

    it "creates billing_invoices migration with customer_ref + subscription_ref columns" do
      pattern = File.join(destination_root, "engines/billing/db/migrate", "*_create_billing_invoices.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :billing_invoices")
      [
        ":customer_ref",
        ":subscription_ref",
        ":amount_cents",
        ":paid_at"
      ].each { |needle| expect(content).to include(needle) }
      expect(content).to match(/add_index :billing_invoices, :gateway_ref,\s+unique: true/)
    end

    it "billing_invoices has account_id (uuid)" do
      pattern = File.join(destination_root, "engines/billing/db/migrate", "*_create_billing_invoices.rb")
      content = File.read(Dir[pattern].first)
      expect(content).to match(/t\.uuid\s+:account_id,\s+null: false/)
      expect(content).to include("add_index :billing_invoices, :account_id")
      expect(content).not_to include(":user_id")
      expect(content).not_to include(":host_user_id")
    end

    it "billing_lifetime_passes has account_id (uuid)" do
      content = read_lifetime_passes_migration
      expect(content).to match(/t\.uuid\s+:account_id,\s+null: false/)
    end

    it "billing_lifetime_passes renames granted_by/revoked_by columns to identity-scoped" do
      content = read_lifetime_passes_migration
      expect(content).to include(":granted_by_identity_id")
      expect(content).to include(":revoked_by_identity_id")
    end

    it "billing_lifetime_passes has no user_id-flavoured stale columns" do
      content = read_lifetime_passes_migration
      %i[granted_by_user_id revoked_by_user_id user_id host_user_id].each do |stale|
        expect(content).not_to include(":#{stale}")
      end
    end

    def read_lifetime_passes_migration
      pattern = File.join(destination_root, "engines/billing/db/migrate",
                          "*_create_billing_lifetime_passes.rb")
      File.read(Dir[pattern].first)
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

    it "creates billing_plans migration" do
      pattern = File.join(destination_root,
                          "engines/billing/db/migrate",
                          "*_create_billing_plans.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :billing_plans")
      expect(content).to include("amount_cents")
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

  describe "Lifetime Deals (LTD)" do
    it "Plan adds 'lifetime' to INTERVALS + ships scopes + helpers" do
      assert_file "engines/billing/app/models/billing/plan.rb" do |content|
        expect(content).to include("%w[day week month year lifetime]")
        expect(content).to include("scope :lifetime")
        expect(content).to include("def lifetime?")
        expect(content).to include("def lifetime_inventory_remaining")
        expect(content).to include("def lifetime_sold_out?")
      end
    end

    it "create_billing_plans migration adds max_lifetime_units column" do
      assert_file(Dir.glob(File.join(destination_root, "engines/billing/db/migrate/*_create_billing_plans.rb")).first.then { |f| f.sub("#{destination_root}/", "") }) do |content|
        expect(content).to include(":max_lifetime_units")
      end
    end

    it "ships LifetimePass model + dedicated migration with unique (account_id, plan_ref)" do
      # Post-Wave-9: the unique constraint is on (account_id, plan_ref)
      # because the entitlement belongs to the tenant Account, not to
      # the gateway-side customer record.
      assert_file "engines/billing/app/models/billing/lifetime_pass.rb" do |content|
        expect(content).to include("class LifetimePass < ApplicationRecord")
        expect(content).to include("self.table_name = \"billing_lifetime_passes\"")
        expect(content).to include("validates :account_id, uniqueness: { scope: :plan_ref")
      end
      ltd_migration = Dir.glob(File.join(destination_root, "engines/billing/db/migrate/*_create_billing_lifetime_passes.rb")).first
      expect(ltd_migration).not_to be_nil
      expect(File.read(ltd_migration)).to include("name: \"index_billing_ltd_unique\"")
    end

    it "Stripe gateway gains create_lifetime_checkout_session with mode: payment" do
      assert_file "engines/billing/lib/billing/gateways/stripe.rb" do |content|
        expect(content).to include("def create_lifetime_checkout_session")
        expect(content).to include('mode:        "payment"')
        expect(content).to include('access_type: "lifetime"')
      end
    end

    it "ships all four LTD service classes" do
      %w[
        grant_pass_service
        revoke_pass_service
        create_pass_from_checkout_service
        create_lifetime_session_service
      ].each do |svc|
        assert_file "engines/billing/app/services/billing/lifetime/#{svc}.rb"
      end
    end

    it "registers the three new lifetime canonical events" do
      assert_file "engines/billing/lib/billing/engine.rb" do |content|
        expect(content).to include("lifetime.granted.billing")
        expect(content).to include("lifetime.purchased.billing")
        expect(content).to include("lifetime.revoked.billing")
      end
    end

    it "CheckoutSessionCompletedHandler forks on mode + metadata.access_type for LTDs" do
      assert_file "engines/billing/app/services/billing/webhooks/handlers/checkout_session_completed_handler.rb" do |content|
        [
          "class CheckoutSessionCompletedHandler",
          "Billing::Lifetime::CreatePassFromCheckoutService",
          "mode_value",
          "access_type"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Billable concern adds LTD helpers (lifetime?, has_lifetime_for?, has_active_billing?)" do
      assert_file "engines/billing/lib/billing/concerns/billable.rb" do |content|
        expect(content).to include("def lifetime?")
        expect(content).to include("def has_lifetime_for?")
        expect(content).to include("def has_active_billing?")
      end
    end

    it "PlansController + index view split recurring vs lifetime" do
      assert_file "engines/billing/app/controllers/billing/plans_controller.rb" do |content|
        expect(content).to include("@recurring_plans")
        expect(content).to include("@lifetime_plans")
      end
      assert_file "engines/billing/app/views/billing/plans/index.html.erb" do |content|
        expect(content).to include("Lifetime — buy once")
        expect(content).to include("lifetime_inventory_remaining")
      end
    end

    it "CheckoutController gains #lifetime + route is /checkout/lifetime" do
      assert_file "engines/billing/app/controllers/billing/checkout_controller.rb" do |content|
        expect(content).to include("def lifetime")
        expect(content).to include("Billing::Lifetime::CreateLifetimeSessionService")
      end
      assert_file "engines/billing/config/routes.rb" do |content|
        expect(content).to match(%r{post\s+"/checkout/lifetime",\s+to:\s+"checkout#lifetime"})
      end
    end

    it "ships admin grant controller + index/new views + admin route namespace" do
      assert_file "engines/billing/app/controllers/billing/admin/lifetime_passes_controller.rb"
      assert_file "engines/billing/app/views/billing/admin/lifetime_passes/index.html.erb"
      assert_file "engines/billing/app/views/billing/admin/lifetime_passes/new.html.erb"
      assert_file "engines/billing/config/routes.rb" do |content|
        expect(content).to include("namespace :admin")
        expect(content).to include("resources :lifetime_passes")
      end
    end

    it "documents the LTD trade-off in README" do
      assert_file "engines/billing/README.md" do |content|
        expect(content).to include("Lifetime Deals (LTD)")
        expect(content).to include("Trade-off")
        expect(content).to include("max_lifetime_units")
      end
    end

    it "Plan defines SoldOut + enforce_lifetime_inventory_or_raise! with row lock" do
      assert_file "engines/billing/app/models/billing/plan.rb" do |content|
        expect(content).to include("class SoldOut < StandardError")
        expect(content).to include("def enforce_lifetime_inventory_or_raise!")
        # Pessimistic row lock — without this the count check is racey.
        expect(content).to include("lock!")
        expect(content).to include("raise SoldOut")
      end
    end

    it "CreateLifetimeSessionService wraps inventory check + Stripe call in a transaction with row lock" do
      assert_file "engines/billing/app/services/billing/lifetime/create_lifetime_session_service.rb" do |content|
        # Transaction boundary holds the row lock until commit.
        expect(content).to include("Billing::Plan.transaction")
        # Lock-and-check happens INSIDE the transaction.
        expect(content).to include("enforce_lifetime_inventory_or_raise!")
        # Stripe Checkout creation happens INSIDE the same transaction
        # so the lock spans the API call.
        expect(content).to include("create_lifetime_checkout_session")
        # Sold-out raise is converted to a Result failure for the caller.
        expect(content).to include("rescue Billing::Plan::SoldOut")
      end
    end

    it "ships a Plan model spec covering the inventory lock" do
      assert_file "engines/billing/spec/models/billing/plan_spec.rb" do |content|
        expect(content).to include("RSpec.describe Billing::Plan")
        expect(content).to include("#enforce_lifetime_inventory_or_raise!")
        expect(content).to include("Billing::Plan::SoldOut")
      end
    end
  end

  describe "Phase 3 (1/4) — service foundation" do
    it "ships Billing::ServiceResult with ok/failure constructors" do
      assert_file "engines/billing/app/services/billing/service_result.rb" do |content|
        [
          "ServiceResult = Struct.new",
          "def self.ok",
          "def self.failure",
          "def ok?",
          "def failure?"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships Billing::StripeService base class with uniform error mapping" do
      assert_file "engines/billing/app/services/billing/stripe_service.rb" do |content|
        [
          "class StripeService",
          "def call_stripe",
          "rescue Billing::GatewayError",
          "classify_gateway_error",
          ":gateway_unreachable",
          ":gateway_auth",
          ":gateway_error"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships Billing::CurrencyHelper with zero-decimal awareness" do
      assert_file "engines/billing/app/helpers/billing/currency_helper.rb" do |content|
        [
          "module CurrencyHelper",
          "ZERO_DECIMAL",
          "JPY",
          "format_money"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "Phase 3 (1/4) — spec scaffolding" do
    it "ships FactoryBot factories for plan + subscription + invoice + lifetime_pass + webhook_event" do
      assert_file "engines/billing/spec/factories/billing.rb" do |content|
        %w[
          billing_plan
          billing_lifetime_plan
          billing_subscription
          billing_invoice
          billing_lifetime_pass
          billing_webhook_event
        ].each { |name| expect(content).to include("factory :#{name}") }
      end
    end

    it "ships StripeHelpers webmock module" do
      assert_file "engines/billing/spec/support/stripe_helpers.rb" do |content|
        [
          "module StripeHelpers",
          "STRIPE_BASE",
          "WebMock.stub_request",
          "stub_stripe_fixture",
          "stripe_event_fixture"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships 13 Stripe event fixtures covering the full webhook surface" do
      %w[
        customer_subscription_created customer_subscription_updated
        customer_subscription_deleted customer_subscription_trial_will_end
        invoice_created invoice_paid invoice_payment_failed
        invoice_finalized invoice_voided
        payment_intent_succeeded payment_intent_payment_failed
        charge_refunded checkout_session_completed
      ].each do |name|
        assert_file "engines/billing/spec/fixtures/stripe/#{name}.json"
      end
    end
  end

  describe "Phase 3 (1/4) — --gateway flag" do
    let(:gateway_destination) { File.expand_path("../../../tmp/billing_gateway_flag", __dir__) }

    def run_billing_with(gateway)
      FileUtils.rm_rf(gateway_destination)
      FileUtils.mkdir_p(gateway_destination)
      FileUtils.mkdir_p(File.join(gateway_destination, "engines"))
      described_class.start(["--gateway=#{gateway}"], destination_root: gateway_destination)
    end

    it "default ships Stripe; the configuration's @gateway points at the Stripe class" do
      content = File.read(File.join(destination_root,
                                    "engines/billing/lib/billing/configuration.rb"))
      expect(content).to include('@gateway                = "Billing::Gateways::Stripe"')
      expect(content).to include("STRIPE_SECRET_KEY")

      expect(File.exist?(File.join(destination_root,
                                   "engines/billing/lib/billing/gateways/paddle.rb"))).to be(false)
      expect(File.exist?(File.join(destination_root,
                                   "engines/billing/lib/billing/gateways/adyen.rb"))).to be(false)
    end

    it "--gateway=paddle ships the Paddle stub + points configuration at it" do
      run_billing_with("paddle")

      paddle_path = File.join(gateway_destination,
                              "engines/billing/lib/billing/gateways/paddle.rb")
      expect(File.exist?(paddle_path)).to be(true)

      config = File.read(File.join(gateway_destination,
                                   "engines/billing/lib/billing/configuration.rb"))
      expect(config).to include('@gateway                = "Billing::Gateways::Paddle"')
      expect(config).to include("PADDLE_SECRET_KEY")
    end

    it "--gateway=garbage falls back to Stripe (no surprising half-installed engine)" do
      run_billing_with("garbage")

      config = File.read(File.join(gateway_destination,
                                   "engines/billing/lib/billing/configuration.rb"))
      expect(config).to include('@gateway                = "Billing::Gateways::Stripe"')
    end

    it "wire_into_host adds factory_bot_rails + webmock to the test group" do
      gen_path = File.expand_path("../../../lib/generators/seams/billing/billing_generator.rb",
                                  __dir__)
      content  = File.read(gen_path)
      expect(content).to include('host_inject_gem("factory_bot_rails"')
      expect(content).to include('host_inject_gem("webmock"')
    end
  end

  describe "Phase 3 (2/4) — service objects" do
    it "ships Customers::FindOrCreateService that searches then creates" do
      assert_file "engines/billing/app/services/billing/customers/find_or_create_service.rb" do |content|
        [
          "class FindOrCreateService < Billing::StripeService",
          "client.search_customers",
          "client.create_customer",
          "ServiceResult.ok(value: stripe_response[:id])"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Customers::FindOrCreateService passes a deterministic Idempotency-Key to create_customer" do
      # Stripe's customer-search index is eventually consistent
      # (https://docs.stripe.com/api/customers/search) so two
      # concurrent signups can both miss + both POST. The fix:
      # SHA-256(email:scope) → Stripe Idempotency-Key header
      # (https://docs.stripe.com/api/idempotent_requests).
      # Post-Wave-9 the scope is `account_id` — the tenant the
      # Stripe customer represents — so two members of the same
      # Account who happen to share an email don't get two
      # customers, and two members of *different* Accounts with the
      # same email do get separate customers (one per tenant).
      assert_file "engines/billing/app/services/billing/customers/find_or_create_service.rb" do |content|
        [
          'require "digest"',
          "idempotency_key: idempotency_key",
          "def idempotency_key",
          "Digest::SHA256.hexdigest",
          "seams:billing:customer:",
          "@metadata[:account_id]",
          "docs.stripe.com/api/idempotent_requests"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Stripe::Client#create_customer accepts idempotency_key + forwards it to the SDK opts hash" do
      assert_file "engines/billing/lib/billing/stripe/client.rb" do |content|
        [
          "def create_customer(email:, idempotency_key: nil, **extra)",
          "{ idempotency_key: idempotency_key }",
          "sdk.v1.customers.create(body, opts)",
          "docs.stripe.com/api/idempotent_requests"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships Subscriptions::CancelService with end-of-period default + immediate switch" do
      assert_file "engines/billing/app/services/billing/subscriptions/cancel_service.rb" do |content|
        [
          "class CancelService < Billing::StripeService",
          "@immediate",
          "client.cancel_subscription",
          "client.update_subscription",
          "cancel_at_period_end: true"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships Subscriptions::ChangePlanService that retrieves the existing item then updates" do
      assert_file "engines/billing/app/services/billing/subscriptions/change_plan_service.rb" do |content|
        [
          "class ChangePlanService < Billing::StripeService",
          "client.retrieve_subscription",
          "client.update_subscription",
          "proration_behavior",
          "code: :invalid_state"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships Subscriptions::ReactivateService that flips cancel_at_period_end" do
      assert_file "engines/billing/app/services/billing/subscriptions/reactivate_service.rb" do |content|
        [
          "class ReactivateService < Billing::StripeService",
          "cancel_at_period_end: false"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships Invoices::SyncService that upserts the local Billing::Invoice row" do
      assert_file "engines/billing/app/services/billing/invoices/sync_service.rb" do |content|
        [
          "class SyncService < Billing::StripeService",
          "client.retrieve_invoice",
          "Billing::Invoice.find_or_initialize_by",
          "amount_paid",
          "amount_due"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Stripe::Client gains create_customer / search_customers / update_subscription / retrieve_invoice" do
      assert_file "engines/billing/lib/billing/stripe/client.rb" do |content|
        [
          "def create_customer",
          "def search_customers",
          "def update_subscription",
          "def retrieve_invoice",
          "/v1/customers/search",
          "/v1/invoices/"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "Phase 3 (3/4) — webhook router + handler classes" do
    it "ships the Webhooks::Handler base class" do
      assert_file "engines/billing/app/services/billing/webhooks/handler.rb" do |content|
        [
          "class Handler",
          "SEAMS_EVENT = nil",
          "def call",
          "def publish",
          "def object_hash",
          "def customer_ref",
          "Seams::Events::Publisher.publish"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Webhooks::EventRouter exposes register + handler_for" do
      assert_file "engines/billing/app/services/billing/webhooks/event_router.rb" do |content|
        ["module EventRouter", "def register", "def handler_for"].each do |needle|
          expect(content).to include(needle)
        end
      end
    end

    BILLING_EVENT_ROUTER_NEEDLES.each do |stripe_event|
      it "Webhooks::EventRouter maps #{stripe_event}" do
        assert_file "engines/billing/app/services/billing/webhooks/event_router.rb" do |content|
          expect(content).to include(stripe_event)
        end
      end
    end

    it "ships SubscriptionHandlerBase with the upsert" do
      assert_file "engines/billing/app/services/billing/webhooks/handlers/subscription_handler_base.rb" do |content|
        expect(content).to include("class SubscriptionHandlerBase < Billing::Webhooks::Handler")
        expect(content).to include("upsert_subscription")
      end
    end

    BILLING_SUBSCRIPTION_LEAF_HANDLERS.each do |basename, seams_event|
      it "ships subscription handler: #{basename}" do
        assert_file "engines/billing/app/services/billing/webhooks/handlers/#{basename}.rb" do |content|
          expect(content).to include("< SubscriptionHandlerBase")
          expect(content).to include(%(SEAMS_EVENT = "#{seams_event}"))
        end
      end
    end

    it "ships InvoiceHandlerBase with the upsert" do
      assert_file "engines/billing/app/services/billing/webhooks/handlers/invoice_handler_base.rb" do |content|
        expect(content).to include("class InvoiceHandlerBase < Billing::Webhooks::Handler")
        expect(content).to include("upsert_invoice")
      end
    end

    BILLING_INVOICE_LEAF_HANDLERS.each do |basename, (seams_event, status)|
      it "ships invoice handler: #{basename}" do
        assert_file "engines/billing/app/services/billing/webhooks/handlers/#{basename}.rb" do |content|
          expect(content).to include("< InvoiceHandlerBase")
          expect(content).to include(%(SEAMS_EVENT    = "#{seams_event}"))
          expect(content).to include(%(INVOICE_STATUS = "#{status}"))
        end
      end
    end

    BILLING_STANDALONE_HANDLERS.each do |basename, seams_event|
      it "ships standalone handler: #{basename}" do
        assert_file "engines/billing/app/services/billing/webhooks/handlers/#{basename}.rb" do |content|
          expect(content).to include("< Billing::Webhooks::Handler")
          expect(content).to include(%(SEAMS_EVENT = "#{seams_event}"))
        end
      end
    end

    it "ships Webhooks::ProcessEventJob for opt-in async dispatch" do
      assert_file "engines/billing/app/jobs/billing/webhooks/process_event_job.rb" do |content|
        [
          "class ProcessEventJob < Billing::ApplicationJob",
          "queue_as :billing",
          "Billing::Webhooks::EventRouter.handler_for",
          "handler.new(event: event, gateway: gateway).call"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "WebhooksController shrinks to a router glue layer" do
      assert_file "engines/billing/app/controllers/billing/webhooks_controller.rb" do |content|
        [
          "Billing::Webhooks::EventRouter.handler_for",
          "Billing::Webhooks::ProcessEventJob.perform_later",
          "Billing.configuration.process_webhooks_async"
        ].each { |needle| expect(content).to include(needle) }
        # Old inline machinery should be gone.
        %w[EVENT_MAP customer_ref_for ref_for upsert_local_record checkout_lifetime?].each do |needle|
          expect(content).not_to include(needle)
        end
      end
    end

    BILLING_REGISTERED_EVENTS.each do |event_name|
      it "engine.rb registers #{event_name}" do
        assert_file "engines/billing/lib/billing/engine.rb" do |content|
          expect(content).to include(event_name)
        end
      end
    end

    it "Configuration ships process_webhooks_async (default false)" do
      assert_file "engines/billing/lib/billing/configuration.rb" do |content|
        expect(content).to include(":process_webhooks_async")
        expect(content).to include("@process_webhooks_async = false")
      end
    end

    it "ships a runtime spec that exercises every webhook handler against its fixture" do
      # Catches regressions in SubscriptionHandlerBase#upsert_subscription
      # or InvoiceHandlerBase#upsert_invoice; needles are file-scope.
      assert_file "engines/billing/spec/runtime/webhook_handlers_spec.rb" do |content|
        BILLING_HANDLER_RUNTIME_NEEDLES.each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "Phase 3 (4/4) — self-service controllers + views + routes" do
    it "ships SubscriptionsController with index/show/cancel/reactivate/change_plan" do
      assert_file "engines/billing/app/controllers/billing/subscriptions_controller.rb" do |content|
        [
          "class SubscriptionsController",
          "def index",
          "def show",
          "def cancel",
          "def reactivate",
          "def change_plan",
          "Billing::Subscriptions::CancelService.call",
          "Billing::Subscriptions::ReactivateService.call",
          "Billing::Subscriptions::ChangePlanService.call",
          "current_billing_customer_ref"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships InvoicesController with read-only index/show" do
      assert_file "engines/billing/app/controllers/billing/invoices_controller.rb" do |content|
        [
          "class InvoicesController",
          "def index",
          "def show",
          "Billing::Invoice.where",
          "current_billing_customer_ref"
        ].each { |needle| expect(content).to include(needle) }
        ["def create", "def update", "def destroy", "def download"].each do |needle|
          expect(content).not_to include(needle.tr("\\", ""))
        end
      end
    end

    it "ships index + show views for both controllers" do
      %w[
        engines/billing/app/views/billing/subscriptions/index.html.erb
        engines/billing/app/views/billing/subscriptions/show.html.erb
        engines/billing/app/views/billing/invoices/index.html.erb
        engines/billing/app/views/billing/invoices/show.html.erb
      ].each { |path| assert_file path }
    end

    it "registers the new routes (subscriptions + invoices) on Billing::Engine" do
      assert_file "engines/billing/config/routes.rb" do |content|
        [
          "resources :subscriptions",
          "resources :invoices",
          "delete :cancel",
          "post   :reactivate",
          "post   :change_plan"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "Phase 3 (4/4) — gateway contract shared_examples" do
    it 'ships the "a billing gateway" shared example covering the full Abstract contract' do
      assert_file "engines/billing/spec/support/shared_examples/a_billing_gateway.rb" do |content|
        [
          'RSpec.shared_examples "a billing gateway"',
          "#create_subscription",
          "#cancel_subscription",
          "#fetch_subscription",
          "#create_checkout_session",
          "#create_billing_portal_session",
          "#create_lifetime_checkout_session",
          "#verify_webhook",
          "Billing::WebhookError"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "Stripe gateway runs the contract spec via it_behaves_like" do
      assert_file "engines/billing/spec/gateways/billing/contract_spec.rb" do |content|
        expect(content).to include("RSpec.describe Billing::Gateways::Stripe")
        expect(content).to include('it_behaves_like "a billing gateway"')
      end
    end
  end

  describe "Phase 3 (4/4) — README updates" do
    it "documents handler routing + the EventRouter.register extension point" do
      assert_file "engines/billing/README.md" do |content|
        [
          "Billing::Webhooks::EventRouter.register",
          "process_webhooks_async",
          "SubscriptionCreatedHandler",
          "InvoicePaidHandler",
          "CheckoutSessionCompletedHandler"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "documents the self-service controllers" do
      assert_file "engines/billing/README.md" do |content|
        [
          "Billing::SubscriptionsController",
          "Billing::InvoicesController",
          "current_billing_customer_ref",
          "Self-service controllers"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "documents the Stripe Checkout test-mode walkthrough" do
      assert_file "engines/billing/README.md" do |content|
        [
          "Verifying the Stripe Checkout flow against test mode",
          "stripe listen --forward-to",
          "4242 4242 4242 4242",
          "Billing::WebhookEvent.where"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "documents the gateway contract shared_examples usage" do
      assert_file "engines/billing/README.md" do |content|
        [
          "Gateway contract specs",
          'it_behaves_like "a billing gateway"'
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end
end
