# frozen_string_literal: true

# Factories for Billing engine specs. Sequences keep ref columns
# (gateway_ref, customer_ref, plan_ref) unique across the spec run
# so uniqueness validations don't trip.
#
# Post-Wave-9: every billing-row factory carries an `account_id`
# (UUID) — the Accounts::Account the row belongs to. We don't
# `association :account` because cross-engine model access is
# forbidden by the Seams cops; the spec generates a fresh
# SecureRandom UUID per row, which is safe in a test DB without a
# DB-level FK to accounts. Hosts that have an Accounts::Account
# factory available can override the `account_id` value with one
# from a real `create(:account)`.
FactoryBot.define do
  factory :billing_plan, class: "Billing::Plan" do
    sequence(:gateway_ref) { |n| "price_test_#{n}" }
    sequence(:name)        { |n| "Plan #{n}" }
    amount_cents           { 1299 }
    currency               { "GBP" }
    interval               { "month" }
    trial_period_days      { 0 }

    factory :billing_lifetime_plan do
      interval                   { "lifetime" }
      max_lifetime_units         { nil }
      sequence(:gateway_ref) { |n| "price_test_lifetime_#{n}" }
    end
  end

  factory :billing_subscription, class: "Billing::Subscription" do
    account_id              { SecureRandom.uuid }
    sequence(:gateway_ref)  { |n| "sub_test_#{n}" }
    sequence(:customer_ref) { |n| "cus_test_#{n}" }
    sequence(:plan_ref)     { |n| "price_test_#{n}" }
    status                  { "active" }
    current_period_end      { 30.days.from_now }
  end

  factory :billing_invoice, class: "Billing::Invoice" do
    account_id                     { SecureRandom.uuid }
    sequence(:gateway_ref)         { |n| "in_test_#{n}" }
    sequence(:customer_ref)        { |n| "cus_test_#{n}" }
    sequence(:subscription_ref)    { |n| "sub_test_#{n}" }
    status                         { "paid" }
    amount_cents                   { 1299 }
    currency                       { "GBP" }
    paid_at                        { Time.current }
  end

  factory :billing_lifetime_pass, class: "Billing::LifetimePass" do
    account_id              { SecureRandom.uuid }
    sequence(:customer_ref) { |n| "cus_test_lifetime_#{n}" }
    sequence(:plan_ref)     { |n| "price_test_lifetime_#{n}" }
    sequence(:gateway_ref)  { |n| "cs_test_#{n}" }
    granted_at              { Time.current }
  end

  factory :billing_webhook_event, class: "Billing::WebhookEvent" do
    gateway                     { "stripe" }
    sequence(:gateway_event_id) { |n| "evt_test_#{n}" }
    event_type                  { "customer.subscription.created" }
    livemode                    { false }
  end
end
