# frozen_string_literal: true

module Billing
  # Receives webhook callbacks from the configured payment gateway.
  # The gateway adapter does the signature verification — we just
  # record the event for idempotency and route it to the handler
  # that knows how to process that event type.
  #
  # Trust boundary: the request body is treated as untrusted until
  # the gateway adapter's `verify_webhook` returns. CSRF is
  # intentionally skipped (webhooks come from Stripe, not a browser
  # session) — DO NOT add authentication here; the signature IS the
  # authentication.
  #
  # Idempotent: every accepted event is recorded by gateway+event_id;
  # retries hit the unique index and short-circuit before any handler
  # fires. Stripe explicitly requires this — retries can span days
  # (https://docs.stripe.com/webhooks#handle-duplicate-events).
  #
  # Sync vs async: by default the handler runs in the request thread.
  # Set Billing.configuration.process_webhooks_async = true to enqueue
  # Billing::Webhooks::ProcessEventJob instead — Stripe recommends
  # responding in <100ms (https://docs.stripe.com/webhooks#acknowledge-events-immediately).
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    # POST /billing/webhooks/stripe
    def stripe
      payload   = request.body.read
      signature = request.headers["Stripe-Signature"]

      event = Billing.gateway.verify_webhook(
        payload:   payload,
        signature: signature,
        secret:    Billing.configuration.webhook_secret
      )

      record_and_dispatch("stripe", event)
      head :ok
    rescue Billing::WebhookError => e
      Seams::Observability.adapter.warn(
        "billing.webhook.invalid", engine: "billing", error: e.message
      )
      head :bad_request
    end

    private

    # Insert WebhookEvent FIRST inside a transaction that ALSO runs
    # the handler. If the handler raises, the WebhookEvent row rolls
    # back — Stripe retries, we get another chance to publish.
    # Otherwise a transient handler bug would permanently drop one
    # event behind the unique-index guard. Async path skips the
    # transaction (the job has its own retry semantics).
    def record_and_dispatch(gateway, event)
      Billing::WebhookEvent.transaction do
        Billing::WebhookEvent.create!(
          gateway:          gateway,
          gateway_event_id: event[:id] || object_id_for(event[:object]),
          event_type:       event[:type],
          livemode:         event[:livemode]
        )

        dispatch(gateway: gateway, event: event)
      end
    rescue ActiveRecord::RecordNotUnique
      # Duplicate retry — Stripe will keep retrying; replying 200 stops
      # the storm without re-publishing to subscribers.
      Seams::Observability.adapter.info(
        "billing.webhook.duplicate", engine: "billing",
        gateway: gateway, event_type: event[:type]
      )
    end

    def dispatch(gateway:, event:)
      if Billing.configuration.process_webhooks_async
        Billing::Webhooks::ProcessEventJob.perform_later(
          gateway: gateway, event_data: event.deep_stringify_keys
        )
      else
        run_handler(gateway: gateway, event: event)
      end
    end

    def run_handler(gateway:, event:)
      handler_class = Billing::Webhooks::EventRouter.handler_for(event[:type])
      return unless handler_class

      handler_class.new(event: event, gateway: gateway).call
    end

    def object_id_for(object)
      return nil if object.nil?

      object.respond_to?(:id) ? object.id : (object.is_a?(Hash) && (object[:id] || object["id"]))
    end
  end
end
