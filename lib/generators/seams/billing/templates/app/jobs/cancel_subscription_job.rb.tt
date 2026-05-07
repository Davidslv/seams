# frozen_string_literal: true

module Billing
  class CancelSubscriptionJob < ApplicationJob
    queue_as :billing

    def perform(subscription_ref:)
      result = Billing.gateway.cancel_subscription(subscription_ref: subscription_ref)

      sub = Billing::Subscription.find_by(gateway_ref: subscription_ref)
      sub&.update!(status: result[:status])

      if sub.nil?
        # Local row missing — host's notification subscriber has no
        # customer_ref to resolve the User and will silently no-op.
        # Log so the gap is visible (e.g. drift between Stripe + local
        # DB after a partial migration).
        Seams::Observability.adapter.warn(
          "billing.cancel_subscription.local_row_missing",
          engine: "billing", subscription_ref: subscription_ref
        )
      end

      # Canonical event payload — must match what WebhooksController
      # emits for the same event so subscribers can read one shape:
      #   { gateway:, livemode:, customer_ref:, ref:, object_id:, object: }
      Seams::Events::Publisher.publish(
        "subscription.canceled.billing",
        gateway:      Billing.configuration.gateway_name,
        livemode:     false,
        customer_ref: sub&.customer_ref,
        ref:          subscription_ref,
        object_id:    subscription_ref,
        object:       { id: subscription_ref, status: result[:status] }
      )
    end
  end
end
