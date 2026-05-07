# frozen_string_literal: true

module Billing
  # Audit log of every accepted webhook event. Used to dedupe retries
  # from the gateway (Stripe in particular retries until the endpoint
  # responds 2xx).
  class WebhookEvent < ApplicationRecord
    self.table_name = "billing_webhook_events"

    validates :gateway, :gateway_event_id, :event_type, presence: true
    validates :gateway_event_id, uniqueness: { scope: :gateway }
  end
end
