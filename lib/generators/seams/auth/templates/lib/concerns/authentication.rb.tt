# frozen_string_literal: true

require "active_support/concern"

module Auth
  # Mix into the host's ApplicationController to gain `current_identity`,
  # `signed_in?`, and `authenticate_identity!` helpers backed by the
  # encrypted Auth session cookie.
  #
  #   class ApplicationController < ActionController::Base
  #     include Auth::Authentication
  #     before_action :authenticate_identity!
  #   end
  #
  # Side-effect: when a sign-in is resolved, `Current.identity` is set
  # so models / services downstream can access the signed-in identity
  # without threading it through every method. Future waves will add
  # `Current.account` and `Current.user` (account-membership) — for now
  # this concern only sets `Current.identity`.
  module Authentication
    extend ActiveSupport::Concern

    included do
      helper_method :current_identity, :signed_in? if respond_to?(:helper_method)
      before_action :set_current_identity if respond_to?(:before_action)
    end

    def current_identity
      @current_identity ||= resolve_current_identity
    end

    def signed_in?
      current_identity.present?
    end

    def authenticate_identity!
      return if signed_in?

      respond_to?(:redirect_to) ? redirect_to(auth_engine.new_session_path) : head(:unauthorized)
    end

    private

    def resolve_current_identity
      token = cookies.encrypted[Auth.configuration.cookie_name]
      return nil if token.blank?

      session = Auth::Session.active.find_by(token: token)
      session&.identity
    end

    def set_current_identity
      Auth::Current.identity = current_identity if defined?(Auth::Current)
    end

    def auth_engine
      Auth::Engine.routes.url_helpers
    end
  end
end
