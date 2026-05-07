# frozen_string_literal: true

module Billing
  class Subscription < ApplicationRecord
    self.table_name = "billing_subscriptions"

    STATUSES = %w[trialing active past_due canceled unpaid incomplete incomplete_expired paused].freeze

    validates :gateway_ref,  presence: true, uniqueness: true
    validates :customer_ref, presence: true
    validates :plan_ref,     presence: true
    validates :status,       inclusion: { in: STATUSES }

    scope :active_or_trialing, -> { where(status: %w[active trialing]) }

    def active?
      %w[active trialing].include?(status)
    end
  end
end
