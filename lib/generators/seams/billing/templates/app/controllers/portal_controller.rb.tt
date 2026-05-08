# frozen_string_literal: true

module Billing
  class PortalController < ApplicationController
    # POST /billing/portal
    def create
      account = current_billing_account
      raise Billing::Error, "current_billing_account is not set" unless account

      result = Billing::Portal::CreateSessionService.call(
        customer_ref: account_customer_ref(account),
        return_url:   billing.plans_url
      )

      if result.ok?
        redirect_to result.url, allow_other_host: true, status: :see_other
      else
        redirect_to billing.plans_path, alert: result.error
      end
    end

    private

    # Reads the Stripe customer id off any existing billing row for
    # this Account. Avoids a synchronous Stripe API call — the
    # portal is only meaningful when the Account already has a
    # subscription anyway.
    def account_customer_ref(account)
      account.billing_subscriptions.pick(:customer_ref) ||
        account.billing_invoices.pick(:customer_ref) ||
        account.billing_lifetime_passes.pick(:customer_ref) ||
        raise(Billing::Error, "Account has no billing customer_ref yet — create a subscription or LTD first.")
    end

    # See CheckoutController#current_billing_account — same default.
    def current_billing_account
      return @current_billing_account if defined?(@current_billing_account)

      @current_billing_account =
        if defined?(Accounts::Current) && Accounts::Current.respond_to?(:account)
          Accounts::Current.account
        end
    end
  end
end
