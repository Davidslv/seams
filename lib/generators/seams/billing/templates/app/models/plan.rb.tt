# frozen_string_literal: true

module Billing
  # A subscription plan. Mirror of a Stripe Price (or whatever your
  # gateway calls a recurring billable thing). Hosts seed Plans
  # locally so the pricing page can render without a Stripe round-trip.
  class Plan < ApplicationRecord
    # Raised when a lifetime plan with a finite `max_lifetime_units`
    # capacity has no remaining inventory at the moment of purchase.
    # `Billing::Lifetime::CreateLifetimeSessionService` rescues this
    # and converts it into a ServiceResult-style failure so callers
    # see a friendly "sold out" message rather than an exception
    # bubbling up from inside a transaction.
    class SoldOut < StandardError; end

    self.table_name = "billing_plans"

    # `lifetime` is the LTD interval — a one-time payment with permanent
    # access. Stripe Checkout uses `mode: "payment"` for these instead
    # of `mode: "subscription"`. See LifetimePass + the LTD section in
    # the README for the trade-off (no recurring revenue, indefinite
    # support burden).
    INTERVALS = %w[day week month year lifetime].freeze

    has_many :lifetime_passes, class_name: "Billing::LifetimePass",
                               foreign_key: :plan_ref, primary_key: :gateway_ref,
                               dependent: :nullify

    validates :gateway_ref, presence: true, uniqueness: true
    validates :name, presence: true
    validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
    validates :currency, presence: true
    validates :interval, inclusion: { in: INTERVALS }

    scope :active,    -> { where(active: true) }
    scope :recurring, -> { where.not(interval: "lifetime") }
    scope :lifetime,  -> { where(interval: "lifetime") }

    def free?
      amount_cents.zero?
    end

    def has_trial?
      trial_period_days.to_i.positive?
    end

    def lifetime?
      interval == "lifetime"
    end

    # nil = unlimited; otherwise the count of LTD slots still available
    # (max_lifetime_units minus already-issued LifetimePass count).
    def lifetime_inventory_remaining
      return nil if max_lifetime_units.nil? || !lifetime?

      [max_lifetime_units - lifetime_passes.count, 0].max
    end

    def lifetime_sold_out?
      lifetime? && lifetime_inventory_remaining&.zero?
    end

    # Lock-and-check guard that the lifetime inventory cap has not
    # already been hit. Must be called from inside an open
    # `transaction` block so the `SELECT ... FOR UPDATE` row-lock is
    # held until commit — that's what makes the check race-free across
    # concurrent buyers.
    #
    # No-op for plans without a `max_lifetime_units` cap (nil = unlimited)
    # and for non-lifetime plans (cap is meaningless on recurring plans).
    #
    # Trade-off: holding a row lock across the Stripe API call (the
    # caller does this so the lock spans the Checkout-session creation)
    # means concurrent buyers serialise. For viral promos this can slow
    # checkout under load. The alternative — letting the check race —
    # oversells the plan, which costs refunds + support time + brand
    # damage. For LTDs (capped, low-volume by design) the lock is the
    # right trade. A more sophisticated optimistic alternative
    # (counter column + `UPDATE ... WHERE remaining > 0 RETURNING`) is
    # documented in the README but is out of scope for the generator.
    #
    # Raises `Billing::Plan::SoldOut` when the cap is exhausted.
    def enforce_lifetime_inventory_or_raise!
      return unless lifetime?
      return if max_lifetime_units.nil?

      lock!
      return unless lifetime_sold_out?

      raise SoldOut,
            "Plan #{gateway_ref.inspect} is sold out " \
            "(cap: #{max_lifetime_units})"
    end
  end
end
