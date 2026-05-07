# frozen_string_literal: true

module Billing
  module Subscriptions
    # Cancels a Stripe subscription. By default schedules the cancel
    # for end-of-period (cancel_at_period_end: true) so the user
    # keeps access through what they've already paid for.
    # `immediate: true` cancels the subscription right away — the
    # webhook fires customer.subscription.deleted shortly after.
    #
    #   Billing::Subscriptions::CancelService.call(
    #     subscription_ref: subscription.gateway_ref
    #   )
    #
    # Verified against
    # https://docs.stripe.com/api/subscriptions/update (period-end)
    # and https://docs.stripe.com/api/subscriptions/cancel (immediate).
    class CancelService < Billing::StripeService
      def initialize(subscription_ref:, immediate: false)
        @subscription_ref = subscription_ref
        @immediate        = immediate
      end

      def call_stripe(client)
        if @immediate
          client.cancel_subscription(@subscription_ref)
        else
          client.update_subscription(@subscription_ref, cancel_at_period_end: true)
        end
      end

      def on_success(stripe_response)
        ServiceResult.ok(value: {
                           id:                  stripe_response[:id],
                           status:              stripe_response[:status],
                           cancel_at_period_end: stripe_response[:cancel_at_period_end],
                           canceled_at:         stripe_response[:canceled_at]
                         })
      end
    end
  end
end
