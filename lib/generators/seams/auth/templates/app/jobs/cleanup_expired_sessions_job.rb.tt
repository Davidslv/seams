# frozen_string_literal: true

module Auth
  # Sweeps expired Auth::Session rows. Wire as a Solid Queue Recurring
  # entry in config/recurring.yml:
  #
  #   auth_cleanup_expired_sessions:
  #     class: Auth::CleanupExpiredSessionsJob
  #     schedule: "every 1 hour"
  #
  # Publishes session.expired.auth for each row destroyed so any
  # downstream listener (Notifications, audit log) can react.
  class CleanupExpiredSessionsJob < ApplicationJob
    queue_as :auth

    BATCH_SIZE = 500

    def perform
      Auth::Session.where(expires_at: ..Time.current).find_each(batch_size: BATCH_SIZE) do |session|
        identity = session.identity
        Seams::Events::Publisher.publish(
          "session.expired.auth",
          identity_id: identity&.id,
          session_id:  session.id
        )
        session.destroy
      end
    end
  end
end
