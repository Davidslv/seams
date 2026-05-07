# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # invoice.created fires when Stripe drafts a new invoice (e.g.
      # at the start of a billing period). Status is "draft" until
      # finalised. Hosts rarely need to act on this — included for
      # full audit coverage.
      class InvoiceCreatedHandler < InvoiceHandlerBase
        SEAMS_EVENT    = "invoice.created.billing"
        INVOICE_STATUS = "draft"
      end
    end
  end
end
