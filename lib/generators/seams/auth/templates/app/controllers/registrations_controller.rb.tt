# frozen_string_literal: true

module Auth
  class RegistrationsController < ApplicationController
    # 5 sign-ups per hour per IP. Tighter than sign-in because each
    # successful row also sends a welcome email + provisions side
    # effects. Rails 8's built-in rate_limit uses Solid Cache.
    rate_limit to: 5, within: 1.hour, only: %i[create],
               with: -> { redirect_to auth.new_registration_path, alert: "Too many sign-ups from this IP. Try again later." }

    def new
      @identity = Auth::Identity.new
    end

    def create
      result = Auth::RegisterIdentity.call(
        email:                 params.dig(:identity, :email),
        password:              params.dig(:identity, :password),
        password_confirmation: params.dig(:identity, :password_confirmation)
      )

      if result.ok?
        cookies.encrypted[Auth.configuration.cookie_name] = {
          value: result.session.token, httponly: true, expires: result.session.expires_at
        }
        redirect_to Auth.configuration.after_sign_in_url, notice: "Welcome"
      else
        @identity = Auth::Identity.new(email: params.dig(:identity, :email))
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end
  end
end
