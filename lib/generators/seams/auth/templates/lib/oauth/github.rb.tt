# frozen_string_literal: true

require "auth/oauth/abstract"

module Auth
  module OAuth
    # GitHub OAuth Apps adapter. Faraday-based.
    #
    # Verified against:
    #   https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps
    #   https://docs.github.com/en/rest/users/users
    #   https://docs.github.com/en/rest/users/emails
    #
    # GitHub returns form-encoded responses by default — we send
    # `Accept: application/json` to get JSON consistently.
    #
    # The `/user` endpoint returns null email when the user keeps it
    # private. We additionally fetch `/user/emails` (which requires
    # the `user:email` scope) and pick the primary verified one. If
    # `user:email` isn't in scopes, we fall back to whatever `/user`
    # returns (which may be nil — caller should handle).
    class Github < Abstract
      AUTHORIZE_URL    = "https://github.com/login/oauth/authorize"
      TOKEN_URL        = "https://github.com/login/oauth/access_token"
      USER_URL         = "https://api.github.com/user"
      USER_EMAILS_URL  = "https://api.github.com/user/emails"

      DEFAULT_SCOPES = %w[read:user user:email].freeze

      def initialize(client_id:, client_secret:, scopes: DEFAULT_SCOPES)
        super
      end

      def authorize_url(state:, redirect_uri:)
        params = {
          client_id:    client_id,
          redirect_uri: redirect_uri,
          scope:        scopes.join(" "),
          state:        state,
          allow_signup: "true"
        }
        "#{AUTHORIZE_URL}?#{URI.encode_www_form(params)}"
      end

      def exchange_code(code:, redirect_uri:)
        response = conn(TOKEN_URL).post("") do |req|
          req.headers["Accept"] = "application/json"
          req.body = URI.encode_www_form(
            client_id:     client_id,
            client_secret: client_secret,
            code:          code,
            redirect_uri:  redirect_uri
          )
        end
        assert_success!(response, action: "token exchange")
        body = parse_json(response, action: "token exchange")
        # GitHub returns 200 with { "error": "bad_verification_code" }
        # for bad codes — treat that as a failure too.
        raise Auth::OAuthError, "OAuth github token exchange: #{body["error_description"] || body["error"]}" if body["error"]

        {
          access_token:  body["access_token"],
          refresh_token: nil,                    # GitHub OAuth Apps don't issue refresh tokens
          expires_in:    nil,                    # tokens don't expire (GitHub OAuth Apps)
          token_type:    body["token_type"] || "bearer",
          scope:         body["scope"]
        }
      end

      def fetch_user_info(access_token:)
        user  = fetch_user(access_token)
        email = user["email"] || best_email(access_token)

        Profile.new(
          provider_uid:   user["id"].to_s,    # GitHub numeric id, stable
          email:          email,
          email_verified: !email.nil?,         # /user/emails primary+verified is what we picked
          name:           user["name"] || user["login"],
          avatar_url:     user["avatar_url"],
          raw:            user
        )
      end

      private

      def fetch_user(access_token)
        response = conn(USER_URL).get("") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Accept"]        = "application/vnd.github+json"
          req.headers["User-Agent"]    = "Seams Auth"
        end
        assert_success!(response, action: "user fetch")
        parse_json(response, action: "user fetch")
      end

      def best_email(access_token)
        return nil unless scopes.include?("user:email")

        response = conn(USER_EMAILS_URL).get("") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Accept"]        = "application/vnd.github+json"
          req.headers["User-Agent"]    = "Seams Auth"
        end
        return nil unless response.success?

        emails = JSON.parse(response.body)
        primary = emails.find { |e| e["primary"] && e["verified"] }
        primary&.dig("email")
      end
    end
  end
end
