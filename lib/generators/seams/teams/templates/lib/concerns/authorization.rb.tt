# frozen_string_literal: true

require "active_support/concern"

module Teams
  # Helpers for controllers that need to enforce team-membership
  # checks. Mix in by default in TeamsController/MembershipsController/
  # InvitationsController so the engine ships with safe defaults.
  # Hosts can override the predicates by re-opening the concern.
  #
  # Resolves the current Identity via `current_identity_id`, which by
  # default reads `Auth::Current.identity` (the Auth engine's
  # per-request namespace). Hosts can override `current_identity_id`
  # to plug in a different resolver.
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
      return false unless current_identity_id && @team

      Teams::Membership.exists?(team_id: @team.id, identity_id: current_identity_id)
    end

    def team_admin?
      return false unless current_identity_id && @team

      Teams::Membership.where(team_id: @team.id, identity_id: current_identity_id, role: %w[owner admin]).exists?
    end

    # Resolves the signed-in human's id from `Auth::Current.identity`
    # (the Auth engine's per-request namespace). Gated on
    # `defined?(Auth::Current)` so the concern remains include-safe in
    # hosts that don't ship the auth engine. Hosts that wire auth
    # differently override this method.
    def current_identity_id
      if defined?(Auth::Current) && Auth::Current.respond_to?(:identity) && Auth::Current.identity
        return Auth::Current.identity.id
      end

      nil
    end
  end
end
