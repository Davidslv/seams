# frozen_string_literal: true

require "active_support/concern"

module Auth
  # Bearer-token controller authentication. Mix into API controllers
  # that should accept `Authorization: Bearer <token>` instead of the
  # session cookie.
  #
  #   class Api::WidgetsController < ApplicationController
  #     include Auth::ApiAuthenticatable
  #     before_action :authenticate_api_token!
  #   end
  #
  # Sets `current_api_token` (the ApiToken row) and `current_identity`
  # (the Auth::Identity) on success. Renders 401 with a JSON body on
  # failure. last_used_at is bumped on every successful auth.
  module ApiAuthenticatable
    extend ActiveSupport::Concern

    included do
      attr_reader :current_api_token
    end

    def authenticate_api_token!
      token = current_api_token_or_render_401
      return unless token

      @current_api_token = token
      @current_identity  = token.identity
      Auth::Current.identity = @current_identity if defined?(Auth::Current)
      token.touch_last_used!
    end

    def current_identity
      @current_identity
    end

    private

    def current_api_token_or_render_401
      header = request.headers["Authorization"].to_s
      return render_unauthorized!("missing Authorization header") unless header.start_with?("Bearer ")

      plaintext = header.sub(/\ABearer\s+/, "").strip
      token     = Auth::ApiToken.find_by_plaintext(plaintext)
      return render_unauthorized!("invalid token")          unless token
      return render_unauthorized!("token expired")          if token.expired?

      token
    end

    def render_unauthorized!(message)
      render json: { error: message }, status: :unauthorized
      nil
    end
  end
end
