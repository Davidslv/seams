# frozen_string_literal: true

module Notifications
  # One row per successful +Notification#send!+. Useful audit trail
  # and the basis for "when did we last send?" queries that don't
  # need to load the gateway.
  class Delivery < ApplicationRecord
    self.table_name = "notification_deliveries"

    belongs_to :notification, class_name: "Notifications::Notification",
                              inverse_of: :deliveries
  end
end
