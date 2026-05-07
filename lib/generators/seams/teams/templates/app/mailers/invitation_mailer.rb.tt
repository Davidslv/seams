# frozen_string_literal: true

module Teams
  # Sends the email a team invitation generates. The default invocation
  # is `InvitationMailer.invite(invitation_id)` from
  # `Teams::InvitationSubscriber` — both the controller and any other
  # caller can also invoke it directly.
  #
  # Override the body by dropping a file at
  # `app/views/teams/invitation_mailer/invite.text.erb` (or .html.erb)
  # in the host application.
  class InvitationMailer < ActionMailer::Base
    default from: -> { Teams.configuration.invitation_mailer_from }

    def invite(invitation_id)
      @invitation = Teams::Invitation.find(invitation_id)
      @team       = @invitation.team
      @accept_url = build_accept_url(@invitation.token)

      mail(
        to:      @invitation.email,
        subject: "You're invited to join #{@team.name}"
      )
    end

    private

    def build_accept_url(token)
      base = Teams.configuration.host_url.to_s
      base = base.sub(/\/+\z/, "")
      "#{base}/teams/invitations/accept/#{token}"
    end
  end
end
