# frozen_string_literal: true

module Teams
  class MembershipsController < ApplicationController
    include Teams::Authorization

    before_action :set_team
    before_action :require_team_member!, only: %i[index]
    before_action :require_team_admin!,  only: %i[create destroy]

    def index
      @memberships = @team.memberships
    end

    def create
      membership = @team.memberships.create!(membership_params)
      Seams::Events::Publisher.publish(
        "team.member_joined.teams",
        team_id: @team.id, identity_id: membership.identity_id, role: membership.role
      )
      redirect_to team_memberships_path(@team), notice: "Member added"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to team_memberships_path(@team), alert: e.message
    end

    def destroy
      membership = @team.memberships.find(params[:id])
      membership.destroy
      Seams::Events::Publisher.publish(
        "team.member_left.teams", team_id: @team.id, identity_id: membership.identity_id
      )
      redirect_to team_memberships_path(@team), notice: "Member removed"
    end

    private

    def set_team
      @team = Teams::Team.find(params[:team_id])
    end

    # `permit` deliberately omits `:role` — Brakeman flags it as
    # mass-assignment, and even with server-side coercion the
    # permit-list reads as "we accept whatever role the form posts".
    # Role is extracted separately via `safe_role` and merged in.
    def membership_params
      params.require(:membership).permit(:identity_id).merge(role: safe_role)
    end

    def safe_role
      candidate = params.dig(:membership, :role).to_s
      Teams::Membership::ROLES.include?(candidate) ? candidate : "member"
    end
  end
end
