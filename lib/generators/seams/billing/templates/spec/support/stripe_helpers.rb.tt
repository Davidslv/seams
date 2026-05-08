# frozen_string_literal: true

# Stub helpers for specs that talk to the Stripe REST API via
# Billing::Stripe::Client (the official `stripe` gem, which uses
# Net::HTTP under the hood). WebMock intercepts the request before
# it leaves the process — no live network. The dummy app's
# rails_helper.rb requires "webmock/rspec" automatically when the
# webmock gem is bundled, so individual specs only need:
#
#   require_relative "support/stripe_helpers"
#   RSpec.configure { |c| c.include StripeHelpers }
#
# Usage in a spec:
#
#   stub_stripe(:post, "/v1/checkout/sessions", returns: {
#     id: "cs_test_123", url: "https://stripe.test/cs_test_123"
#   })
#   result = Billing::Checkout::CreateSessionService.call(...)
#   expect(result.value[:id]).to eq("cs_test_123")
#
# Or load a saved fixture:
#
#   stub_stripe_fixture(:post, "/v1/customers", fixture: "customer_created")
module StripeHelpers
  STRIPE_BASE = "https://api.stripe.com"

  def stub_stripe(verb, path, returns:, status: 200)
    WebMock.stub_request(verb, "#{STRIPE_BASE}#{path}")
      .to_return(status: status,
                 headers: { "Content-Type" => "application/json" },
                 body:    returns.to_json)
  end

  def stub_stripe_fixture(verb, path, fixture:, status: 200)
    body = File.read(stripe_fixture_path(fixture))
    WebMock.stub_request(verb, "#{STRIPE_BASE}#{path}")
      .to_return(status: status,
                 headers: { "Content-Type" => "application/json" },
                 body:    body)
  end

  def stub_stripe_failure(verb, path, status:, error_message: "Bad request")
    body = { error: { message: error_message } }.to_json
    WebMock.stub_request(verb, "#{STRIPE_BASE}#{path}")
      .to_return(status: status,
                 headers: { "Content-Type" => "application/json" },
                 body:    body)
  end

  def stripe_event_fixture(name)
    JSON.parse(File.read(stripe_fixture_path(name)), symbolize_names: true)
  end

  private

  def stripe_fixture_path(name)
    File.expand_path("../fixtures/stripe/#{name}.json", __dir__)
  end
end
