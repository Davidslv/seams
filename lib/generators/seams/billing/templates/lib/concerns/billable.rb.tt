# frozen_string_literal: true

require "active_support/concern"

module Billing
  # Mix into the host's Accounts::Account model — the tenant — to gain
  # billing helpers. The Account is the Stripe customer; subscriptions,
  # invoices, and lifetime passes all belong to the tenant, not to an
  # individual human (Identity). A single Identity who is a member of
  # two Accounts has TWO independent billing relationships.
  #
  # Wiring is config-driven (see Billing::Configuration#billable_class).
  # The default `"Accounts::Account"` matches the canonical accounts
  # engine; hosts on a different tenant model point the config at
  # their own class.
  #
  # Hosts that want to wire it manually instead can do so:
  #
  #   class Accounts::Account < ApplicationRecord
  #     include Billing::Billable
  #   end
  module Billable
    extend ActiveSupport::Concern

    included do
      # Associations are bare `account_id` keyed — the cross-engine
      # model-access cop forbids `belongs_to :account` from inside
      # billing pointing at Accounts::Account, so we use foreign_key
      # without a class_name on the back-edge: account.billing_*
      # queries the billing tables by the account's id.
      has_many :billing_subscriptions, class_name: "Billing::Subscription",
                                       foreign_key: :account_id, primary_key: :id
      has_many :billing_lifetime_passes, class_name: "Billing::LifetimePass",
                                         foreign_key: :account_id, primary_key: :id
      has_many :billing_invoices, class_name: "Billing::Invoice",
                                  foreign_key: :account_id, primary_key: :id
    end

    # Enqueues a Stripe subscription. The `email:` arg is the contact
    # address Stripe attaches to the customer record on first creation
    # — typically the Account owner's Identity#email_address, but the
    # host decides (it might be a billing-specific contact instead).
    # Subsequent calls reuse the existing Stripe customer.
    def start_subscription!(plan_ref:, email:)
      Billing::StartSubscriptionJob.perform_later(
        account_id:   id,
        customer_ref: stripe_customer_ref!(email: email),
        plan_ref:     plan_ref
      )
    end

    def cancel_subscription!(subscription_ref:)
      Billing::CancelSubscriptionJob.perform_later(subscription_ref: subscription_ref)
    end

    # Lifetime Deal helpers (issue #2 section 3A.LTD).
    # `lifetime?` is true if this Account holds an active LifetimePass
    # for ANY plan; `has_lifetime_for?(plan_ref:)` narrows to one.
    def lifetime?
      billing_lifetime_passes.where(revoked_at: nil).exists?
    end

    def has_lifetime_for?(plan_ref:)
      billing_lifetime_passes.where(revoked_at: nil, plan_ref: plan_ref).exists?
    end

    # The "is this Account a paying / entitled customer right now?"
    # check. True for active or trialing recurring subscriptions OR
    # for any active lifetime pass. Use this in host code instead of
    # querying subscriptions directly so LTD-only accounts are
    # accounted for.
    def has_active_billing?
      billing_subscriptions.where(status: %w[active trialing]).exists? || lifetime?
    end

    # Lazily resolves (and caches) the Stripe customer id for this
    # Account. First call creates a Stripe customer keyed on the
    # Account#name + the supplied billing email; subsequent calls
    # return the cached value.
    #
    # The `customer_ref` is stored on every billing_subscriptions /
    # billing_invoices / billing_lifetime_passes row, so once an
    # Account has any billing activity we can read the ref off any
    # existing row and skip the Stripe API call.
    def stripe_customer_ref!(email:)
      existing = billing_subscriptions.first&.customer_ref ||
                 billing_invoices.first&.customer_ref ||
                 billing_lifetime_passes.first&.customer_ref
      return existing if existing

      result = Billing::Customers::FindOrCreateService.call(
        email:    email,
        metadata: { account_id: id, account_name: respond_to?(:name) ? name : nil }
      )
      raise Billing::Error, "Could not resolve Stripe customer: #{result.error}" unless result.ok?

      result.value
    end
  end
end
