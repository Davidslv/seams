# frozen_string_literal: true

require "active_support/concern"

module Billing
  # Mix into the host's user-facing model to gain `subscriptions` +
  # `start_subscription!(plan_ref:)` helpers backed by the Billing
  # engine's gateway.
  #
  #   class User < ApplicationRecord
  #     include Billing::Billable
  #   end
  module Billable
    extend ActiveSupport::Concern

    included do
      has_many :billing_subscriptions, class_name: "Billing::Subscription",
                                       foreign_key: :customer_ref, primary_key: :stripe_customer_id
      has_many :billing_lifetime_passes, class_name: "Billing::LifetimePass",
                                         foreign_key: :customer_ref, primary_key: :stripe_customer_id
    end

    def start_subscription!(plan_ref:)
      Billing::StartSubscriptionJob.perform_later(
        customer_ref: stripe_customer_id_or_raise!, plan_ref: plan_ref
      )
    end

    def cancel_subscription!(subscription_ref:)
      Billing::CancelSubscriptionJob.perform_later(subscription_ref: subscription_ref)
    end

    # Lifetime Deal helpers (issue #2 section 3A.LTD).
    # `lifetime?` is true if the user holds an active LifetimePass for
    # ANY plan; `has_lifetime_for?(plan_ref:)` narrows to a specific one.
    def lifetime?
      lifetime_passes.active.exists?
    end

    def has_lifetime_for?(plan_ref:)
      lifetime_passes.active.exists?(plan_ref: plan_ref)
    end

    def lifetime_passes
      return Billing::LifetimePass.none unless respond_to?(:stripe_customer_id) && stripe_customer_id.present?

      billing_lifetime_passes
    end

    # The "is this user a paying / entitled customer right now?" check.
    # True for active or trialing recurring subscriptions OR for any
    # active lifetime pass. Use this in host code instead of querying
    # subscriptions directly so LTD users are accounted for.
    def has_active_billing?
      billing_subscriptions.active_or_trialing.exists? || lifetime?
    end

    private

    def stripe_customer_id_or_raise!
      return stripe_customer_id if respond_to?(:stripe_customer_id) && stripe_customer_id.present?

      raise Billing::Error,
            "Host model #{self.class.name} must define a stripe_customer_id attribute " \
            "before calling Billable methods."
    end
  end
end
