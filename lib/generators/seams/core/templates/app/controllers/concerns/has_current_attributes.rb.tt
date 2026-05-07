# frozen_string_literal: true

require "active_support/concern"

module Core
  # Mix into ApplicationController to populate Core::Current at the
  # start of every request. Hosts override #resolve_current_user and
  # #resolve_current_team to plug in their own auth/tenant lookup —
  # the default implementations look for current_user (Auth engine)
  # and params[:team_id] (Teams engine).
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

    def resolve_current_user
      respond_to?(:current_user) ? current_user : nil
    end

    def resolve_current_team
      return nil unless params[:team_id]
      return nil unless defined?(Teams::Team)

      Teams::Team.find_by(id: params[:team_id])
    end
  end
end
