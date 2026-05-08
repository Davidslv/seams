# frozen_string_literal: true

require "stripe"

module Billing
  module Stripe
    # Verifies the Stripe-Signature header on incoming webhooks via
    # the official `stripe` gem's first-party helper.
    #
    # Stripe maintains the verification logic — HMAC-SHA256 over
    # `<timestamp>.<payload>`, 5-minute tolerance window, multiple
    # v1= entries for key rotation, constant-time comparison. We used
    # to reimplement this against https://docs.stripe.com/webhooks/signatures
    # in a hand-rolled HMAC module; that decision was reversed in
    # 2026-05 because Stripe ships breaking changes to the signing
    # scheme over time and the gem tracks them as a first-class
    # commitment.
    #
    # Public surface preserved (verify!) so callers (Billing::Gateways::Stripe)
    # don't need to change. Stripe::SignatureVerificationError is
    # rethrown as Billing::WebhookError to keep the engine's error
    # boundary intact.
    module WebhookSignature
      DEFAULT_TOLERANCE = 300  # seconds — matches Stripe's default

      module_function

      # Returns the parsed Stripe::Event on success; raises
      # Billing::WebhookError on any failure mode (no header,
      # malformed header, no v1, no matching v1, timestamp outside
      # tolerance, malformed JSON).
      def verify!(payload:, signature_header:, secret:, tolerance: DEFAULT_TOLERANCE)
        raise Billing::WebhookError, "Stripe-Signature header missing" if signature_header.nil? || signature_header.empty?

        ::Stripe::Webhook.construct_event(payload, signature_header, secret, tolerance: tolerance)
      rescue ::Stripe::SignatureVerificationError => e
        raise Billing::WebhookError, "Stripe signature invalid: #{e.message}"
      rescue JSON::ParserError => e
        raise Billing::WebhookError, "Stripe payload not JSON: #{e.message}"
      end
    end
  end
end
