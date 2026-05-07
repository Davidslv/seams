# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # Stripe sends customer.subscription.deleted when the
      # subscription has actually ended (period elapsed after a
      # period-end cancel, or immediate cancellation). The local
      # status flips to "canceled".
      class SubscriptionDeletedHandler < SubscriptionHandlerBase
        SEAMS_EVENT = "subscription.canceled.billing"
      end
    end
  end
end
