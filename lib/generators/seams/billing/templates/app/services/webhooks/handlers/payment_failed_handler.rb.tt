# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      class PaymentFailedHandler < Billing::Webhooks::Handler
        SEAMS_EVENT = "payment.failed.billing"

        def call
          publish
        end
      end
    end
  end
end
