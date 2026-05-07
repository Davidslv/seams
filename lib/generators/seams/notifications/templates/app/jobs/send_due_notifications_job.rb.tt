# frozen_string_literal: true

module Notifications
  # Recurring sweeper. Finds every Notification whose +next_delivery_at+
  # has passed and enqueues a +SendNotificationJob+ for each. Per-row
  # jobs let each notification retry / rate-limit independently.
  #
  # Wire into your queue's recurring scheduler. With Rails 8's Solid
  # Queue, add to config/recurring.yml:
  #
  #   production:
  #     notifications_dispatcher:
  #       class: Notifications::SendDueNotificationsJob
  #       schedule: every minute
  class SendDueNotificationsJob < ApplicationJob
    queue_as :notifications

    def perform
      Notifications::Notification.due.find_each(&:send_async)
    end
  end
end
