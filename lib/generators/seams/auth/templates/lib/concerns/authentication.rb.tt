# frozen_string_literal: true

require "active_support/concern"

module Auth
  # Mix into the host's ApplicationController to gain `current_user`,
  # `signed_in?`, and `authenticate_user!` helpers backed by the
  # encrypted Auth session cookie.
  #
  #   class ApplicationController < ActionController::Base
  #     include Auth::Authentication
  #     before_action :authenticate_user!
  #   end
  module Authentication
    extend ActiveSupport::Concern

    included do
      helper_method :current_user, :signed_in? if respond_to?(:helper_method)
    end

    def current_user
      @current_user ||= resolve_current_user
    end

    def signed_in?
      current_user.present?
    end

    def authenticate_user!
      return if signed_in?

      respond_to?(:redirect_to) ? redirect_to(auth_engine.new_session_path) : head(:unauthorized)
    end

    private

    def resolve_current_user
      token = cookies.encrypted[Auth.configuration.cookie_name]
      return nil if token.blank?

      session = Auth::Session.active.find_by(token: token)
      session&.user
    end

    def auth_engine
      Auth::Engine.routes.url_helpers
    end
  end
end
