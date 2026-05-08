# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # Base for the four customer.subscription.* handlers. Owns the
      # upsert of Billing::Subscription so each leaf class just sets
      # SEAMS_EVENT and inherits.
      class SubscriptionHandlerBase < Billing::Webhooks::Handler
        def call
          upsert_subscription
          publish
        end

        protected

        def upsert_subscription
          return unless object_id && customer_ref && object_hash.is_a?(Hash)

          Billing::Subscription
            .find_or_initialize_by(gateway_ref: object_id)
            .tap do |subscription|
              subscription.customer_ref       = customer_ref
              subscription.plan_ref           = plan_ref_from_object_hash
              subscription.status             = object_hash[:status] || object_hash["status"] || subscription.status || "incomplete"
              subscription.current_period_end = current_period_end_at
              subscription.save!
            end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          warn_upsert_failure(e)
        end

        def plan_ref_from_object_hash
          first = first_subscription_item
          return nil unless first

          price = first[:price] || first["price"]
          price.is_a?(Hash) ? (price[:id] || price["id"]) : nil
        end

        # Stripe moved current_period_end onto each subscription item
        # in 2024; older API versions still set it at the root. Try
        # root first, fall back to items.data[0].
        # https://docs.stripe.com/api/subscriptions/object
        def current_period_end_at
          unix = object_hash[:current_period_end] ||
                 object_hash["current_period_end"]
          unix ||= (item = first_subscription_item) &&
                   (item[:current_period_end] || item["current_period_end"])
          unix && Time.at(unix)
        end

        def first_subscription_item
          items = object_hash[:items] || object_hash["items"]
          return nil unless items.is_a?(Hash)

          first = (items[:data] || items["data"] || []).first
          first if first.is_a?(Hash)
        end
      end
    end
  end
end
