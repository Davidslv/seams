# frozen_string_literal: true

module Notifications
  module Strategies
    # In-app notification. The +Notification+ row IS the delivery —
    # the bell view renders pending rows for the recipient and
    # +#mark_as_read!+ flips +read_at+. +#dispatch!+ broadcasts on
    # the per-recipient ActionCable channel so connected clients
    # update without polling. No-op when ActionCable isn't booted.
    class InApp < Notification
      def recipient
        super.presence || owner&.id&.to_s
      end

      private

      def dispatch!
        return unless defined?(Notifications::NotificationChannel) && defined?(::ActionCable)

        Notifications::NotificationChannel.broadcast_to(
          owner, id: id, template: template, body: rendered_content
        )
      end
    end
  end
end
