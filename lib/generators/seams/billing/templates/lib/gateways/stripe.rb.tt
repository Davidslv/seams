# frozen_string_literal: true

require "billing/gateways/abstract"
require "billing/stripe/client"
require "billing/stripe/webhook_signature"

module Billing
  module Gateways
    # Stripe billing gateway. Implements the Billing::Gateways::Abstract
    # contract on top of the official `stripe` Ruby gem
    # (https://github.com/stripe/stripe-ruby), wrapped in a thin
    # facade at Billing::Stripe::Client so the rest of the engine
    # has one place to call. Webhook signature verification uses
    # Stripe::Webhook.construct_event from the same gem rather than
    # a hand-rolled HMAC. Wave 8's earlier decision to roll a Faraday
    # client was reversed in 2026-05 — the gem is actively maintained
    # by Stripe and tracking their API ourselves wasn't worth the
    # centralisation benefit Faraday alone provided.
    #
    # API surface used (verified against current Stripe docs):
    #   POST   /v1/customers                   https://docs.stripe.com/api/customers/create
    #   GET    /v1/customers/search            https://docs.stripe.com/api/customers/search
    #   POST   /v1/subscriptions               https://docs.stripe.com/api/subscriptions/create
    #   POST   /v1/subscriptions/{id}          https://docs.stripe.com/api/subscriptions/update
    #   DELETE /v1/subscriptions/{id}          https://docs.stripe.com/api/subscriptions/cancel
    #   GET    /v1/subscriptions/{id}          https://docs.stripe.com/api/subscriptions/retrieve
    #   GET    /v1/invoices/{id}               https://docs.stripe.com/api/invoices/retrieve
    #   POST   /v1/checkout/sessions           https://docs.stripe.com/api/checkout/sessions/create
    #   POST   /v1/billing_portal/sessions     https://docs.stripe.com/api/customer_portal/sessions/create
    #   Webhook signature                      https://docs.stripe.com/webhooks/signatures
    class Stripe < Abstract
      def initialize(client: nil)
        super()
        @injected_client = client
      end

      # Lazy so `Billing::Gateways::Stripe.new` works without an API
      # key configured — important for contract specs that only check
      # the method shape via reflection. Real callers exercise actual
      # endpoints, which forces the client to be built (and the
      # missing-key error to fire) at the call site, not at boot.
      def client
        @injected_client || @client ||= Billing::Stripe::Client.new(api_key: Billing.configuration.api_key)
      end

      # POST /v1/subscriptions
      def create_subscription(customer_ref:, plan_ref:, **opts)
        sub = client.create_subscription(
          customer: customer_ref,
          items:    [{ price: plan_ref }],
          **opts
        )
        normalise_subscription(sub)
      end

      # DELETE /v1/subscriptions/{id}
      def cancel_subscription(subscription_ref:, **opts)
        sub = client.cancel_subscription(subscription_ref, **opts)
        normalise_subscription(sub)
      end

      # GET /v1/subscriptions/{id}
      def fetch_subscription(subscription_ref:)
        sub = client.retrieve_subscription(subscription_ref)
        normalise_subscription(sub)
      end

      # POST /v1/checkout/sessions  (mode: "subscription")
      def create_checkout_session(customer_ref:, plan_ref:, success_url:, cancel_url:, **opts)
        session = client.create_checkout_session({
          mode:        "subscription",
          line_items:  [{ price: plan_ref, quantity: 1 }],
          customer:    customer_ref,
          success_url: success_url,
          cancel_url:  cancel_url
        }.merge(opts))
        { id: session["id"], url: session["url"] }
      end

      # POST /v1/billing_portal/sessions
      def create_billing_portal_session(customer_ref:, return_url:, **)
        session = client.create_billing_portal_session(
          customer:   customer_ref,
          return_url: return_url
        )
        { id: session["id"], url: session["url"] }
      end

      # POST /v1/checkout/sessions  (mode: "payment", LTD path).
      # metadata.access_type=lifetime + metadata.plan_ref=<plan_ref>
      # are duplicated on the session AND payment_intent_data so the
      # webhook handler can read either one.
      def create_lifetime_checkout_session(customer_ref:, plan_ref:, success_url:, cancel_url:, **opts)
        session = client.create_checkout_session({
          mode:        "payment",
          line_items:  [{ price: plan_ref, quantity: 1 }],
          customer:    customer_ref,
          success_url: success_url,
          cancel_url:  cancel_url,
          payment_intent_data: { metadata: { access_type: "lifetime", plan_ref: plan_ref } },
          metadata:            { access_type: "lifetime", plan_ref: plan_ref }
        }.merge(opts))
        { id: session["id"], url: session["url"] }
      end

      # https://docs.stripe.com/webhooks/signatures
      # Verifies the Stripe-Signature header against `secret` via the
      # official Stripe::Webhook helper. Raises Billing::WebhookError
      # on any failure (no header / signature mismatch / timestamp
      # outside the 5-minute tolerance window / non-JSON payload).
      # Returns the normalised event hash on success.
      def verify_webhook(payload:, signature:, secret:)
        event = Billing::Stripe::WebhookSignature.verify!(
          payload:          payload,
          signature_header: signature,
          secret:           secret
        )
        # event.data["object"] is a Stripe::StripeObject. Convert to
        # a plain Hash so subscribers downstream don't need to know
        # they're dealing with a Stripe SDK type — the engine's
        # contract is "events are hashes".
        object_hash = event.data["object"].respond_to?(:to_hash) ? event.data["object"].to_hash.transform_keys(&:to_s) : event.data["object"]
        {
          id:       event["id"],            # evt_* — controller dedupes via Billing::WebhookEvent
          type:     event["type"],
          livemode: event["livemode"],
          object:   object_hash,
          raw:      payload
        }
      end

      private

      # Stripe's response shape changed: current_period_end now lives
      # on items.data[].current_period_end. We try the subscription
      # root first for backwards compatibility, then fall back to the
      # first item.
      def normalise_subscription(sub)
        items_data = sub.dig("items", "data") || []
        first_item = items_data.first || {}
        {
          id:                  sub["id"],
          status:              sub["status"],
          current_period_end:  sub["current_period_end"] || first_item["current_period_end"],
          plan_ref:            first_item.dig("price", "id")
        }
      end
    end
  end
end
