# frozen_string_literal: true

module Notifications
  module Strategies
    # Email notification. +#dispatch!+ delegates to the configured
    # email adapter, which ultimately renders the +template+ ERB
    # against the owner and posts to the gateway (ActionMailer by
    # default; swap with +Notifications.configuration.email_adapter+).
    #
    # The polymorphic +owner+ supplies the recipient address. We try
    # +#email_address+ first (Rails 8's `has_secure_password` convention,
    # used by some host User models), then +#email+ (Auth::Identity and
    # most host User models). If the owner includes
    # +Notifications::Notifiable+, +#email_notification_recipient+ wins.
    # Hosts whose owner exposes a different attribute should override
    # +#recipient+ on the strategy or set +recipient+ explicitly when
    # creating the Notification.
    class Email < Notification
      def recipient
        super.presence || resolve_email_from_owner
      end

      private

      def dispatch!
        Notifications.email_adapter.deliver(notification: self)
      end

      def resolve_email_from_owner
        return nil unless owner

        owner.try(:email_notification_recipient) ||
          owner.try(:email_address) ||
          owner.try(:email)
      end
    end
  end
end
