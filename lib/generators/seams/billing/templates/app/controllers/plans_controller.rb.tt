# frozen_string_literal: true

module Billing
  class PlansController < ApplicationController
    def index
      @recurring_plans = Billing::Plan.active.recurring.order(:amount_cents)
      # LTD plans grouped separately on the pricing page so the host
      # can render them under a "buy once, own forever" section.
      # `lifetime_inventory_remaining` is nil for unlimited; integer
      # for capped (used by the view to show "X seats left").
      @lifetime_plans = Billing::Plan.active.lifetime.order(:amount_cents)
    end
  end
end
