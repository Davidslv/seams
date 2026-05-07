# frozen_string_literal: true

require "active_support/concern"

module Teams
  # Helpers for controllers that need to enforce team-membership
  # checks. Mix in by default in TeamsController/MembershipsController/
  # InvitationsController so the engine ships with safe defaults.
  # Hosts can override the predicates by re-opening the concern.
  module Authorization
    extend ActiveSupport::Concern

    private

    def require_team_member!
      head :forbidden and return false unless team_member?
      true
    end

    def require_team_admin!
      head :forbidden and return false unless team_admin?
      true
    end

    def team_member?
      return false unless current_user_id && @team

      Teams::Membership.exists?(team_id: @team.id, user_id: current_user_id)
    end

    def team_admin?
      return false unless current_user_id && @team

      Teams::Membership.where(team_id: @team.id, user_id: current_user_id, role: %w[owner admin]).exists?
    end

    def current_user_id
      respond_to?(:current_user) && current_user&.id
    end
  end
end
