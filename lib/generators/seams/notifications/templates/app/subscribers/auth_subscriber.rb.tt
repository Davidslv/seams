# frozen_string_literal: true

module Notifications
  # Consumes Auth events. On +user.signed_up.auth+:
  #   1. Resolves the host User by `payload[:host_user_id]`.
  #   2. Enqueues Notifications::CreateNotificationJob — which creates
  #      InApp + (preferences-permitting) Email rows out-of-band.
  #
  # Notifications are NEVER created inline inside the publisher's
  # thread (see Seams::Events::Publisher docstring); the job is the
  # boundary.
  #
  # +.attach!+ is idempotent across Rails autoreload via
  # +Seams::Events::Publisher.attach_class+ — registering the class by
  # NAME (a String) rather than capturing a closure means each dispatch
  # re-resolves the constant, so edits to +handle_signed_up+ are picked
  # up without a server restart.
  class AuthSubscriber
    SUBSCRIBER_KEY = :notifications_auth_subscriber
    HOST_USER_CLASS_NAME = "User"

    class << self
      def attach!
        Seams::Events::Publisher.attach_class(
          SUBSCRIBER_KEY,
          "user.signed_up.auth",
          class_name:  "Notifications::AuthSubscriber",
          method_name: :handle_signed_up
        )
      end

      private

      def handle_signed_up(payload)
        host_user_id = payload[:host_user_id]
        return unless host_user_id

        Notifications::CreateNotificationJob.perform_later(
          owner_class: HOST_USER_CLASS_NAME,
          owner_id:    host_user_id,
          template:    "welcome",
          strategy:    "in_app"
        )

        return unless email_enabled?(host_user_id)

        Notifications::CreateNotificationJob.perform_later(
          owner_class: HOST_USER_CLASS_NAME,
          owner_id:    host_user_id,
          template:    "welcome",
          strategy:    "email"
        )
      end

      def email_enabled?(user_id)
        Notifications::NotificationPreference.enabled?(
          user_id: user_id, channel: "email", notification_type: "welcome"
        )
      end
    end
  end
end
