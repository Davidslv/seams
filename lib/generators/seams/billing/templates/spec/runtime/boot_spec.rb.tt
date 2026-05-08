# frozen_string_literal: true

require_relative "../rails_helper"

RSpec.describe "Billing engine boot", type: :integration do
  it "loads the engine" do
    expect(defined?(Billing::Engine)).to eq("constant")
  end

  it "registers the five canonical billing events" do
    %w[
      subscription.created.billing
      subscription.updated.billing
      subscription.canceled.billing
      invoice.paid.billing
      invoice.failed.billing
    ].each do |event|
      expect(Seams::EventRegistry.registered?(event)).to be(true)
    end
  end

  it "creates the billing tables from the dummy schema" do
    %i[billing_subscriptions billing_invoices billing_webhook_events billing_plans
       billing_lifetime_passes accounts].each do |t|
      expect(ActiveRecord::Base.connection.table_exists?(t)).to be(true), "missing #{t}"
    end
  end

  it "exposes the Billable concern + the Stripe gateway class" do
    expect(defined?(Billing::Billable)).to          eq("constant")
    expect(defined?(Billing::Gateways::Stripe)).to  eq("constant")
    expect(defined?(Billing::Configuration)).to     eq("constant")
  end

  it "Billing::Configuration ships an Account-default billable_class" do
    expect(Billing.configuration.billable_class).to eq("Accounts::Account")
  end
end
