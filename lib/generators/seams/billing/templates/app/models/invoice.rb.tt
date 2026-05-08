# frozen_string_literal: true

module Billing
  # Local mirror of a gateway invoice. Keyed on `account_id` (the
  # Accounts::Account tenant) AND `customer_ref` (the gateway's
  # `cus_*` id) so subscribers can address it either way. No
  # `belongs_to :account` — cross-engine model access is forbidden;
  # querying flows through `account.billing_invoices` (provided by
  # Billing::Billable on the host's Account model).
  class Invoice < ApplicationRecord
    self.table_name = "billing_invoices"

    STATUSES = %w[draft open paid void uncollectible].freeze

    validates :gateway_ref,  presence: true, uniqueness: true
    validates :account_id,   presence: true
    validates :customer_ref, presence: true
    validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
    validates :currency,     presence: true
    validates :status,       inclusion: { in: STATUSES }

    # Convenience association — Stripe sends `subscription` as a
    # gateway-side id (sub_*), not a local FK; resolve through the
    # local subscription mirror by gateway_ref.
    def subscription
      return nil if subscription_ref.blank?

      Billing::Subscription.find_by(gateway_ref: subscription_ref)
    end

    def paid?
      status == "paid"
    end
  end
end
