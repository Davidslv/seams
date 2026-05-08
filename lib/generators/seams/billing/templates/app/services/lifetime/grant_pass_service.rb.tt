# frozen_string_literal: true

module Billing
  module Lifetime
    # Privately grants a Lifetime Pass to an Account. NO Stripe charge —
    # used for early adopters, influencer giveaways, support gestures,
    # ToS-violation refunds-then-re-grant.
    #
    # The `granted_by` argument is an Auth::Identity (the human who
    # pressed the "grant lifetime" button) — Identity, not the
    # Account, because we record human action here. Pass `nil` for
    # system-granted passes (background job / migration / seed data).
    #
    # Idempotent on (account_id, plan_ref) — re-granting an existing
    # pass returns ok? + the existing record rather than raising.
    #
    # Publishes `lifetime.granted.billing` on success (canonical billing
    # payload shape — see billing/README).
    module GrantPassService
      Result = Struct.new(:ok?, :pass, :error, keyword_init: true)

      module_function

      def call(account_id:, customer_ref:, plan_ref:, granted_by:, notes: nil)
        plan = Billing::Plan.find_by(gateway_ref: plan_ref)
        return Result.new(ok?: false, error: "Plan #{plan_ref.inspect} not found") unless plan
        return Result.new(ok?: false, error: "Plan #{plan_ref.inspect} is not a lifetime plan") unless plan.lifetime?
        return Result.new(ok?: false, error: "No lifetime inventory remaining for #{plan_ref.inspect}") if plan.lifetime_sold_out?

        pass = Billing::LifetimePass.find_or_initialize_by(account_id: account_id, plan_ref: plan_ref)
        return Result.new(ok?: true, pass: pass) if pass.persisted? && pass.active?

        pass.assign_attributes(
          customer_ref:           customer_ref,
          gateway_ref:            nil,
          granted_by_identity_id: granted_by_identity_id_from(granted_by),
          granted_at:             Time.current,
          revoked_at:             nil,
          notes:                  notes
        )
        pass.save!

        publish_granted(pass)
        Result.new(ok?: true, pass: pass)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(ok?: false, error: e.message)
      end

      # Coerces the `granted_by` argument into an integer Identity id.
      # Accepts:
      #   - an Integer (assumed already an Auth::Identity#id)
      #   - any object responding to `#id` (an Auth::Identity record)
      #   - nil (system-granted; column stays NULL)
      def self.granted_by_identity_id_from(granted_by)
        return granted_by if granted_by.is_a?(Integer)
        return granted_by.id if granted_by.respond_to?(:id) && !granted_by.nil?

        nil
      end

      def self.publish_granted(pass)
        Seams::Events::Publisher.publish(
          "lifetime.granted.billing",
          gateway:      Billing.configuration.gateway_name,
          livemode:     false,  # private grants are never livemode
          account_id:   pass.account_id,
          customer_ref: pass.customer_ref,
          ref:          pass.id.to_s,
          object_id:    pass.id.to_s,
          object:       {
            id:                     pass.id,
            account_id:             pass.account_id,
            plan_ref:               pass.plan_ref,
            granted_by_identity_id: pass.granted_by_identity_id
          }
        )
      end
    end
  end
end
