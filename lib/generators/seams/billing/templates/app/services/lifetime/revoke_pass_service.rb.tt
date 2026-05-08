# frozen_string_literal: true

module Billing
  module Lifetime
    # Revokes a previously-issued LifetimePass. Soft delete: sets
    # `revoked_at` (and `revoked_by_identity_id`) so the audit trail
    # survives. Use for refunds, ToS violations, support gestures
    # that are later reversed.
    #
    # The `revoked_by` argument is an Auth::Identity (the human who
    # pressed "revoke") — Identity, not the Account that lost the
    # entitlement. Pass `nil` for system-revoked passes (a background
    # ToS sweep, for instance).
    #
    # Stripe refund (if the pass was paid) is NOT issued here — the
    # caller is expected to refund via the gateway separately. This
    # service updates only the local row.
    #
    # Idempotent: revoking an already-revoked pass returns ok? + the
    # same row without re-publishing the event.
    module RevokePassService
      Result = Struct.new(:ok?, :pass, :error, keyword_init: true)

      module_function

      def call(pass:, revoked_by:, notes: nil)
        pass = Billing::LifetimePass.find(pass) if pass.is_a?(Integer)
        return Result.new(ok?: false, error: "Pass not found") unless pass

        return Result.new(ok?: true, pass: pass) if pass.revoked?

        pass.update!(
          revoked_at:             Time.current,
          revoked_by_identity_id: GrantPassService.granted_by_identity_id_from(revoked_by),
          notes:                  [pass.notes, notes].compact.join("\n---\n").presence
        )

        Seams::Events::Publisher.publish(
          "lifetime.revoked.billing",
          gateway:      Billing.configuration.gateway_name,
          livemode:     false,
          account_id:   pass.account_id,
          customer_ref: pass.customer_ref,
          ref:          pass.id.to_s,
          object_id:    pass.id.to_s,
          object:       {
            id:                     pass.id,
            account_id:             pass.account_id,
            plan_ref:               pass.plan_ref,
            revoked_by_identity_id: pass.revoked_by_identity_id
          }
        )
        Result.new(ok?: true, pass: pass)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
        Result.new(ok?: false, error: e.message)
      end
    end
  end
end
