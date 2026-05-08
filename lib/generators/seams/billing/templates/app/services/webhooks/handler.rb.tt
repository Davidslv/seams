# frozen_string_literal: true

module Billing
  module Webhooks
    # Base class for every webhook handler. Subclasses implement
    # #call which receives a normalised event hash:
    #
    #   { id:, type:, livemode:, object:, raw: }
    #
    # And typically:
    #   1. Upserts the local Billing::Subscription / Billing::Invoice
    #      so downstream subscribers can read from the DB rather than
    #      reparsing the raw payload.
    #   2. Calls #publish with the canonical seams event name + the
    #      shared payload shape.
    #
    # Subclasses MUST set SEAMS_EVENT to the canonical event name
    # (e.g. "subscription.created.billing"). EventRouter routes by the
    # Stripe event type; SEAMS_EVENT is what we re-publish.
    class Handler
      SEAMS_EVENT = nil # override in subclasses

      def initialize(event:, gateway:)
        @event   = event
        @gateway = gateway
      end

      def call
        raise NotImplementedError, "#{self.class} must implement #call"
      end

      protected

      attr_reader :event, :gateway

      def object_hash
        @object_hash ||= begin
          obj = event[:object]
          obj.respond_to?(:to_hash) ? obj.to_hash : obj
        end
      end

      def object_id
        @object_id ||= begin
          obj = event[:object]
          return nil if obj.nil?

          obj.respond_to?(:id) ? obj.id : (obj.is_a?(Hash) && (obj[:id] || obj["id"]))
        end
      end

      def customer_ref
        @customer_ref ||= object_hash.is_a?(Hash) && (object_hash[:customer] || object_hash["customer"])
      end

      # Resolves the Accounts::Account id for this webhook event by
      # cross-referencing the gateway's customer id (`cus_*`) against
      # the local Billing::Subscription mirror. Returns nil if no
      # matching local row exists yet (e.g. the very first
      # `customer.subscription.created` event lands before the local
      # row is upserted; the leaf handler does the upsert and reads
      # account_id off the just-saved row in that case).
      def account_id
        return @account_id if defined?(@account_id)

        @account_id =
          Billing::Subscription.where(customer_ref: customer_ref).pick(:account_id) if customer_ref
      end

      def publish(seams_event = self.class::SEAMS_EVENT, ref: object_id)
        Seams::Events::Publisher.publish(
          seams_event,
          gateway:      gateway,
          livemode:     event[:livemode],
          account_id:   account_id,
          customer_ref: customer_ref,
          ref:          ref,
          object_id:    object_id,
          object:       object_hash
        )
      end

      def warn_upsert_failure(error)
        Seams::Observability.adapter.warn(
          "billing.webhook.upsert_failed",
          engine: "billing",
          event:  self.class::SEAMS_EVENT,
          error:  error.message
        )
      end
    end
  end
end
