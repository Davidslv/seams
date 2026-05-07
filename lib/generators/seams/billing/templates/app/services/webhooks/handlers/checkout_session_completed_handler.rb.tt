# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # Two distinct paths through one Stripe event:
      #
      #   - mode: "subscription"  → the recurring subscription is now
      #     paid + active. The customer.subscription.created event
      #     usually arrives first; this is the confirmation that the
      #     checkout flow itself completed.
      #   - mode: "payment" with metadata.access_type == "lifetime" →
      #     a Lifetime Deal was purchased. Hands off to the LTD
      #     service which creates the LifetimePass row + emits
      #     lifetime.purchased.billing.
      #
      # Stripe also fires checkout.session.async_payment_succeeded for
      # delayed methods (ACH). The router maps both to this handler.
      # Verified against
      # https://docs.stripe.com/payments/checkout/fulfill-orders.
      class CheckoutSessionCompletedHandler < Billing::Webhooks::Handler
        SEAMS_EVENT = "checkout.session_completed.billing"

        def call
          if lifetime?
            handle_lifetime
          else
            publish
          end
        end

        private

        def lifetime?
          mode_value == "payment" && access_type == "lifetime"
        end

        def handle_lifetime
          Billing::Lifetime::CreatePassFromCheckoutService.call(
            session:  event[:object],
            livemode: event[:livemode]
          )
        end

        def mode_value
          object_hash.is_a?(Hash) && (object_hash[:mode] || object_hash["mode"])
        end

        def access_type
          metadata = object_hash.is_a?(Hash) && (object_hash[:metadata] || object_hash["metadata"])
          return nil unless metadata.is_a?(Hash)

          metadata[:access_type] || metadata["access_type"]
        end
      end
    end
  end
end
