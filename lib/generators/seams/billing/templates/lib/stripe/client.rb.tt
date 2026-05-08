# frozen_string_literal: true

require "stripe"

module Billing
  module Stripe
    # Thin facade over the official `stripe` Ruby gem so the engine's
    # service objects + gateway have one shape to call. The previous
    # version of this file was a hand-rolled Faraday REST client we
    # owned; that decision was reversed in 2026-05 (Wave 8 → reversed
    # Wave 6) because Stripe maintains the gem as a first-class
    # deliverable and keeping our own client current with their API
    # was strictly more work than the centralisation benefit Faraday
    # alone gave us.
    #
    # The public method surface is unchanged — every service object
    # and the gateway adapter call this Client without knowing
    # whether the implementation is Faraday or the gem.
    #
    # Stripe gem version pinned to ~> 13 in the host Gemfile by the
    # Billing generator. The StripeClient API
    # (`client.v1.<resource>.<action>`) is what Stripe documents at
    # https://docs.stripe.com/api?lang=ruby for every endpoint we use.
    #
    # Verified against:
    #   https://docs.stripe.com/api/customers/create
    #   https://docs.stripe.com/api/customers/search
    #   https://docs.stripe.com/api/subscriptions/create
    #   https://docs.stripe.com/api/subscriptions/update
    #   https://docs.stripe.com/api/subscriptions/cancel
    #   https://docs.stripe.com/api/subscriptions/retrieve
    #   https://docs.stripe.com/api/invoices/retrieve
    #   https://docs.stripe.com/api/checkout/sessions/create
    #   https://docs.stripe.com/api/customer_portal/sessions/create
    #   https://docs.stripe.com/api/idempotent_requests
    class Client
      def initialize(api_key:)
        @sdk = ::Stripe::StripeClient.new(api_key)
      end

      # POST /v1/subscriptions
      def create_subscription(customer:, items:, **extra)
        sdk.v1.subscriptions.create({ customer: customer, items: items }.merge(extra))
      end

      # DELETE /v1/subscriptions/{id}
      def cancel_subscription(subscription_id, **extra)
        sdk.v1.subscriptions.cancel(subscription_id, extra)
      end

      # GET /v1/subscriptions/{id}
      def retrieve_subscription(subscription_id)
        sdk.v1.subscriptions.retrieve(subscription_id)
      end

      # POST /v1/subscriptions/{id} — used by ChangePlanService (items[])
      # and ReactivateService (cancel_at_period_end: false).
      def update_subscription(subscription_id, **fields)
        sdk.v1.subscriptions.update(subscription_id, fields)
      end

      # POST /v1/checkout/sessions — params is a Hash (subscription
      # mode for recurring; payment mode for LTDs).
      def create_checkout_session(params)
        sdk.v1.checkout.sessions.create(params)
      end

      # POST /v1/billing_portal/sessions
      def create_billing_portal_session(customer:, return_url: nil)
        body = { customer: customer }
        body[:return_url] = return_url if return_url
        sdk.v1.billing_portal.sessions.create(body)
      end

      # POST /v1/customers. The optional `idempotency_key:` is the gem's
      # standard per-request opts hash (Stripe holds the response for
      # ~24h and replays it for the same key, so concurrent
      # FindOrCreate calls during a signup burst produce one customer
      # instead of two — see https://docs.stripe.com/api/idempotent_requests).
      def create_customer(email:, idempotency_key: nil, **extra)
        body = { email: email }.merge(extra)
        opts = idempotency_key ? { idempotency_key: idempotency_key } : {}
        sdk.v1.customers.create(body, opts)
      end

      # GET /v1/customers/search
      def search_customers(query:, limit: 1)
        sdk.v1.customers.search(query: query, limit: limit)
      end

      # GET /v1/invoices/{id}
      def retrieve_invoice(invoice_id)
        sdk.v1.invoices.retrieve(invoice_id)
      end

      private

      attr_reader :sdk
    end
  end
end
