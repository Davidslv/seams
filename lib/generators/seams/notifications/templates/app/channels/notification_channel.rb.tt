# frozen_string_literal: true

module Notifications
  # Per-recipient ActionCable channel. Server-side code can broadcast
  # a Turbo Stream to this channel when a new notification is created,
  # so the bell icon updates in real time.
  #
  #   Notifications::NotificationChannel.broadcast_to(
  #     identity, { unread_count: identity.notifications.unread.count }
  #   )
  #
  # Post-Wave-9 the canonical recipient is `Auth::Current.identity`.
  # Hosts that keep a domain User on top of Auth::Identity can
  # override `current_recipient` to point at that User instead.
  class NotificationChannel < ActionCable::Channel::Base
    def subscribed
      return reject unless current_recipient

      stream_for current_recipient
    end

    private

    # Resolves the recipient for the WebSocket connection. Tries
    # `connection.current_identity` (the Wave-9 default exposed by
    # `Auth::Authentication`) first, then falls back to
    # `connection.current_user` for hosts that maintain a User model
    # on top of Auth::Identity.
    def current_recipient
      return connection.current_identity if connection.respond_to?(:current_identity)
      return connection.current_user     if connection.respond_to?(:current_user)

      nil
    end
  end
end
