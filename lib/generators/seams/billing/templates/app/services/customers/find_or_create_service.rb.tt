# frozen_string_literal: true

require "digest"

module Billing
  module Customers
    # Resolves a Stripe customer for an Accounts::Account. Looks up by
    # `email` first via /v1/customers/search; creates a new one if no
    # match is found. Returns ServiceResult with `value: customer_ref`
    # (the Stripe `cus_*` id).
    #
    #   result = Billing::Customers::FindOrCreateService.call(
    #     email: "owner@acme.com",
    #     metadata: { account_id: "5e3b...", account_name: "Acme Inc" }
    #   )
    #   result.ok?         # => true
    #   result.value       # => "cus_xyz"
    #
    # Idempotent — re-running with the same email returns the same
    # customer_ref. Stripe's `/v1/customers/search` index is eventually
    # consistent (the docs quote a "less than a minute" delay:
    # https://docs.stripe.com/api/customers/search), so two
    # near-simultaneous signups for the same email can both miss the
    # search and both fall through to `POST /v1/customers`. Stripe
    # does not dedupe customers by email server-side, so without
    # protection that produces two `cus_*` rows for the same person.
    #
    # We defend against that with a deterministic Stripe
    # `Idempotency-Key` header derived from the email plus the
    # caller-supplied scope (typically `account_id` — the tenant the
    # customer represents). Per
    # https://docs.stripe.com/api/idempotent_requests Stripe caches
    # the response for at least 24h and replays it for the same key,
    # so two concurrent calls with the same key produce one customer.
    # The key is SHA-256(email:scope) so it stays well under the 255-
    # character ceiling and is stable across retries.
    class FindOrCreateService < Billing::StripeService
      def initialize(email:, metadata: {})
        @email    = email
        @metadata = metadata
      end

      def call_stripe(client)
        existing = client.search_customers(query: %(email:"#{@email}"), limit: 1)
        return existing[:data].first if existing[:data].any?

        client.create_customer(
          email:           @email,
          metadata:        @metadata,
          idempotency_key: idempotency_key
        )
      end

      def on_success(stripe_response)
        ServiceResult.ok(value: stripe_response[:id])
      end

      private

      # Deterministic per-(email, scope) key. SHA-256 hex is 64 chars
      # — well within Stripe's 255-character limit
      # (https://docs.stripe.com/api/idempotent_requests). The
      # `seams:billing:customer:` prefix namespaces the key so it
      # cannot collide with other engines that share the same Stripe
      # account. Scope defaults to the caller-supplied `account_id`
      # (the tenant the Stripe customer represents post-Wave-9).
      def idempotency_key
        scope = @metadata[:account_id] || @metadata["account_id"] || ""
        Digest::SHA256.hexdigest("seams:billing:customer:#{@email}:#{scope}")
      end
    end
  end
end
