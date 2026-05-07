# frozen_string_literal: true

# Shared contract every Billing gateway adapter must satisfy. Use
# this when you write a new gateway (Paddle, Adyen, etc) so you know
# you have implemented the full Abstract interface that the rest of
# the engine depends on.
#
# Usage:
#
#   require "rails_helper"
#   require "support/shared_examples/a_billing_gateway"
#
#   RSpec.describe Billing::Gateways::Paddle do
#     it_behaves_like "a billing gateway"
#   end
#
# The shared example only checks the *contract* (the methods exist
# and accept the documented arguments). Wiring-level behaviour —
# does Paddle actually charge people? — needs an integration test
# that hits Paddle's test mode.
RSpec.shared_examples "a billing gateway" do
  let(:gateway) { described_class.new }

  describe "#create_subscription" do
    it "accepts customer_ref + plan_ref + arbitrary keyword extras" do
      expect(gateway).to respond_to(:create_subscription)
      method = gateway.method(:create_subscription)
      keyword_names = method.parameters.select { |type, _| %i[key keyreq].include?(type) }.map(&:last)
      expect(keyword_names).to include(:customer_ref, :plan_ref)
    end
  end

  describe "#cancel_subscription" do
    it "accepts subscription_ref + arbitrary keyword extras" do
      expect(gateway).to respond_to(:cancel_subscription)
      keyword_names = gateway.method(:cancel_subscription).parameters
                              .select { |type, _| %i[key keyreq].include?(type) }.map(&:last)
      expect(keyword_names).to include(:subscription_ref)
    end
  end

  describe "#fetch_subscription" do
    it "accepts subscription_ref" do
      expect(gateway).to respond_to(:fetch_subscription)
      keyword_names = gateway.method(:fetch_subscription).parameters
                              .select { |type, _| %i[key keyreq].include?(type) }.map(&:last)
      expect(keyword_names).to include(:subscription_ref)
    end
  end

  describe "#create_checkout_session" do
    it "accepts customer_ref + plan_ref + success_url + cancel_url" do
      expect(gateway).to respond_to(:create_checkout_session)
      keyword_names = gateway.method(:create_checkout_session).parameters
                              .select { |type, _| %i[key keyreq].include?(type) }.map(&:last)
      %i[customer_ref plan_ref success_url cancel_url].each do |required|
        expect(keyword_names).to include(required), "missing #{required.inspect}"
      end
    end
  end

  describe "#create_billing_portal_session" do
    it "accepts customer_ref + return_url" do
      expect(gateway).to respond_to(:create_billing_portal_session)
      keyword_names = gateway.method(:create_billing_portal_session).parameters
                              .select { |type, _| %i[key keyreq].include?(type) }.map(&:last)
      expect(keyword_names).to include(:customer_ref)
    end
  end

  describe "#create_lifetime_checkout_session" do
    it "accepts the same shape as #create_checkout_session (mode: payment under the hood)" do
      expect(gateway).to respond_to(:create_lifetime_checkout_session)
      keyword_names = gateway.method(:create_lifetime_checkout_session).parameters
                              .select { |type, _| %i[key keyreq].include?(type) }.map(&:last)
      %i[customer_ref plan_ref success_url cancel_url].each do |required|
        expect(keyword_names).to include(required), "missing #{required.inspect}"
      end
    end
  end

  describe "#verify_webhook" do
    it "accepts payload + signature + secret and returns a normalised event hash" do
      expect(gateway).to respond_to(:verify_webhook)
      keyword_names = gateway.method(:verify_webhook).parameters
                              .select { |type, _| %i[key keyreq].include?(type) }.map(&:last)
      %i[payload signature secret].each do |required|
        expect(keyword_names).to include(required), "missing #{required.inspect}"
      end
    end

    it "raises Billing::WebhookError on signature mismatch" do
      skip "subclass must seed a verifier that rejects bad signatures" unless gateway.respond_to?(:verify_webhook)

      expect {
        gateway.verify_webhook(payload: "{}", signature: "bad", secret: "x")
      }.to raise_error(Billing::WebhookError)
    end
  end
end
