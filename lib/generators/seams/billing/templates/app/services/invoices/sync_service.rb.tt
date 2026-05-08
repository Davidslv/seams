# frozen_string_literal: true

module Billing
  module Invoices
    # Fetches an invoice from Stripe and upserts the local
    # Billing::Invoice row. Used by the invoice.* webhook handlers
    # for retries / out-of-order delivery, and by the
    # InvoicesController for on-demand refresh when a host wants the
    # latest status without waiting for the next webhook.
    #
    #   result = Billing::Invoices::SyncService.call(invoice_ref: "in_xyz")
    #   result.value.status   # => "paid"
    class SyncService < Billing::StripeService
      def initialize(invoice_ref:)
        @invoice_ref = invoice_ref
      end

      def call_stripe(client)
        client.retrieve_invoice(@invoice_ref)
      end

      def on_success(stripe_response)
        invoice = Billing::Invoice.find_or_initialize_by(gateway_ref: stripe_response[:id])
        invoice.assign_attributes(
          customer_ref:     stripe_response[:customer],
          subscription_ref: stripe_response[:subscription],
          status:           stripe_response[:status],
          amount_cents:     stripe_response[:amount_paid] || stripe_response[:amount_due],
          currency:         stripe_response[:currency].to_s.upcase,
          paid_at:          paid_at_for(stripe_response)
        )
        invoice.save!

        ServiceResult.ok(value: invoice)
      end

      private

      # Stripe moved the paid timestamp out of the top-level invoice
      # object into status_transitions.paid_at — see
      # https://docs.stripe.com/api/invoices/object#invoice_object-status_transitions.
      # We still tolerate a top-level :paid_at on older API versions.
      def paid_at_for(stripe_response)
        unix = stripe_response.dig(:status_transitions, :paid_at) ||
               stripe_response[:paid_at]
        unix && Time.at(unix)
      end
    end
  end
end
