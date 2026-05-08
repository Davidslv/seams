# frozen_string_literal: true

module Notifications
  module Strategies
    # SMS notification. +#dispatch!+ delegates to the configured SMS
    # adapter (NullSms by default — logs and drops; swap with
    # +Notifications.configuration.sms_adapter+).
    #
    # The polymorphic +owner+ supplies the recipient phone number.
    # If the owner includes +Notifications::Notifiable+,
    # +#sms_notification_recipient+ wins; otherwise we fall back to
    # +#phone+. Hosts whose owner exposes a different attribute
    # should override +#recipient+ on the strategy or set +recipient+
    # explicitly when creating the Notification.
    class Sms < Notification
      def recipient
        super.presence || resolve_phone_from_owner
      end

      private

      def dispatch!
        Notifications.sms_adapter.deliver(notification: self)
      end

      def resolve_phone_from_owner
        return nil unless owner

        owner.try(:sms_notification_recipient) || owner.try(:phone)
      end
    end
  end
end
