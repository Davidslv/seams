# frozen_string_literal: true

module Billing
  # Subscription record mirrored from the gateway. Keyed locally on
  # `account_id` (UUID, the Accounts::Account tenant id) and on
  # `customer_ref` (the gateway's `cus_*` id). Both are present on
  # every row so the same data can be addressed via either side.
  #
  # No `belongs_to :account` declaration: cross-engine model access
  # is forbidden by Seams::Cops::NoCrossEngineModelAccess. Hosts that
  # want a typed handle can call `.account` on their Account model
  # via the `Billing::Billable` concern (which queries the inverse
  # association `account.billing_subscriptions`).
  class Subscription < ApplicationRecord
    self.table_name = "billing_subscriptions"

    STATUSES = %w[trialing active past_due canceled unpaid incomplete incomplete_expired paused].freeze

    validates :gateway_ref,  presence: true, uniqueness: true
    validates :account_id,   presence: true
    validates :customer_ref, presence: true
    validates :plan_ref,     presence: true
    validates :status,       inclusion: { in: STATUSES }

    scope :active_or_trialing, -> { where(status: %w[active trialing]) }

    def active?
      %w[active trialing].include?(status)
    end
  end
end
