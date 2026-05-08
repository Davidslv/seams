# frozen_string_literal: true

module Billing
  module Lifetime
    # Creates a Stripe Checkout session for an LTD plan (`mode: payment`).
    # Validates inventory + plan-is-lifetime before round-tripping to
    # the gateway so a sold-out plan doesn't burn a Stripe API call.
    #
    # Concurrency note (the reason this service is not "just call Stripe"):
    # `Billing::Plan#max_lifetime_units` is enforced by counting issued
    # `LifetimePass` rows. A plain count is racey — two browsers clicking
    # "Buy lifetime" within the same second on a plan with one seat left
    # will both pass the check, both hit Stripe Checkout, both pay, and
    # the unique index on `(customer_ref, plan_ref)` does not save us
    # because the buyers have different customer refs. We end up with
    # `count > max_lifetime_units` and an oversold promo.
    #
    # The fix: open a transaction, take a `SELECT ... FOR UPDATE`
    # row-lock on the plan, re-check inventory under the lock, and
    # only THEN create the Stripe Checkout session. The lock is held
    # for the duration of the Stripe API call (released on commit).
    #
    # Trade-off: the Stripe call can take up to ~30s, so under a viral
    # promo with 1000+ concurrent buyers on the same plan, checkout
    # session creation serialises. For LTDs (low-volume by design) this
    # is the right trade — correctness over throughput. For high-volume
    # workloads the alternative is optimistic concurrency via a counter
    # column + `UPDATE ... WHERE remaining > 0 RETURNING`, which is out
    # of scope for the seams generator.
    #
    # Returns a Result with ok?, url, error.
    module CreateLifetimeSessionService
      Result = Struct.new(:ok?, :url, :error, keyword_init: true)

      module_function

      def call(customer_ref:, plan_ref:, success_url:, cancel_url:)
        url = Billing::Plan.transaction do
          plan = Billing::Plan.find_by(gateway_ref: plan_ref)
          raise PlanLookupError, "Plan #{plan_ref.inspect} not found" unless plan
          raise PlanLookupError, "Plan #{plan_ref.inspect} is not a lifetime plan" unless plan.lifetime?

          # Inside the transaction so the row-lock is held until commit.
          # Raises Billing::Plan::SoldOut if the cap is exhausted.
          plan.enforce_lifetime_inventory_or_raise!

          # Stripe Checkout session creation happens under the lock.
          # Yes, this serialises concurrent buyers on the same plan —
          # see the class comment for why that's the right trade for LTDs.
          session = Billing.gateway.create_lifetime_checkout_session(
            customer_ref: customer_ref,
            plan_ref:     plan_ref,
            success_url:  success_url,
            cancel_url:   cancel_url
          )
          session[:url]
        end

        Result.new(ok?: true, url: url)
      rescue PlanLookupError => e
        Result.new(ok?: false, error: e.message)
      rescue Billing::Plan::SoldOut => e
        Result.new(ok?: false, error: e.message)
      rescue Billing::GatewayError => e
        Result.new(ok?: false, error: e.message)
      end

      # Internal sentinel so `find_by` misses + non-lifetime plans bubble
      # out of the transaction block as failures (rather than as a return
      # value, which `transaction { }` would commit). Not part of the
      # public API.
      class PlanLookupError < StandardError; end
    end
  end
end
