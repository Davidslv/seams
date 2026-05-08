# frozen_string_literal: true

module Auth
  module OAuth
    # Orchestrates the OAuth callback flow:
    #
    #   1. Exchange the authorization `code` for an access token.
    #   2. Fetch the provider's user profile.
    #   3. Find an existing Auth::OAuth::Provider row by (provider,
    #      provider_uid) OR find an existing Auth::User by email OR
    #      create a new Auth::User. Link the row to the user.
    #   4. Refresh stored token + profile.
    #   5. Create a new Auth::Session.
    #   6. Publish user.signed_up.auth (first sign-in via OAuth) or
    #      user.signed_in.auth (returning user).
    #
    # Returns a Result: ok?, user, session, oauth_provider, new_user, error.
    class Authenticator
      Result = Struct.new(:ok?, :user, :session, :oauth_provider, :new_user, :error,
                          keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(provider:, code:, redirect_uri:)
        @provider     = provider.to_s
        @code         = code
        @redirect_uri = redirect_uri
      end

      def call
        adapter = Auth.oauth(@provider)
        tokens  = adapter.exchange_code(code: @code, redirect_uri: @redirect_uri)
        profile = adapter.fetch_user_info(access_token: tokens[:access_token])

        return Result.new(ok?: false, error: "OAuth provider returned no email") if profile.email.blank?

        oauth_row, user, new_user = link_or_create(profile, tokens)
        session = user.sessions.create!

        Seams::Events::Publisher.publish(
          new_user ? "user.signed_up.auth" : "user.signed_in.auth",
          auth_user_id: user.id,
          host_user_id: user.host_user_id,
          session_id:   session.id,
          email:        user.email
        )

        Result.new(ok?: true, user: user, session: session,
                   oauth_provider: oauth_row, new_user: new_user)
      rescue Auth::OAuthError, ActiveRecord::RecordInvalid => e
        Result.new(ok?: false, error: e.message)
      end

      private

      def link_or_create(profile, tokens)
        Provider.transaction do
          oauth_row = Provider.find_by(provider: @provider, provider_uid: profile.provider_uid)

          new_user = false
          user =
            if oauth_row
              oauth_row.user
            else
              existing = Auth::User.find_by(email: profile.email.to_s.downcase)
              existing || begin
                new_user = true
                # Random unguessable password — OAuth users don't have a
                # password but the column is required. They sign in via
                # the provider; password reset lets them set one later.
                Auth::User.create!(
                  email:    profile.email,
                  password: SecureRandom.urlsafe_base64(32)
                )
              end
            end

          oauth_row ||= Provider.new(provider: @provider, provider_uid: profile.provider_uid, user: user)
          oauth_row.assign_attributes(
            access_token:  tokens[:access_token],
            refresh_token: tokens[:refresh_token],
            expires_at:    tokens[:expires_in] ? Time.current + tokens[:expires_in].to_i : nil,
            token_type:    tokens[:token_type] || "Bearer",
            profile_data:  profile.raw
          )
          oauth_row.save!

          [oauth_row, user, new_user]
        end
      end
    end
  end
end
