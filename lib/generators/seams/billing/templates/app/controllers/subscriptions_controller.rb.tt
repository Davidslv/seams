# frozen_string_literal: true

module Billing
  # Self-service subscription management for the current Account.
  # Backed by the Phase 3 (2/4) service objects — every action is a
  # thin wrapper that calls a service and renders / redirects on the
  # ServiceResult.
  #
  # Routes (from config/routes.rb):
  #
  #   GET    /billing/subscriptions          → index   (list)
  #   GET    /billing/subscriptions/:id      → show
  #   DELETE /billing/subscriptions/:id      → cancel  (period-end by default)
  #   POST   /billing/subscriptions/:id/reactivate
  #   POST   /billing/subscriptions/:id/change_plan
  #
  # The host's authentication concern decides who `current_user` is —
  # this controller scopes by the current Account (the tenant), not
  # the human. Subscriptions belong to Accounts::Account post-Wave-9.
  class SubscriptionsController < ApplicationController
    before_action :require_subscription, only: %i[show cancel reactivate change_plan]

    def index
      @subscriptions = scoped_subscriptions.order(created_at: :desc)
    end

    def show
      # @subscription is set by require_subscription
    end

    # DELETE /billing/subscriptions/:id
    # Default: cancel at period end (user keeps access through what
    # they have already paid for). Pass ?immediate=1 to cancel now.
    def cancel
      result = Billing::Subscriptions::CancelService.call(
        subscription_ref: @subscription.gateway_ref,
        immediate:        params[:immediate].present?
      )

      respond_to_result(result, success: "Subscription cancelled.")
    end

    # POST /billing/subscriptions/:id/reactivate
    # Un-cancel a subscription that is pending end-of-period cancellation.
    def reactivate
      result = Billing::Subscriptions::ReactivateService.call(
        subscription_ref: @subscription.gateway_ref
      )

      respond_to_result(result, success: "Subscription reactivated.")
    end

    # POST /billing/subscriptions/:id/change_plan
    #   params[:price_ref]          — required, the new Stripe price id
    #   params[:proration_behavior] — optional, "create_prorations" (default) | "none"
    def change_plan
      new_price = params[:price_ref].to_s
      if new_price.empty?
        redirect_to subscription_path(@subscription),
                    alert: "Choose a plan before submitting."
        return
      end

      result = Billing::Subscriptions::ChangePlanService.call(
        subscription_ref:    @subscription.gateway_ref,
        new_price_ref:       new_price,
        proration_behavior:  params[:proration_behavior].presence || "create_prorations"
      )

      respond_to_result(result, success: "Plan changed.")
    end

    private

    # Override in the host (or here) to scope by the current Account's
    # billing rows. The default scopes by `current_billing_customer_ref`
    # — the Stripe `cus_*` id resolved from the current Account — which
    # is correct whenever the controller has an Account in scope.
    def scoped_subscriptions
      Billing::Subscription.where(customer_ref: current_billing_customer_ref)
    end

    def require_subscription
      @subscription = scoped_subscriptions.find_by(id: params[:id])
      return if @subscription

      redirect_to subscriptions_path, alert: "Subscription not found."
    end

    # Reads the Stripe customer id off the current Account. Hosts on
    # a pre-Wave-9 user-keyed flow can override this method to point
    # at their User's own `billing_customer_ref` accessor.
    def current_billing_customer_ref
      account = current_billing_account
      return nil unless account

      account.billing_subscriptions.pick(:customer_ref) ||
        account.billing_invoices.pick(:customer_ref) ||
        account.billing_lifetime_passes.pick(:customer_ref)
    end

    def current_billing_account
      return @current_billing_account if defined?(@current_billing_account)

      @current_billing_account =
        if defined?(Accounts::Current) && Accounts::Current.respond_to?(:account)
          Accounts::Current.account
        end
    end

    def respond_to_result(result, success:)
      if result.ok?
        redirect_to subscriptions_path, notice: success
      else
        redirect_to subscription_path(@subscription), alert: result.error
      end
    end
  end
end
