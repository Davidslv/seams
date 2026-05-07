# frozen_string_literal: true

module Billing
  module Webhooks
    # Maps a Stripe event type → the handler class that processes it.
    # Hosts extend the map by reopening this module in an initializer:
    #
    #   Billing::Webhooks::EventRouter.register(
    #     "customer.tax_id.created",
    #     "MyHost::TaxIdCreatedHandler"
    #   )
    #
    # Returns nil for unmapped events so the controller can no-op
    # without raising — Stripe sends events the host hasn't subscribed
    # to and that's normal.
    module EventRouter
      HANDLERS = {
        "customer.subscription.created"          => "Billing::Webhooks::Handlers::SubscriptionCreatedHandler",
        "customer.subscription.updated"          => "Billing::Webhooks::Handlers::SubscriptionUpdatedHandler",
        "customer.subscription.deleted"          => "Billing::Webhooks::Handlers::SubscriptionDeletedHandler",
        "customer.subscription.trial_will_end"   => "Billing::Webhooks::Handlers::SubscriptionTrialWillEndHandler",
        "invoice.created"                        => "Billing::Webhooks::Handlers::InvoiceCreatedHandler",
        "invoice.paid"                           => "Billing::Webhooks::Handlers::InvoicePaidHandler",
        "invoice.payment_failed"                 => "Billing::Webhooks::Handlers::InvoicePaymentFailedHandler",
        "invoice.finalized"                      => "Billing::Webhooks::Handlers::InvoiceFinalizedHandler",
        "invoice.voided"                         => "Billing::Webhooks::Handlers::InvoiceVoidedHandler",
        "payment_intent.succeeded"               => "Billing::Webhooks::Handlers::PaymentSucceededHandler",
        "payment_intent.payment_failed"          => "Billing::Webhooks::Handlers::PaymentFailedHandler",
        "charge.refunded"                        => "Billing::Webhooks::Handlers::ChargeRefundedHandler",
        "checkout.session.completed"             => "Billing::Webhooks::Handlers::CheckoutSessionCompletedHandler",
        "checkout.session.async_payment_succeeded" => "Billing::Webhooks::Handlers::CheckoutSessionCompletedHandler"
      }

      module_function

      def register(stripe_event_type, handler_class_name)
        HANDLERS[stripe_event_type] = handler_class_name
      end

      def handler_for(stripe_event_type)
        klass_name = HANDLERS[stripe_event_type]
        return nil unless klass_name

        klass_name.constantize
      end

      def supported_event_types
        HANDLERS.keys
      end
    end
  end
end
