# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    # 10 attempts per minute per IP. Rails 8's built-in rate_limit
    # uses Solid Cache by default; configure cache_store in your host
    # if you need to override.
    rate_limit to: 10, within: 1.minute, only: %i[create],
               with: -> { redirect_to auth.new_session_path, alert: "Too many attempts. Try again in a minute." }

    def new
      # render the sign-in form
    end

    def create
      result = Auth::AuthenticateUser.call(
        email: params[:email], password: params[:password]
      )

      if result.ok?
        cookies.encrypted[Auth.configuration.cookie_name] = {
          value: result.session.token, httponly: true, expires: result.session.expires_at
        }
        redirect_to Auth.configuration.after_sign_in_url, notice: "Signed in"
      else
        flash.now[:alert] = result.error
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      token = cookies.encrypted[Auth.configuration.cookie_name]
      if token
        session = Auth::Session.find_by(token: token)
        if session
          auth_user = session.user
          Seams::Events::Publisher.publish(
            "user.signed_out.auth",
            auth_user_id: auth_user.id,
            host_user_id: auth_user.host_user_id,
            session_id:   session.id
          )
          session.destroy
        end
      end
      cookies.delete(Auth.configuration.cookie_name)
      redirect_to Auth.configuration.after_sign_out_url, notice: "Signed out"
    end
  end
end
