# frozen_string_literal: true

module Billing
  # Base class for service objects that talk to Stripe via
  # Billing::Stripe::Client. Subclasses define #call_stripe and the
  # base wraps it in uniform error handling that converts Faraday
  # errors + Billing::Stripe::Client errors into ServiceResult
  # failures with stable codes.
  #
  #   class MyService < Billing::StripeService
  #     def initialize(plan_ref:)
  #       @plan_ref = plan_ref
  #     end
  #
  #     def call_stripe(client)
  #       client.create_checkout_session(...)
  #     end
  #
  #     def on_success(stripe_response)
  #       ServiceResult.ok(value: stripe_response)
  #     end
  #   end
  #
  #   MyService.call(plan_ref: "p_pro")
  class StripeService
    def self.call(**kwargs)
      new(**kwargs).call
    end

    # Override in subclasses. Receives a configured
    # Billing::Stripe::Client. Return whatever the Stripe call
    # returns — the base class translates it via #on_success.
    def call_stripe(_client)
      raise NotImplementedError, "#{self.class} must implement #call_stripe"
    end

    # Override to shape the Stripe response into the service's public
    # ServiceResult value. Default: pass the raw response through.
    def on_success(stripe_response)
      ServiceResult.ok(value: stripe_response)
    end

    def call
      on_success(call_stripe(client))
    rescue Billing::GatewayError => e
      # The Faraday-based Billing::Stripe::Client raises
      # Billing::GatewayError on 4xx/5xx, network failures, and
      # auth errors. Sub-classify by message prefix so callers can
      # branch on `result.code`.
      ServiceResult.failure(error: e.message, code: classify_gateway_error(e))
    end

    private

    def classify_gateway_error(error)
      case error.message
      when /connection error|TimeoutError|ConnectionFailed/i then :gateway_unreachable
      when /authentication|invalid api key/i                 then :gateway_auth
      else                                                        :gateway_error
      end
    end

    def client
      @client ||= Billing::Stripe::Client.new(api_key: Billing.configuration.api_key)
    end
  end
end
