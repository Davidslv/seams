# frozen_string_literal: true

module Billing
  # Read-only billing history. The local Billing::Invoice rows are
  # populated by the InvoiceHandlerBase webhook handlers as Stripe
  # fires invoice.* events; SyncService can refresh on demand.
  #
  # No `download` action — Stripe hosts the PDF; link to the
  # `hosted_invoice_url` Stripe returns on the invoice object. Saves
  # us from being a redirect proxy for content we do not own.
  #
  #   GET /billing/invoices       → index (paginated history)
  #   GET /billing/invoices/:id   → show
  class InvoicesController < ApplicationController
    before_action :require_invoice, only: %i[show]

    def index
      @invoices = scoped_invoices.order(created_at: :desc)
    end

    def show
      # @invoice is set by require_invoice. Hosts that want a fresh
      # read from Stripe before rendering can opt in:
      #
      #   Billing::Invoices::SyncService.call(invoice_ref: @invoice.gateway_ref)
      #
      # The default render is the local DB row — webhook lag is
      # usually <1s, so this is good enough for almost every UI.
    end

    private

    def scoped_invoices
      Billing::Invoice.where(customer_ref: current_billing_customer_ref)
    end

    def require_invoice
      @invoice = scoped_invoices.find_by(id: params[:id])
      return if @invoice

      redirect_to invoices_path, alert: "Invoice not found."
    end

    def current_billing_customer_ref
      return current_user.billing_customer_ref if current_user.respond_to?(:billing_customer_ref)

      raise NotImplementedError,
            "Override #current_billing_customer_ref in your host InvoicesController " \
            "to point at your User's billing customer reference."
    end
  end
end
