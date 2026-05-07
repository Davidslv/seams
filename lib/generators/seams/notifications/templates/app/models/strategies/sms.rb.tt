# frozen_string_literal: true

module Notifications
  module Strategies
    # SMS notification. +#dispatch!+ delegates to the configured SMS
    # adapter (NullSms by default — logs and drops; swap with
    # +Notifications.configuration.sms_adapter+).
    class Sms < Notification
      def recipient
        super.presence || owner&.sms_notification_recipient
      end

      private

      def dispatch!
        Notifications.sms_adapter.deliver(notification: self)
      end
    end
  end
end
