# frozen_string_literal: true

module Billing
  module Subscriptions
    # Un-cancels a subscription that's pending cancellation at period
    # end. No-op for subscriptions already past their period end —
    # those need a fresh checkout flow, not a reactivate. Verified
    # against
    # https://docs.stripe.com/billing/subscriptions/cancel#reactivate-canceled-subscription.
    class ReactivateService < Billing::StripeService
      def initialize(subscription_ref:)
        @subscription_ref = subscription_ref
      end

      def call_stripe(client)
        client.update_subscription(@subscription_ref, cancel_at_period_end: false)
      end

      def on_success(stripe_response)
        ServiceResult.ok(value: {
                           id:                  stripe_response[:id],
                           status:              stripe_response[:status],
                           cancel_at_period_end: stripe_response[:cancel_at_period_end]
                         })
      end
    end
  end
end
