# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # invoice.finalized — Stripe finalised the draft invoice and is
      # about to attempt collection. Status flips draft → open.
      class InvoiceFinalizedHandler < InvoiceHandlerBase
        SEAMS_EVENT    = "invoice.finalized.billing"
        INVOICE_STATUS = "open"
      end
    end
  end
end
