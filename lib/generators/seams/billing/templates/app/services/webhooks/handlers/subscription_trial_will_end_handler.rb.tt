# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # Fires ~3 days before a trialing subscription transitions to
      # active. Hosts subscribe to send "your trial is ending" email.
      # Verified against
      # https://docs.stripe.com/api/events/types#event_types-customer.subscription.trial_will_end
      class SubscriptionTrialWillEndHandler < SubscriptionHandlerBase
        SEAMS_EVENT = "subscription.trial_will_end.billing"
      end
    end
  end
end
