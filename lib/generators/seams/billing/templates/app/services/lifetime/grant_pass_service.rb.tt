# frozen_string_literal: true

module Billing
  module Lifetime
    # Privately grants a Lifetime Pass to a customer. NO Stripe charge —
    # used for early adopters, influencer giveaways, support gestures,
    # ToS-violation refunds-then-re-grant.
    #
    # Idempotent on (customer_ref, plan_ref) — re-granting an existing
    # pass returns ok? + the existing record rather than raising.
    #
    # Publishes `lifetime.granted.billing` on success (canonical billing
    # payload shape — see billing/README).
    module GrantPassService
      Result = Struct.new(:ok?, :pass, :error, keyword_init: true)

      module_function

      def call(customer_ref:, plan_ref:, granted_by:, notes: nil)
        plan = Billing::Plan.find_by(gateway_ref: plan_ref)
        return Result.new(ok?: false, error: "Plan #{plan_ref.inspect} not found") unless plan
        return Result.new(ok?: false, error: "Plan #{plan_ref.inspect} is not a lifetime plan") unless plan.lifetime?
        return Result.new(ok?: false, error: "No lifetime inventory remaining for #{plan_ref.inspect}") if plan.lifetime_sold_out?

        pass = Billing::LifetimePass.find_or_initialize_by(customer_ref: customer_ref, plan_ref: plan_ref)
        return Result.new(ok?: true, pass: pass) if pass.persisted? && pass.active?

        pass.assign_attributes(
          gateway_ref:        nil,
          granted_by_user_id: granted_by_user_id_from(granted_by),
          granted_at:         Time.current,
          revoked_at:         nil,
          notes:              notes
        )
        pass.save!

        publish_granted(pass)
        Result.new(ok?: true, pass: pass)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(ok?: false, error: e.message)
      end

      def self.granted_by_user_id_from(granted_by)
        return granted_by if granted_by.is_a?(Integer)
        return granted_by.id if granted_by.respond_to?(:id)

        nil
      end

      def self.publish_granted(pass)
        Seams::Events::Publisher.publish(
          "lifetime.granted.billing",
          gateway:      Billing.configuration.gateway_name,
          livemode:     false,  # private grants are never livemode
          customer_ref: pass.customer_ref,
          ref:          pass.id.to_s,
          object_id:    pass.id.to_s,
          object:       { id: pass.id, plan_ref: pass.plan_ref, granted_by_user_id: pass.granted_by_user_id }
        )
      end
    end
  end
end
