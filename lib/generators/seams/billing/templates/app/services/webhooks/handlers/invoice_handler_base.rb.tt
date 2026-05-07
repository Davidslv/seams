# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # Shared base for the five invoice.* handlers. Owns the upsert
      # of Billing::Invoice. Subclasses set SEAMS_EVENT + INVOICE_STATUS.
      class InvoiceHandlerBase < Billing::Webhooks::Handler
        DEFAULT_STATUS = "open"

        def call
          upsert_invoice
          publish
        end

        protected

        def upsert_invoice
          return unless object_id && customer_ref && object_hash.is_a?(Hash)

          Billing::Invoice
            .find_or_initialize_by(gateway_ref: object_id)
            .tap do |invoice|
              invoice.customer_ref     = customer_ref
              invoice.subscription_ref = object_hash[:subscription] || object_hash["subscription"]
              invoice.amount_cents     = object_hash[:amount_paid] || object_hash["amount_paid"] ||
                                         object_hash[:amount_due]  || object_hash["amount_due"]  || 0
              invoice.currency         = (object_hash[:currency] || object_hash["currency"] || "usd").to_s.upcase
              invoice.status           = invoice_status
              invoice.paid_at          = paid_at_for_status
              invoice.save!
            end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          warn_upsert_failure(e)
        end

        def invoice_status
          self.class::INVOICE_STATUS || DEFAULT_STATUS
        end

        def paid_at_for_status
          invoice_status == "paid" ? Time.current : nil
        end
      end
    end
  end
end
