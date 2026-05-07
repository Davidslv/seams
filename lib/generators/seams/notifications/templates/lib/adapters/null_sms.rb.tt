# frozen_string_literal: true

require "notifications/adapters/abstract"

module Notifications
  module Adapters
    # No-op SMS adapter. Logs the delivery via Seams::Observability
    # and returns success without dispatching. Useful in development
    # and tests so SMS calls succeed without burning vendor quota.
    class NullSms < Abstract
      def deliver(notification:)
        Seams::Observability.adapter.info(
          "notifications.null_sms.deliver",
          engine: "notifications",
          to: notification.recipient,
          template: notification.template,
          length: notification.rendered_content.to_s.length
        )
        { ok: true, provider: "null_sms" }
      end
    end
  end
end
