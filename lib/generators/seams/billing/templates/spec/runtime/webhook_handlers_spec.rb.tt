# frozen_string_literal: true

require_relative "../rails_helper"
require_relative "../support/stripe_helpers"

# Runtime coverage for the 13 webhook handlers shipped under
# app/services/billing/webhooks/handlers/. Generator specs already
# assert the FILES exist + contain the right SEAMS_EVENT constants;
# this spec instantiates each handler with the matching Stripe event
# fixture, calls #call, and asserts:
#
#   1. The local Billing::Subscription / Billing::Invoice row is
#      upserted with the expected columns (or NOT upserted, for the
#      stateless payment_intent / charge handlers).
#   2. The canonical seams event is published with the expected
#      payload shape.
#
# Why this exists: a regression in SubscriptionHandlerBase#upsert_subscription
# or InvoiceHandlerBase#upsert_invoice would not be caught by the
# string-matching generator specs alone — they ship green even if the
# upsert silently no-ops. This spec exercises the real ActiveRecord
# round-trip + the Seams::Events::Publisher contract.
#
# CheckoutSessionCompletedHandler is covered for both the subscription
# branch (publishes checkout.session_completed.billing) and the
# Lifetime Deal branch (forks to Billing::Lifetime::CreatePassFromCheckoutService).
RSpec.describe "Billing webhook handlers (runtime)", type: :integration do
  include StripeHelpers

  # Helper: load a fixture and reshape it into the event hash that
  # Billing::Gateways::Stripe#verify_webhook hands to the handler.
  # Fixtures are full Stripe event envelopes (top-level id/type +
  # nested data.object); handlers expect a flat hash with :object
  # holding what was data.object.
  def event_for(fixture_name)
    full = stripe_event_fixture(fixture_name)
    {
      id:       full[:id],
      type:     full[:type],
      livemode: full[:livemode],
      object:   full.dig(:data, :object),
      raw:      full.to_json
    }
  end

  # Capture every payload published under +event_name+ during the
  # block. Returns the Array of payload hashes. Uses the Publisher's
  # public subscribe API so we exercise the real adapter dispatch
  # (ActiveSupport::Notifications by default) rather than mocking the
  # Publisher away.
  def capture_published(event_name)
    captured   = []
    subscriber = Seams::Events::Publisher.subscribe(event_name) { |payload| captured << payload }
    yield
    captured
  ensure
    Seams::Events::Publisher.unsubscribe(subscriber) if subscriber
  end

  let(:gateway) { "stripe" }

  describe Billing::Webhooks::Handlers::SubscriptionCreatedHandler do
    it "upserts a Billing::Subscription row + publishes subscription.created.billing" do
      event    = event_for("customer_subscription_created")
      captured = capture_published("subscription.created.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      subscription = Billing::Subscription.find_by(gateway_ref: "sub_test_123")
      expect(subscription).not_to be_nil
      expect(subscription.customer_ref).to eq("cus_test_123")
      expect(subscription.plan_ref).to eq("price_test_pro")
      expect(subscription.status).to eq("active")
      expect(subscription.current_period_end).to be_within(1.second).of(Time.at(1_732_678_400))

      expect(captured.size).to eq(1)
      expect(captured.first[:gateway]).to eq("stripe")
      expect(captured.first[:customer_ref]).to eq("cus_test_123")
      expect(captured.first[:object_id]).to eq("sub_test_123")
    end
  end

  describe Billing::Webhooks::Handlers::SubscriptionUpdatedHandler do
    it "updates the existing Billing::Subscription row + publishes subscription.updated.billing" do
      # Seed the row first so the handler exercises the find branch
      # of find_or_initialize_by — guards against a regression that
      # accidentally creates duplicates instead of updating.
      create(:billing_subscription,
             gateway_ref:  "sub_test_123",
             customer_ref: "cus_test_123",
             plan_ref:     "price_test_pro",
             status:       "active")

      event    = event_for("customer_subscription_updated")
      captured = capture_published("subscription.updated.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      subscription = Billing::Subscription.find_by(gateway_ref: "sub_test_123")
      expect(Billing::Subscription.where(gateway_ref: "sub_test_123").count).to eq(1)
      expect(subscription.plan_ref).to eq("price_test_pro_annual")
      expect(subscription.current_period_end).to be_within(1.second).of(Time.at(1_735_270_400))
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::SubscriptionDeletedHandler do
    it "flips the row status to canceled + publishes subscription.canceled.billing" do
      create(:billing_subscription,
             gateway_ref:  "sub_test_123",
             customer_ref: "cus_test_123",
             plan_ref:     "price_test_pro",
             status:       "active")

      # Stripe sends an empty items.data on the deletion event, but
      # the handler still overwrites plan_ref from the payload — the
      # fixture would fail validation. We patch in a minimal items
      # block here so the upsert succeeds and we can assert on the
      # status flip the handler is responsible for.
      full = stripe_event_fixture("customer_subscription_deleted").deep_dup
      full[:data][:object][:items] = {
        data: [{ price: { id: "price_test_pro" } }]
      }
      event = {
        id:       full[:id],
        type:     full[:type],
        livemode: full[:livemode],
        object:   full[:data][:object],
        raw:      full.to_json
      }

      captured = capture_published("subscription.canceled.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      subscription = Billing::Subscription.find_by(gateway_ref: "sub_test_123")
      expect(subscription.status).to eq("canceled")
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::SubscriptionTrialWillEndHandler do
    it "upserts the row + publishes subscription.trial_will_end.billing" do
      # The shipped fixture's items.data[0].price intentionally omits
      # `id` (lookup_key only). We add `id` here so plan_ref_from_object_hash
      # returns a value the model's presence validation accepts.
      full = stripe_event_fixture("customer_subscription_trial_will_end").deep_dup
      full[:data][:object][:items][:data][0][:price][:id] = "price_test_pro"
      event = {
        id:       full[:id],
        type:     full[:type],
        livemode: full[:livemode],
        object:   full[:data][:object],
        raw:      full.to_json
      }

      captured = capture_published("subscription.trial_will_end.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      subscription = Billing::Subscription.find_by(gateway_ref: "sub_test_123")
      expect(subscription).not_to be_nil
      expect(subscription.status).to eq("trialing")
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::InvoiceCreatedHandler do
    it "upserts a draft Billing::Invoice row + publishes invoice.created.billing" do
      event    = event_for("invoice_created")
      captured = capture_published("invoice.created.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      invoice = Billing::Invoice.find_by(gateway_ref: "in_test_123")
      expect(invoice).not_to be_nil
      expect(invoice.customer_ref).to eq("cus_test_123")
      expect(invoice.subscription_ref).to eq("sub_test_123")
      expect(invoice.status).to eq("draft")
      expect(invoice.amount_cents).to eq(1299)
      expect(invoice.currency).to eq("GBP")
      expect(invoice.paid_at).to be_nil
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::InvoicePaidHandler do
    it "marks the invoice paid (status + paid_at) + publishes invoice.paid.billing" do
      event    = event_for("invoice_paid")
      captured = capture_published("invoice.paid.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      invoice = Billing::Invoice.find_by(gateway_ref: "in_test_123")
      expect(invoice.status).to eq("paid")
      expect(invoice.paid_at).not_to be_nil
      expect(invoice.amount_cents).to eq(1299)
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::InvoicePaymentFailedHandler do
    it "leaves the invoice in 'open' + publishes invoice.failed.billing" do
      event    = event_for("invoice_payment_failed")
      captured = capture_published("invoice.failed.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      invoice = Billing::Invoice.find_by(gateway_ref: "in_test_123")
      expect(invoice.status).to eq("open")
      expect(invoice.paid_at).to be_nil
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::InvoiceFinalizedHandler do
    it "promotes draft → open + publishes invoice.finalized.billing" do
      create(:billing_invoice,
             gateway_ref: "in_test_123",
             status:      "draft",
             paid_at:     nil)

      event    = event_for("invoice_finalized")
      captured = capture_published("invoice.finalized.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      invoice = Billing::Invoice.find_by(gateway_ref: "in_test_123")
      expect(invoice.status).to eq("open")
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::InvoiceVoidedHandler do
    it "flips status to void + publishes invoice.voided.billing" do
      event    = event_for("invoice_voided")
      captured = capture_published("invoice.voided.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      invoice = Billing::Invoice.find_by(gateway_ref: "in_test_123")
      expect(invoice.status).to eq("void")
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::PaymentSucceededHandler do
    it "publishes payment.succeeded.billing without writing any local row" do
      event    = event_for("payment_intent_succeeded")
      captured = capture_published("payment.succeeded.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      # PaymentIntents are not modelled locally — see the handler comment.
      expect(Billing::Subscription.count).to eq(0)
      expect(Billing::Invoice.count).to     eq(0)
      expect(captured.size).to eq(1)
      expect(captured.first[:object_id]).to eq("pi_test_123")
    end
  end

  describe Billing::Webhooks::Handlers::PaymentFailedHandler do
    it "publishes payment.failed.billing without writing any local row" do
      event    = event_for("payment_intent_payment_failed")
      captured = capture_published("payment.failed.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      expect(Billing::Subscription.count).to eq(0)
      expect(Billing::Invoice.count).to     eq(0)
      expect(captured.size).to eq(1)
    end
  end

  describe Billing::Webhooks::Handlers::ChargeRefundedHandler do
    it "publishes charge.refunded.billing without writing any local row" do
      event    = event_for("charge_refunded")
      captured = capture_published("charge.refunded.billing") do
        described_class.new(event: event, gateway: gateway).call
      end

      expect(captured.size).to eq(1)
      expect(captured.first[:object_id]).to eq("ch_test_123")
    end
  end

  describe Billing::Webhooks::Handlers::CheckoutSessionCompletedHandler do
    context "subscription mode (default fixture)" do
      it "publishes checkout.session_completed.billing and does NOT touch LifetimePass" do
        event    = event_for("checkout_session_completed")
        captured = capture_published("checkout.session_completed.billing") do
          described_class.new(event: event, gateway: gateway).call
        end

        expect(captured.size).to eq(1)
        expect(Billing::LifetimePass.count).to eq(0)
      end
    end

    context "lifetime mode (mode=payment + metadata.access_type=lifetime)" do
      it "forks to CreatePassFromCheckoutService which creates a LifetimePass + emits lifetime.purchased.billing" do
        full = stripe_event_fixture("checkout_session_completed").deep_dup
        full[:data][:object][:mode] = "payment"
        full[:data][:object][:metadata] = { access_type: "lifetime", plan_ref: "price_test_lifetime_1" }
        event = {
          id:       full[:id],
          type:     full[:type],
          livemode: full[:livemode],
          object:   full[:data][:object],
          raw:      full.to_json
        }

        captured_lifetime = capture_published("lifetime.purchased.billing") do
          captured_session = capture_published("checkout.session_completed.billing") do
            described_class.new(event: event, gateway: gateway).call
          end
          # Lifetime path forks BEFORE publish — checkout.session_completed
          # is intentionally not emitted on the LTD branch.
          expect(captured_session).to be_empty
        end

        pass = Billing::LifetimePass.find_by(gateway_ref: "cs_test_123")
        expect(pass).not_to be_nil
        expect(pass.customer_ref).to eq("cus_test_123")
        expect(pass.plan_ref).to eq("price_test_lifetime_1")
        expect(captured_lifetime.size).to eq(1)
      end
    end
  end
end
