# frozen_string_literal: true

module Notifications
  module Strategies
    # Email notification. +#dispatch!+ delegates to the configured
    # email adapter, which ultimately renders the +template+ ERB
    # against the owner and posts to the gateway (ActionMailer by
    # default; swap with +Notifications.configuration.email_adapter+).
    class Email < Notification
      def recipient
        super.presence || owner&.email_notification_recipient
      end

      private

      def dispatch!
        Notifications.email_adapter.deliver(notification: self)
      end
    end
  end
end
