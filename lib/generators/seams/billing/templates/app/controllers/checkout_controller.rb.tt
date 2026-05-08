# frozen_string_literal: true

module Billing
  class CheckoutController < ApplicationController
    # POST /billing/checkout?plan=price_xxx
    def create
      plan = Billing::Plan.active.find_by!(gateway_ref: params[:plan])

      result = Billing::Checkout::CreateSessionService.call(
        customer_ref: customer_ref_or_create!,
        plan_ref:     plan.gateway_ref,
        success_url:  billing.checkout_success_url,
        cancel_url:   billing.plans_url
      )

      if result.ok?
        redirect_to result.url, allow_other_host: true, status: :see_other
      else
        redirect_to billing.plans_path, alert: result.error
      end
    end

    # GET /billing/checkout/success
    def success
      # Stripe will fire `checkout.session.completed` webhook; the
      # subscription row gets created/updated by the webhook handler.
      render :success
    end

    # POST /billing/checkout/lifetime?plan=price_xxx
    # LTD purchase flow — same shape as #create but uses Stripe's
    # `mode: "payment"`. The webhook handler distinguishes the two via
    # session.metadata.access_type.
    def lifetime
      plan = Billing::Plan.active.find_by!(gateway_ref: params[:plan])

      result = Billing::Lifetime::CreateLifetimeSessionService.call(
        account_id:   current_billing_account.id,
        customer_ref: customer_ref_or_create!,
        plan_ref:     plan.gateway_ref,
        success_url:  billing.checkout_success_url,
        cancel_url:   billing.plans_url
      )

      if result.ok?
        redirect_to result.url, allow_other_host: true, status: :see_other
      else
        redirect_to billing.plans_path, alert: result.error
      end
    end

    private

    # Resolves the Stripe customer id for the current Account. The
    # host must implement `current_billing_account` (or set it from
    # a before_action) — typically `Accounts::Current.account`.
    # Hosts pre-Wave-9 can override the entire method to use their
    # own user-keyed lookup.
    def customer_ref_or_create!
      account = current_billing_account
      raise Billing::Error, "current_billing_account is not set" unless account
      raise Billing::Error, "Account #{account.id} does not respond to stripe_customer_ref!" unless account.respond_to?(:stripe_customer_ref!)

      account.stripe_customer_ref!(email: billing_contact_email_for(account))
    end

    # Override in the host to point at the right contact email for
    # the Stripe customer record. Default reads `current_user.email`
    # if the host's auth concern wires one up — usually the right
    # answer for B2C flows. B2B hosts often want the Account owner's
    # email instead; override accordingly.
    def billing_contact_email_for(_account)
      return current_user.email_address if respond_to?(:current_user) && current_user.respond_to?(:email_address)
      return current_user.email if respond_to?(:current_user) && current_user.respond_to?(:email)

      raise Billing::Error,
            "Override #billing_contact_email_for(account) to supply the Stripe customer email."
    end

    # Default implementation reads `Accounts::Current.account` if the
    # accounts engine is installed. Override in the host if your
    # Account is bound differently (e.g. via params, subdomain, etc).
    def current_billing_account
      return @current_billing_account if defined?(@current_billing_account)

      @current_billing_account =
        if defined?(Accounts::Current) && Accounts::Current.respond_to?(:account)
          Accounts::Current.account
        end
    end
  end
end
