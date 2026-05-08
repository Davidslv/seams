# frozen_string_literal: true

module Auth
  module OAuth
    # Two endpoints per provider — the user-facing flow:
    #   GET /auth/oauth/:provider/start    → redirect to provider's authorize URL
    #   GET /auth/oauth/:provider/callback → exchange code + sign in
    #
    # State token: cryptographically random, stored in the session, and
    # re-verified on callback. Mismatch ⇒ 403. Without this, an attacker
    # can trick a victim into linking the attacker's OAuth identity to
    # the victim's account.
    class CallbacksController < ApplicationController
      skip_before_action :verify_authenticity_token, only: %i[callback]

      rescue_from Auth::OAuthProviderUnknown do |e|
        redirect_to Auth.configuration.after_sign_out_url, alert: e.message
      end

      # GET /auth/oauth/:provider/start
      def start
        provider = params.require(:provider)
        Auth.oauth(provider) # raises OAuthProviderUnknown if not configured

        state = SecureRandom.urlsafe_base64(32)
        session[oauth_state_key(provider)] = state

        redirect_to Auth.oauth(provider).authorize_url(
          state:        state,
          redirect_uri: callback_url(provider)
        ), allow_other_host: true, status: :see_other
      end

      # GET /auth/oauth/:provider/callback?code=...&state=...
      def callback
        provider       = params.require(:provider)
        returned_state = params[:state]
        expected_state = session.delete(oauth_state_key(provider))

        if expected_state.nil? || returned_state != expected_state
          return redirect_to Auth.configuration.after_sign_out_url, alert: "OAuth state mismatch"
        end

        if (error = params[:error])
          return redirect_to Auth.configuration.after_sign_out_url,
                             alert: "OAuth #{provider}: #{error}"
        end

        result = Auth::OAuth::Authenticator.call(
          provider:     provider,
          code:         params.require(:code),
          redirect_uri: callback_url(provider)
        )

        if result.ok?
          cookies.encrypted[Auth.configuration.cookie_name] = {
            value:    result.session.token,
            httponly: true,
            secure:   request.ssl?,
            expires:  result.session.expires_at
          }
          redirect_to Auth.configuration.after_sign_in_url,
                      notice: result.new_user ? "Welcome!" : "Signed in"
        else
          redirect_to Auth.configuration.after_sign_out_url, alert: result.error
        end
      end

      private

      def oauth_state_key(provider)
        "auth_oauth_state_#{provider}"
      end

      def callback_url(provider)
        url_for(action: :callback, provider: provider, only_path: false)
      end
    end
  end
end
