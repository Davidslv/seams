# frozen_string_literal: true

require "auth/oauth/abstract"

module Auth
  module OAuth
    # Google OAuth 2.0 + OpenID Connect adapter. Faraday-based
    # (no oauth2 gem, no Net::HTTP).
    #
    # Verified against:
    #   https://developers.google.com/identity/protocols/oauth2/web-server
    #   https://developers.google.com/identity/openid-connect/openid-connect
    #
    # Default scopes (`openid email profile`) cover the four fields we
    # populate on Profile. Use `access_type=offline` + `prompt=consent`
    # only if you need refresh tokens — most "sign in with Google"
    # flows don't.
    class Google < Abstract
      AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
      TOKEN_URL     = "https://oauth2.googleapis.com/token"
      USERINFO_URL  = "https://openidconnect.googleapis.com/v1/userinfo"

      DEFAULT_SCOPES = %w[openid email profile].freeze

      def initialize(client_id:, client_secret:, scopes: DEFAULT_SCOPES)
        super
      end

      def authorize_url(state:, redirect_uri:)
        params = {
          client_id:     client_id,
          redirect_uri:  redirect_uri,
          response_type: "code",
          scope:         scopes.join(" "),
          state:         state,
          access_type:   "online",
          prompt:        "select_account"
        }
        "#{AUTHORIZE_URL}?#{URI.encode_www_form(params)}"
      end

      def exchange_code(code:, redirect_uri:)
        response = conn(TOKEN_URL).post("", {
          client_id:     client_id,
          client_secret: client_secret,
          code:          code,
          redirect_uri:  redirect_uri,
          grant_type:    "authorization_code"
        })
        assert_success!(response, action: "token exchange")
        body = parse_json(response, action: "token exchange")
        {
          access_token:  body["access_token"],
          refresh_token: body["refresh_token"],
          expires_in:    body["expires_in"],
          token_type:    body["token_type"] || "Bearer",
          scope:         body["scope"]
        }
      end

      def fetch_user_info(access_token:)
        response = conn(USERINFO_URL).get("") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
        end
        assert_success!(response, action: "userinfo")
        body = parse_json(response, action: "userinfo")
        Profile.new(
          provider_uid:   body["sub"],     # stable Google account id
          email:          body["email"],
          email_verified: body["email_verified"],
          name:           body["name"],
          avatar_url:     body["picture"],
          raw:            body
        )
      end
    end
  end
end
