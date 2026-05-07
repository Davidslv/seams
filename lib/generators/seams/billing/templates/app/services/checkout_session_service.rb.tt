# frozen_string_literal: true

module Billing
  module Checkout
    # Creates a hosted-checkout session for a given customer + plan.
    # Returns a Result with ok?, url, error.
    module CreateSessionService
      Result = Struct.new(:ok?, :url, :error, keyword_init: true)

      module_function

      def call(customer_ref:, plan_ref:, success_url:, cancel_url:)
        session = Billing.gateway.create_checkout_session(
          customer_ref: customer_ref,
          plan_ref:     plan_ref,
          success_url:  success_url,
          cancel_url:   cancel_url
        )
        Result.new(ok?: true, url: session[:url])
      rescue Billing::GatewayError => e
        Result.new(ok?: false, error: e.message)
      end
    end
  end
end
