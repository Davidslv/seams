# frozen_string_literal: true

require "active_support/concern"

module Core
  # Mix into ApplicationController to populate Core::Current at the
  # start of every request. Hosts override #resolve_current_user and
  # #resolve_current_team to plug in their own auth/tenant lookup —
  # the default implementations look for `Auth::Current.identity`
  # (the Auth engine's per-request namespace post-Wave-9) and
  # `params[:team_id]` (the Teams engine).
  #
  # `Core::Current.user` is best read as "the current actor" — the
  # auditable concern writes `actor_id = Core::Current.user&.id`. By
  # default that's the signed-in Identity. Hosts that maintain a
  # domain-specific User on top of Auth::Identity can override
  # #resolve_current_user to point at that User instead.
  #
  #   class ApplicationController < ActionController::Base
  #     include Core::HasCurrentAttributes
  #   end
  module HasCurrentAttributes
    extend ActiveSupport::Concern

    included do
      before_action :populate_current_attributes
    end

    private

    def populate_current_attributes
      Core::Current.user       = resolve_current_user
      Core::Current.team       = resolve_current_team
      Core::Current.request_id = request.request_id if respond_to?(:request)
    end

    # Default resolution order (post-Wave-9):
    #   1. `Auth::Current.identity` — the canonical signed-in human.
    #   2. `current_identity`       — the helper Auth engine exposes.
    #   3. `current_user`           — the legacy Wave-8 helper, kept
    #      so hosts that maintain a User on top of Auth::Identity
    #      stay working without overriding the concern.
    # Hosts override this method to plug in a different actor.
    def resolve_current_user
      if defined?(Auth::Current) && Auth::Current.respond_to?(:identity) && Auth::Current.identity
        return Auth::Current.identity
      end
      return current_identity if respond_to?(:current_identity)
      return current_user     if respond_to?(:current_user)

      nil
    end

    # Default: read `Teams::Current.team` (set by the host's teams
    # before_action), which the boundary cop exempts as a per-request
    # namespace. Hosts that want a different binding (e.g. resolving
    # the team from `params[:team_id]` without delegating to teams)
    # override this method in their ApplicationController.
    #
    # Why we no longer reach into `Teams::Team` here: doing so makes
    # core depend on teams, which inverts the dependency direction
    # (teams may include core's concerns; core must not know about
    # teams' models). Reading `Teams::Current.team` keeps the
    # cross-engine surface to the documented per-request namespace.
    def resolve_current_team
      return nil unless defined?(Teams::Current) && Teams::Current.respond_to?(:team)

      Teams::Current.team
    end
  end
end
