# frozen_string_literal: true

module Notifications
  # Consumes Auth events. On +identity.signed_up.auth+:
  #   1. Resolves the recipient by `payload[:identity_id]`. The owner
  #      of the welcome notification is the Auth::Identity itself
  #      (the human who just signed up).
  #   2. Enqueues Notifications::CreateNotificationJob — which creates
  #      InApp + (preferences-permitting) Email rows out-of-band.
  #
  # Notifications are NEVER created inline inside the publisher's
  # thread (see Seams::Events::Publisher docstring); the job is the
  # boundary.
  #
  # Hosts that want a different owner (an Account, a Membership, or
  # a host-defined User) should override this subscriber — copy this
  # file into their host engine, change `OWNER_CLASS_NAME` and the
  # resolution rule, and re-attach. The Notification table accepts
  # any polymorphic owner; the choice is purely about which model
  # the welcome notification "belongs to" in the bell partial / index.
  #
  # +.attach!+ is idempotent across Rails autoreload via
  # +Seams::Events::Publisher.attach_class+ — registering the class by
  # NAME (a String) rather than capturing a closure means each dispatch
  # re-resolves the constant, so edits to +handle_signed_up+ are picked
  # up without a server restart.
  class AuthSubscriber
    SUBSCRIBER_KEY = :notifications_auth_subscriber
    OWNER_CLASS_NAME = "Auth::Identity"

    class << self
      def attach!
        Seams::Events::Publisher.attach_class(
          SUBSCRIBER_KEY,
          "identity.signed_up.auth",
          class_name:  "Notifications::AuthSubscriber",
          method_name: :handle_signed_up
        )
      end

      private

      def handle_signed_up(payload)
        identity_id = payload[:identity_id]
        return unless identity_id

        Notifications::CreateNotificationJob.perform_later(
          owner_class: OWNER_CLASS_NAME,
          owner_id:    identity_id,
          template:    "welcome",
          strategy:    "in_app"
        )

        return unless email_enabled?(identity_id)

        Notifications::CreateNotificationJob.perform_later(
          owner_class: OWNER_CLASS_NAME,
          owner_id:    identity_id,
          template:    "welcome",
          strategy:    "email"
        )
      end

      def email_enabled?(identity_id)
        Notifications::NotificationPreference.enabled?(
          identity_id: identity_id, channel: "email", notification_type: "welcome"
        )
      end
    end
  end
end
