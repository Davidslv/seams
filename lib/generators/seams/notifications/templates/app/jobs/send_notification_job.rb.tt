# frozen_string_literal: true

module Notifications
  # Sends a single Notification by id. Uses find_by so a row deleted
  # between enqueue and execution silently no-ops instead of raising.
  class SendNotificationJob < ApplicationJob
    queue_as :notifications

    def perform(notification_id)
      Notifications::Notification.find_by(id: notification_id)&.send!
    end
  end
end
