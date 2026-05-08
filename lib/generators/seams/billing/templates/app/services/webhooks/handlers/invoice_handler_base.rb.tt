# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # Shared base for the five invoice.* handlers. Owns the upsert
      # of Billing::Invoice. Subclasses set SEAMS_EVENT + INVOICE_STATUS.
      #
      # Account resolution mirrors SubscriptionHandlerBase: the
      # invoice belongs to the same Account as the subscription it
      # references; we resolve account_id by walking
      # subscription_ref → Billing::Subscription#account_id, falling
      # back to a sibling Billing::Invoice on the same customer_ref
      # for one-off invoices that have no subscription.
      class InvoiceHandlerBase < Billing::Webhooks::Handler
        DEFAULT_STATUS = "open"

        def call
          upsert_invoice
          publish
        end

        protected

        def upsert_invoice
          return unless object_id && customer_ref && object_hash.is_a?(Hash)

          invoice = Billing::Invoice.find_or_initialize_by(gateway_ref: object_id)
          resolved_account_id = invoice.account_id || resolve_account_id_for_invoice
          unless resolved_account_id
            warn_upsert_failure(
              StandardError.new("could not resolve account_id for customer_ref=#{customer_ref}")
            )
            return
          end

          invoice.account_id       = resolved_account_id
          invoice.customer_ref     = customer_ref
          invoice.subscription_ref = object_hash[:subscription] || object_hash["subscription"]
          invoice.amount_cents     = object_hash[:amount_paid] || object_hash["amount_paid"] ||
                                     object_hash[:amount_due]  || object_hash["amount_due"]  || 0
          invoice.currency         = (object_hash[:currency] || object_hash["currency"] || "usd").to_s.upcase
          invoice.status           = invoice_status
          invoice.paid_at          = paid_at_for_status
          invoice.save!
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          warn_upsert_failure(e)
        end

        # First, try the subscription_ref → Subscription mirror.
        # Fall back to any sibling Invoice on the same customer.
        # Final fallback is a Subscription row on the same
        # customer_ref (covers the case of a one-off invoice that
        # arrives before any sibling Invoice).
        def resolve_account_id_for_invoice
          subscription_ref = object_hash[:subscription] || object_hash["subscription"]
          if subscription_ref
            id = Billing::Subscription.where(gateway_ref: subscription_ref).pick(:account_id)
            return id if id
          end

          Billing::Invoice.where(customer_ref: customer_ref)
                          .where.not(account_id: nil)
                          .pick(:account_id) ||
            Billing::Subscription.where(customer_ref: customer_ref)
                                 .where.not(account_id: nil)
                                 .pick(:account_id)
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
