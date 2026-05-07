# frozen_string_literal: true

module Notifications
  module Adapters
    # Contract every notification adapter must implement. Subclass
    # this in your host application to wire Mailgun, SendGrid, Twilio,
    # etc., then point the relevant +Notifications.configuration+
    # knob at the subclass name.
    #
    # Each adapter receives the full Notification object so it can
    # read +recipient+, +template+, +rendered_content+, +owner+ —
    # whatever the gateway needs. Returns a Hash that includes at
    # least { ok: true|false, provider: <string> }.
    class Abstract
      def deliver(notification:)
        raise NotImplementedError, "#{self.class} must implement #deliver"
      end
    end
  end
end
