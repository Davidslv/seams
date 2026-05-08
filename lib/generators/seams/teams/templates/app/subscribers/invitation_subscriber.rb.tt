# frozen_string_literal: true

module Teams
  # Consumes Teams events. On +invitation.sent.teams+:
  #   1. Resolves the Teams::Invitation by id from the payload.
  #   2. Enqueues Teams::InvitationMailer.invite — `deliver_later` so
  #      the publisher's transaction isn't blocked on SMTP.
  #
  # +.attach!+ is idempotent — Rails reload won't double-subscribe, and
  # because we register the subscriber CLASS by its String name via
  # +attach_class+, dispatch re-resolves the constant on every event so
  # edits to +handle_invitation_sent+ take effect without a server restart.
  class InvitationSubscriber
    SUBSCRIBER_KEY = :teams_invitation_subscriber

    class << self
      def attach!
        Seams::Events::Publisher.attach_class(
          SUBSCRIBER_KEY,
          "invitation.sent.teams",
          class_name:  "Teams::InvitationSubscriber",
          method_name: :handle_invitation_sent
        )
      end

      private

      def handle_invitation_sent(payload)
        invitation_id = payload[:invitation_id]
        return unless invitation_id

        Teams::InvitationMailer.invite(invitation_id).deliver_later
      end
    end
  end
end
