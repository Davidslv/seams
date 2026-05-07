# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # payment_intent.succeeded — a one-off payment cleared. No local
      # row to upsert (PaymentIntents are not modelled locally — see
      # Phase 3A scope review). Just publishes the canonical event so
      # subscribers can react (notifications, audit log, etc).
      class PaymentSucceededHandler < Billing::Webhooks::Handler
        SEAMS_EVENT = "payment.succeeded.billing"

        def call
          publish
        end
      end
    end
  end
end
