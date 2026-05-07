# frozen_string_literal: true

module Billing
  module Webhooks
    module Handlers
      # charge.refunded — full or partial refund applied. Subscribers
      # typically use this to revoke access, send a refund-receipt
      # email, or reverse internal credit grants.
      class ChargeRefundedHandler < Billing::Webhooks::Handler
        SEAMS_EVENT = "charge.refunded.billing"

        def call
          publish
        end
      end
    end
  end
end
