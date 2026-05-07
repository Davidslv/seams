# frozen_string_literal: true

module Teams
  class InvitationsController < ApplicationController
    include Teams::Authorization

    before_action :set_team,             only: %i[index create destroy]
    before_action :require_team_admin!,  only: %i[create destroy]

    def index
      @invitations = @team.invitations.pending
    end

    def create
      invitation = @team.invitations.create!(invitation_params)
      Seams::Events::Publisher.publish(
        "invitation.sent.teams",
        invitation_id: invitation.id,
        team_id:       @team.id,
        email:         invitation.email,
        role:          invitation.role,
        token:         invitation.token
      )
      redirect_to team_invitations_path(@team), notice: "Invitation sent"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to team_invitations_path(@team), alert: e.message
    end

    def destroy
      invitation = @team.invitations.find(params[:id])
      invitation.destroy
      redirect_to team_invitations_path(@team), notice: "Invitation revoked"
    end

    # GET /invitations/accept/:token — show the confirmation page.
    def accept_form
      @invitation = Teams::Invitation.find_by!(token: params[:token])
    end

    # POST /invitations/accept/:token — perform the accept.
    # Wraps the lookup in a row lock and short-circuits if the
    # invitation has already been accepted, so a double-click on the
    # email link returns a friendly redirect instead of a 500.
    def accept
      Teams::Invitation.transaction do
        @invitation = Teams::Invitation.lock.find_by!(token: params[:token])

        if @invitation.accepted?
          return redirect_to team_path(@invitation.team), notice: "You're already a member"
        end

        if @invitation.expired?
          return redirect_to root_path, alert: "Invitation expired"
        end

        @invitation.team.memberships.create!(user_id: current_user_id, role: @invitation.role)
        @invitation.update!(accepted_at: Time.current)
      end

      Seams::Events::Publisher.publish(
        "invitation.accepted.teams",
        team_id: @invitation.team_id, email: @invitation.email, user_id: current_user_id
      )
      redirect_to team_path(@invitation.team), notice: "Joined #{@invitation.team.name}"
    rescue ActiveRecord::RecordNotUnique
      redirect_to team_path(@invitation.team), notice: "You're already a member"
    end

    private

    def set_team
      @team = Teams::Team.find(params[:team_id])
    end

    # `permit` deliberately omits `:role` — Brakeman flags it as
    # mass-assignment, and even with server-side coercion the
    # permit-list reads as "we accept whatever role the form posts".
    # Role is extracted separately via `safe_role` and merged in.
    def invitation_params
      params.require(:invitation).permit(:email).merge(role: safe_role)
    end

    def safe_role
      candidate = params.dig(:invitation, :role).to_s
      Teams::Membership::ROLES.include?(candidate) ? candidate : "member"
    end
  end
end
