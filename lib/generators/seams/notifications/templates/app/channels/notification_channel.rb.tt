# frozen_string_literal: true

module Notifications
  # Per-recipient ActionCable channel. The host's User model can
  # broadcast a Turbo Stream to this channel when a new notification
  # is created, so the bell icon updates in real time.
  #
  #   Notifications::NotificationChannel.broadcast_to(
  #     user, { unread_count: user.notifications.unread.count }
  #   )
  class NotificationChannel < ActionCable::Channel::Base
    def subscribed
      return reject unless current_user

      stream_for current_user
    end

    private

    def current_user
      connection.respond_to?(:current_user) ? connection.current_user : nil
    end
  end
end
