# frozen_string_literal: true

module Billing
  # A LifetimePass is a one-time-paid OR privately-granted permanent
  # access record. It deliberately lives in its own table rather than
  # piggy-backing on Subscription with a `lifetime: true` flag — the
  # semantics diverge enough (no current_period_end, no renewal
  # webhook, no proration) that mixing them invites bugs.
  #
  # Two creation paths:
  #   1. Public — host's pricing page → Stripe Checkout (mode: payment)
  #      → `checkout.session.completed` webhook → CreatePassFromCheckoutService.
  #      `gateway_ref` is the Stripe Checkout Session id; `granted_by_user_id`
  #      is nil (paid, not granted).
  #   2. Private grant — admin form → GrantPassService.
  #      `gateway_ref` is nil (no Stripe charge); `granted_by_user_id` is
  #      the admin who issued it.
  #
  # Active passes can be revoked via RevokePassService (refunded,
  # ToS violation, etc.) — sets `revoked_at` rather than deleting so
  # the audit trail survives.
  class LifetimePass < ApplicationRecord
    self.table_name = "billing_lifetime_passes"

    belongs_to :plan, class_name: "Billing::Plan",
                      foreign_key: :plan_ref, primary_key: :gateway_ref,
                      optional: true

    validates :customer_ref, :plan_ref, :granted_at, presence: true
    validates :customer_ref, uniqueness: { scope: :plan_ref,
                                           message: "already has a lifetime pass for this plan" }

    scope :active,  -> { where(revoked_at: nil) }
    scope :revoked, -> { where.not(revoked_at: nil) }

    # True for paid passes (Stripe Checkout completed), false for
    # privately-granted ones (admin form, no charge).
    def paid?
      gateway_ref.present?
    end

    def granted?
      granted_by_user_id.present?
    end

    def revoked?
      revoked_at.present?
    end

    def active?
      !revoked?
    end
  end
end
