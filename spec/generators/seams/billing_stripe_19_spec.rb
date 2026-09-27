# frozen_string_literal: true

require "json"
require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/billing/billing_generator"

# The billing engine targets stripe-ruby ~> 19, which pins API version
# 2026-08-26.dahlia. These specs pin the generated code to that gem's
# surface and to the post-2025-03-31.basil payload shapes:
#
#   - invoice.subscription           -> invoice.parent.subscription_details.subscription
#   - subscription.current_period_*  -> items.data[].current_period_*
#   - ::Stripe::StripeObject has no #dig (NoMethodError on SDK responses)
#   - Stripe::Webhook.construct_event raises ArgumentError on v2 thin events
#   - ::Stripe::StripeError must surface as Billing::GatewayError
RSpec.describe Seams::Generators::BillingGenerator do
  describe "stripe-ruby 19" do
    let(:destination_root) { File.expand_path("../../../tmp/billing_stripe_19", __dir__) }
    let(:engine_root)      { File.join(destination_root, "engines/billing") }

    # Stand-in for ::Stripe::StripeObject: symbol-keyed #[] and #keys,
    # and no #dig (the real one raises NoMethodError for dig).
    let(:sdk_object_class) do
      Class.new do
        def initialize(values) = @values = values
        def [](key) = @values[key.to_sym]
        def keys = @values.keys
      end
    end

    before do
      FileUtils.rm_rf(destination_root)
      FileUtils.mkdir_p(File.join(destination_root, "engines"))
      described_class.start([], destination_root: destination_root)
    end

    def read(path)
      full = File.join(engine_root, path)
      expect(File.exist?(full)).to be(true), "expected engines/billing/#{path} to be generated"
      File.read(full)
    end

    def fixture(name)
      JSON.parse(read("spec/fixtures/stripe/#{name}.json"))
    end

    # Loads the generated Payload module into an anonymous namespace so
    # the spec process never defines a top-level ::Billing.
    def payload_module
      sandbox = Module.new
      sandbox.module_eval(read("lib/billing/stripe/payload.rb"), "payload.rb")
      sandbox.const_get(:Billing)::Stripe::Payload
    end

    it "pins the host Gemfile to stripe ~> 19.0" do
      generator_source = File.read(File.expand_path("../../../lib/generators/seams/billing/billing_generator.rb", __dir__))
      expect(generator_source).to include('host_inject_gem("stripe", "~> 19.0")')
      expect(generator_source).not_to include('"~> 13.0"')
    end

    describe "Billing::Stripe::Payload" do
      it "is generated and required by the Stripe gateway" do
        expect(read("lib/billing/stripe/payload.rb")).to include("module Payload")
        expect(read("lib/billing/gateways/stripe.rb")).to include('require "billing/stripe/payload"')
      end

      it "reads the invoice's subscription from parent.subscription_details (current API)" do
        invoice = fixture("invoice_paid")["data"]["object"]
        expect(payload_module.invoice_subscription_ref(invoice)).to eq("sub_test_123")
      end

      it "falls back to the pre-basil top-level invoice.subscription" do
        expect(payload_module.invoice_subscription_ref({ subscription: "sub_old" })).to eq("sub_old")
        expect(payload_module.invoice_subscription_ref({ "subscription" => "sub_old" })).to eq("sub_old")
        expect(payload_module.invoice_subscription_ref({ "id" => "in_1" })).to be_nil
      end

      it "reads an expanded subscription object's id" do
        invoice = { parent: { subscription_details: { subscription: { id: "sub_expanded" } } } }
        expect(payload_module.invoice_subscription_ref(invoice)).to eq("sub_expanded")
      end

      it "reads current_period_end from the first item, then the pre-basil root" do
        subscription = fixture("customer_subscription_created")["data"]["object"]
        expect(payload_module.subscription_current_period_end(subscription)).to eq(1_732_678_400)
        expect(payload_module.subscription_current_period_end({ current_period_end: 5, items: { data: [] } })).to eq(5)
      end

      it "reads invoice paid time from status_transitions.paid_at" do
        invoice = fixture("invoice_paid")["data"]["object"]
        expect(payload_module.invoice_paid_at(invoice)).to eq(1_730_500_000)
      end

      it "walks the verify_webhook shape (string keys on top, symbol keys below)" do
        object = { "parent" => { subscription_details: { subscription: "sub_mixed" } } }
        expect(payload_module.invoice_subscription_ref(object)).to eq("sub_mixed")
      end

      it "walks SDK objects that have no #dig" do
        price = sdk_object_class.new(id: "price_1")
        item  = sdk_object_class.new(current_period_end: 42, price: price)
        list  = sdk_object_class.new(data: [item])
        sub   = sdk_object_class.new(id: "sub_1", items: list)
        expect(sub).not_to respond_to(:dig)

        expect(payload_module.subscription_current_period_end(sub)).to eq(42)
        expect(payload_module.subscription_price_ref(sub)).to eq("price_1")
      end

      it "returns nil instead of raising on scalars in the path" do
        expect(payload_module.dig({ "parent" => "oops" }, :parent, :subscription_details)).to be_nil
        expect(payload_module.dig(nil, :a)).to be_nil
      end
    end

    describe "no Hash#dig on SDK responses" do
      it "keeps generated runtime code off #dig (::Stripe::StripeObject does not define it)" do
        Dir[File.join(engine_root, "{app,lib}/**/*.rb")].each do |path|
          code      = File.readlines(path).reject { |line| line.strip.start_with?("#") }
          offenders = code.grep(/\.dig\(/).grep_v(/Payload\.dig\(/)
          expect(offenders).to be_empty, "#{path} calls #dig: #{offenders.join}"
        end
      end
    end

    describe "handlers and services read the current payload shapes" do
      it "InvoiceHandlerBase reads the subscription via Payload" do
        content = read("app/services/billing/webhooks/handlers/invoice_handler_base.rb")
        expect(content).to include("Billing::Stripe::Payload.invoice_subscription_ref(object_hash)")
        expect(content).to include("Billing::Stripe::Payload.invoice_paid_at(object_hash)")
        expect(content).not_to include('object_hash["subscription"]')
      end

      it "SubscriptionHandlerBase reads the period + price via Payload" do
        content = read("app/services/billing/webhooks/handlers/subscription_handler_base.rb")
        expect(content).to include("Billing::Stripe::Payload.subscription_current_period_end(object_hash)")
        expect(content).to include("Billing::Stripe::Payload.subscription_price_ref(object_hash)")
      end

      it "Invoices::SyncService reads the subscription + paid time via Payload" do
        content = read("app/services/billing/invoices/sync_service.rb")
        expect(content).to include("Billing::Stripe::Payload.invoice_subscription_ref(stripe_response)")
        expect(content).to include("Billing::Stripe::Payload.invoice_paid_at(stripe_response)")
        expect(content).not_to include("stripe_response[:subscription]")
      end

      it "the Stripe gateway normalises subscriptions via Payload" do
        content = read("lib/billing/gateways/stripe.rb")
        expect(content).to include("Billing::Stripe::Payload.subscription_current_period_end(sub)")
        expect(content).to include("Billing::Stripe::Payload.subscription_price_ref(sub)")
      end
    end

    describe "error translation" do
      let(:client) { read("lib/billing/stripe/client.rb") }

      it "wraps every SDK call (and client construction) in translate_errors" do
        code      = client.lines.reject { |line| line.strip.start_with?("#") }
        sdk_calls = code.grep(/sdk\.v1\.|StripeClient\.new/)
        expect(sdk_calls.size).to eq(10)
        expect(sdk_calls).to all(include("translate_errors {"))
      end

      it "re-raises ::Stripe::StripeError subclasses as Billing::GatewayError" do
        expect(client).to include("rescue ::Stripe::APIConnectionError => e")
        expect(client).to include("rescue ::Stripe::AuthenticationError, ::Stripe::PermissionError => e")
        expect(client).to include("rescue ::Stripe::StripeError => e")
      end

      # Runs the generated StripeService#classify_gateway_error regexes
      # over a message, so the prefixes Client emits are proven to land
      # on the intended ServiceResult codes.
      def classify(message)
        service = read("app/services/billing/stripe_service.rb")
        %i[gateway_unreachable gateway_auth].each do |code|
          pattern = Regexp.new(service[%r{when /(.+?)/i\s+then :#{code}}, 1], Regexp::IGNORECASE)
          return code if message.match?(pattern)
        end
        :gateway_error
      end

      it "emits the connection + auth message prefixes" do
        expect(client).to include("\"Stripe connection error: \#{e.message}\"")
        expect(client).to include("\"Stripe authentication error: \#{e.message}\"")
      end

      it "prefixes map to stable StripeService codes" do
        expect(classify("Stripe connection error: timed out")).to eq(:gateway_unreachable)
        expect(classify("Stripe authentication error: Invalid API Key")).to eq(:gateway_auth)
        expect(classify("Stripe InvalidRequestError: No such invoice")).to eq(:gateway_error)
      end
    end

    describe "webhook signature" do
      it "maps stripe-ruby 19's ArgumentError for v2 thin events to Billing::WebhookError" do
        content = read("lib/billing/stripe/webhook_signature.rb")
        expect(content).to include("::Stripe::Webhook.construct_event(payload, signature_header, secret, tolerance: tolerance)")
        expect(content).to include("rescue ArgumentError => e")
      end
    end

    describe "fixtures (API 2026-08-26.dahlia shapes)" do
      let(:removed_invoice_fields) { %w[subscription paid charge payment_intent paid_out_of_band] }
      let(:all_fixtures) do
        %w[
          customer_subscription_created customer_subscription_updated
          customer_subscription_deleted customer_subscription_trial_will_end
          invoice_created invoice_paid invoice_payment_failed invoice_finalized invoice_voided
          payment_intent_succeeded payment_intent_payment_failed charge_refunded checkout_session_completed
        ]
      end

      it "stamps every event with the pinned API version" do
        all_fixtures.each do |name|
          expect(fixture(name)["api_version"]).to eq("2026-08-26.dahlia"), "#{name} api_version"
        end
      end

      it "puts the invoice's subscription under parent.subscription_details, not the top level" do
        %w[invoice_created invoice_paid invoice_payment_failed invoice_finalized invoice_voided].each do |name|
          invoice = fixture(name)["data"]["object"]
          expect(invoice.dig("parent", "type")).to eq("subscription_details")
          expect(invoice.dig("parent", "subscription_details", "subscription")).to eq("sub_test_123")
          expect(invoice).to have_key("status_transitions")
          expect(invoice.keys & removed_invoice_fields).to be_empty, "#{name} has fields removed in basil"
        end
      end

      it "records the paid time on status_transitions.paid_at" do
        invoice = fixture("invoice_paid")["data"]["object"]
        expect(invoice.dig("status_transitions", "paid_at")).to eq(1_730_500_000)
        expect(invoice).not_to have_key("paid_at")
      end

      it "puts the billing period on subscription items, not the subscription" do
        %w[customer_subscription_created customer_subscription_updated
           customer_subscription_deleted customer_subscription_trial_will_end].each do |name|
          subscription = fixture(name)["data"]["object"]
          expect(subscription).not_to have_key("current_period_end"), "#{name} has root current_period_end"
          expect(subscription).not_to have_key("current_period_start"), "#{name} has root current_period_start"
          expect(subscription.dig("items", "data")).to all(include("current_period_start", "current_period_end"))
        end
      end

      it "drops the invoice pointer removed from PaymentIntent and Charge" do
        %w[payment_intent_succeeded payment_intent_payment_failed charge_refunded].each do |name|
          expect(fixture(name)["data"]["object"]).not_to have_key("invoice")
        end
      end
    end

    it "documents the gem pin, API version, and payload fallbacks in the engine README" do
      readme = read("README.md")
      expect(readme).to include('gem "stripe", "~> 19.0"')
      expect(readme).to include("2026-08-26.dahlia")
      expect(readme).to include("invoice.parent.subscription_details.subscription")
      expect(readme).to include("Billing::Stripe::Payload")
    end
  end
end
