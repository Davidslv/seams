# frozen_string_literal: true

require "notifications/adapters/abstract"

module Notifications
  module Adapters
    # Default email adapter — delegates to the engine's
    # NotificationMailer which renders the notification's template
    # and dispatches via ActionMailer.
    class ActionMailer < Abstract
      def deliver(notification:)
        Notifications::NotificationMailer.notify(notification).deliver_later
        { ok: true, provider: "action_mailer" }
      end
    end
  end
end
