# frozen_string_literal: true

module Billing
  module Webhooks
    # Async wrapper around the synchronous handler dispatch. Hosts
    # who want sub-100ms webhook responses (Stripe's recommendation —
    # https://docs.stripe.com/webhooks#acknowledge-events-immediately)
    # set Billing.configuration.process_webhooks_async = true and the
    # WebhooksController enqueues this job instead of running the
    # handler in the request thread.
    #
    # The event payload is serialised as a hash so the job survives
    # Active Job's argument restrictions; the handler reconstructs
    # what it needs from that hash.
    class ProcessEventJob < Billing::ApplicationJob
      queue_as :billing

      def perform(gateway:, event_data:)
        event   = symbolize(event_data)
        handler = Billing::Webhooks::EventRouter.handler_for(event[:type])
        return unless handler

        handler.new(event: event, gateway: gateway).call
      end

      private

      def symbolize(hash)
        case hash
        when Hash  then hash.transform_keys(&:to_sym).transform_values { |value| symbolize(value) }
        when Array then hash.map { |element| symbolize(element) }
        else            hash
        end
      end
    end
  end
end
