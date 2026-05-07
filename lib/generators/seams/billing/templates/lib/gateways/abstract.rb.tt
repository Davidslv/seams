# frozen_string_literal: true

module Billing
  module Gateways
    # Contract every billing gateway must implement. Subclass this
    # in the host application to wire Paddle, Adyen, Lemon Squeezy,
    # then point Billing.configuration.gateway at the subclass name.
    class Abstract
      # Create or fetch a recurring subscription for the host's
      # customer. `customer_ref` is whatever opaque identifier the
      # host stores on its user (typically a Stripe customer id).
      def create_subscription(customer_ref:, plan_ref:, **)
        raise NotImplementedError, "#{self.class} must implement #create_subscription"
      end

      def cancel_subscription(subscription_ref:, **)
        raise NotImplementedError, "#{self.class} must implement #cancel_subscription"
      end

      # Retrieve a subscription as a normalised hash:
      #   { id:, status:, current_period_end:, plan_ref: }
      def fetch_subscription(subscription_ref:)
        raise NotImplementedError, "#{self.class} must implement #fetch_subscription"
      end

      # Create a hosted checkout session. Returns a normalised hash:
      #   { id:, url: }
      # The host redirects the user to `url`, the gateway handles the
      # payment UI, and webhooks tell us the result.
      def create_checkout_session(customer_ref:, plan_ref:, success_url:, cancel_url:, **)
        raise NotImplementedError, "#{self.class} must implement #create_checkout_session"
      end

      # Create a customer-portal session so the user can self-serve
      # their subscription (cancel, change plan, update payment
      # method). Returns: { id:, url: }.
      def create_billing_portal_session(customer_ref:, return_url:, **)
        raise NotImplementedError, "#{self.class} must implement #create_billing_portal_session"
      end

      # Create a one-time-payment hosted-checkout session for an LTD
      # plan. Same return shape as #create_checkout_session, but uses
      # the gateway's `mode: payment` flow (Stripe) — no recurring
      # billing, no customer.subscription.* webhooks. Idempotency
      # carries through metadata so the webhook handler can resolve
      # the LTD plan_ref without a separate API call.
      def create_lifetime_checkout_session(customer_ref:, plan_ref:, success_url:, cancel_url:, **)
        raise NotImplementedError, "#{self.class} must implement #create_lifetime_checkout_session"
      end

      # Verify a webhook payload + signature and return a normalised
      # event hash:
      #   { id:, type:, livemode:, object: <provider's raw object>, raw: <payload> }
      #
      # `id:` is the gateway's own event id (e.g. evt_* from Stripe).
      # The Billing webhook controller uses it to dedupe retries via
      # Billing::WebhookEvent.unique(gateway, gateway_event_id).
      # Implementations MUST raise Billing::WebhookError on any
      # signature mismatch.
      def verify_webhook(payload:, signature:, secret:)
        raise NotImplementedError, "#{self.class} must implement #verify_webhook"
      end
    end
  end
end
