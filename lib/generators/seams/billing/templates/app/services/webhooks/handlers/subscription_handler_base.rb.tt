# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # Base for the four customer.subscription.* handlers. Owns the
      # upsert of Billing::Subscription so each leaf class just sets
      # SEAMS_EVENT and inherits.
      #
      # Account resolution: for subscriptions created via the host's
      # `Account#start_subscription!` flow, StartSubscriptionJob has
      # already inserted a Billing::Subscription row with `account_id`
      # set; the upsert here finds it via `gateway_ref` and preserves
      # the existing `account_id`. For subscriptions created directly
      # in the Stripe Dashboard (no local row pre-exists), the upsert
      # falls back to looking up `account_id` from any sibling row
      # under the same `customer_ref`. If neither path resolves,
      # the upsert is skipped + a warning is logged — the host
      # supports this case by reconciling the orphaned subscription
      # via a sync task (see README "Stripe-initiated subscriptions").
      class SubscriptionHandlerBase < Billing::Webhooks::Handler
        def call
          upsert_subscription
          publish
        end

        protected

        def upsert_subscription
          return unless object_id && customer_ref && object_hash.is_a?(Hash)

          subscription = Billing::Subscription.find_or_initialize_by(gateway_ref: object_id)
          resolved_account_id = subscription.account_id || resolve_account_id_from_sibling
          unless resolved_account_id
            warn_upsert_failure(
              StandardError.new("could not resolve account_id for customer_ref=#{customer_ref}")
            )
            return
          end

          subscription.account_id         = resolved_account_id
          subscription.customer_ref       = customer_ref
          subscription.plan_ref           = plan_ref_from_object_hash
          subscription.status             = object_hash[:status] || object_hash["status"] || subscription.status || "incomplete"
          subscription.current_period_end = current_period_end_at
          subscription.save!
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          warn_upsert_failure(e)
        end

        # Look up account_id from any other Billing::Subscription row
        # under the same Stripe customer. A customer almost always
        # belongs to one Account post-Wave-9 (Account == Stripe
        # customer), so the first sibling row's account_id is the
        # correct answer.
        def resolve_account_id_from_sibling
          Billing::Subscription.where(customer_ref: customer_ref)
                               .where.not(account_id: nil)
                               .pick(:account_id)
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
