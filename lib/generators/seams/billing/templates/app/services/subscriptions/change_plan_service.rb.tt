# frozen_string_literal: true

module Billing
  module Subscriptions
    # Switches a Stripe subscription to a new price. Stripe requires
    # the existing subscription_item id (not just the new price), so
    # this service does a retrieve-then-update rather than a single
    # call. Proration mode defaults to "create_prorations" so the
    # user is billed/credited the difference immediately; pass
    # `proration_behavior: "none"` to defer until the next cycle.
    #
    #   Billing::Subscriptions::ChangePlanService.call(
    #     subscription_ref: "sub_xyz",
    #     new_price_ref:    "price_pro_annual"
    #   )
    #
    # Verified against
    # https://docs.stripe.com/billing/subscriptions/upgrade-downgrade.
    class ChangePlanService < Billing::StripeService
      def initialize(subscription_ref:, new_price_ref:, proration_behavior: "create_prorations")
        @subscription_ref   = subscription_ref
        @new_price_ref      = new_price_ref
        @proration_behavior = proration_behavior
      end

      def call_stripe(client)
        existing      = client.retrieve_subscription(@subscription_ref)
        existing_item = existing[:items][:data].first
        return :no_items if existing_item.nil?

        client.update_subscription(
          @subscription_ref,
          items: [
            { id: existing_item[:id], price: @new_price_ref }
          ],
          proration_behavior: @proration_behavior
        )
      end

      def on_success(stripe_response)
        return ServiceResult.failure(error: "Subscription has no items", code: :invalid_state) if stripe_response == :no_items

        new_price = stripe_response[:items][:data].first[:price][:id]
        ServiceResult.ok(value: { id: stripe_response[:id], plan_ref: new_price })
      end
    end
  end
end
