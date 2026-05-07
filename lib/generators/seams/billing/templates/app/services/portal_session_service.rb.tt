# frozen_string_literal: true

module Billing
  module Portal
    # Creates a customer-portal session — Stripe-hosted UI for the
    # user to manage their subscription. Returns Result(ok?, url, error).
    module CreateSessionService
      Result = Struct.new(:ok?, :url, :error, keyword_init: true)

      module_function

      def call(customer_ref:, return_url:)
        session = Billing.gateway.create_billing_portal_session(
          customer_ref: customer_ref,
          return_url:   return_url
        )
        Result.new(ok?: true, url: session[:url])
      rescue Billing::GatewayError => e
        Result.new(ok?: false, error: e.message)
      end
    end
  end
end
