# frozen_string_literal: true

module Billing
  class StartSubscriptionJob < ApplicationJob
    queue_as :billing

    def perform(customer_ref:, plan_ref:)
      result = Billing.gateway.create_subscription(customer_ref: customer_ref, plan_ref: plan_ref)

      Billing::Subscription.create!(
        customer_ref: customer_ref,
        plan_ref:     result[:plan_ref] || plan_ref,
        gateway_ref:  result[:id],
        status:       result[:status]
      )

      # Canonical event payload — same shape as WebhooksController emits:
      #   { gateway:, livemode:, customer_ref:, ref:, object_id:, object: }
      Seams::Events::Publisher.publish(
        "subscription.created.billing",
        gateway:      Billing.configuration.gateway_name,
        livemode:     false,
        customer_ref: customer_ref,
        ref:          result[:id],
        object_id:    result[:id],
        object:       { id: result[:id], plan: { id: plan_ref }, status: result[:status] }
      )
    end
  end
end
