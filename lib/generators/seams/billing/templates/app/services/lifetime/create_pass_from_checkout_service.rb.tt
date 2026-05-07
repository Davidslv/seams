# frozen_string_literal: true

module Billing
  module Lifetime
    # Creates a LifetimePass from a successful Stripe Checkout Session.
    # Called from the WebhooksController when a `checkout.session.completed`
    # (or `checkout.session.async_payment_succeeded`) event arrives with
    # `mode == "payment"` AND the session metadata flags `access_type:
    # "lifetime"`.
    #
    # Idempotent on `gateway_ref` (the Stripe Checkout Session id) so
    # Stripe retries hit the unique index and short-circuit.
    #
    # Publishes `lifetime.purchased.billing` on success.
    #
    # Docs:
    #   https://docs.stripe.com/api/checkout/sessions/object
    #   https://docs.stripe.com/payments/checkout/fulfill-orders
    module CreatePassFromCheckoutService
      Result = Struct.new(:ok?, :pass, :error, keyword_init: true)

      module_function

      def call(session:, livemode: false)
        gateway_ref  = session_field(session, :id)
        customer_ref = session_field(session, :customer)
        metadata     = session_field(session, :metadata) || {}
        plan_ref     = metadata_value(metadata, :plan_ref)

        return Result.new(ok?: false, error: "Session id missing") if gateway_ref.nil?
        return Result.new(ok?: false, error: "Customer ref missing on session") if customer_ref.nil?
        return Result.new(ok?: false, error: "plan_ref metadata missing on session") if plan_ref.nil?

        pass = Billing::LifetimePass.find_or_initialize_by(gateway_ref: gateway_ref)
        return Result.new(ok?: true, pass: pass) if pass.persisted?

        pass.assign_attributes(
          customer_ref: customer_ref,
          plan_ref:     plan_ref,
          granted_at:   Time.current,
          revoked_at:   nil
        )
        pass.save!

        Seams::Events::Publisher.publish(
          "lifetime.purchased.billing",
          gateway:      Billing.configuration.gateway_name,
          livemode:     livemode,
          customer_ref: customer_ref,
          ref:          pass.id.to_s,
          object_id:    gateway_ref,
          object:       { id: gateway_ref, plan_ref: plan_ref, pass_id: pass.id }
        )
        Result.new(ok?: true, pass: pass)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        Result.new(ok?: false, error: e.message)
      end

      # Stripe SDK objects respond to method-style access; webhook
      # payloads parsed from JSON are Hashes. Handle both.
      def self.session_field(session, name)
        if session.respond_to?(name)
          session.public_send(name)
        elsif session.is_a?(Hash)
          session[name] || session[name.to_s]
        end
      end

      def self.metadata_value(metadata, key)
        if metadata.respond_to?(key)
          metadata.public_send(key)
        elsif metadata.is_a?(Hash)
          metadata[key] || metadata[key.to_s]
        end
      end
    end
  end
end
