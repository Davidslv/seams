# frozen_string_literal: true

module Billing
  class PortalController < ApplicationController
    # POST /billing/portal
    def create
      result = Billing::Portal::CreateSessionService.call(
        customer_ref: current_user.stripe_customer_id,
        return_url:   billing.plans_url
      )

      if result.ok?
        redirect_to result.url, allow_other_host: true, status: :see_other
      else
        redirect_to billing.plans_path, alert: result.error
      end
    end
  end
end
