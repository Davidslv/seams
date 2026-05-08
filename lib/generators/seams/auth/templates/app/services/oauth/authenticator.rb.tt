# frozen_string_literal: true

module Auth
  module OAuth
    # Orchestrates the OAuth callback flow:
    #
    #   1. Exchange the authorization `code` for an access token.
    #   2. Fetch the provider's user profile.
    #   3. Find an existing Auth::OAuth::Provider row by (provider,
    #      provider_uid) OR find an existing Auth::Identity by email OR
    #      create a new Auth::Identity. Link the row to the identity.
    #   4. Refresh stored token + profile.
    #   5. Create a new Auth::Session.
    #   6. Publish identity.signed_up.auth (first sign-in via OAuth) or
    #      identity.signed_in.auth (returning identity).
    #
    # Returns a Result: ok?, identity, session, oauth_provider, new_identity, error.
    class Authenticator
      Result = Struct.new(:ok?, :identity, :session, :oauth_provider, :new_identity, :error,
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

        oauth_row, identity, new_identity = link_or_create(profile, tokens)
        session = identity.sessions.create!

        Seams::Events::Publisher.publish(
          new_identity ? "identity.signed_up.auth" : "identity.signed_in.auth",
          identity_id: identity.id,
          session_id:  session.id,
          email:       identity.email
        )

        Result.new(ok?: true, identity: identity, session: session,
                   oauth_provider: oauth_row, new_identity: new_identity)
      rescue Auth::OAuthError, ActiveRecord::RecordInvalid => e
        Result.new(ok?: false, error: e.message)
      end

      private

      def link_or_create(profile, tokens)
        Provider.transaction do
          oauth_row = Provider.find_by(provider: @provider, provider_uid: profile.provider_uid)

          new_identity = false
          identity =
            if oauth_row
              oauth_row.identity
            else
              existing = Auth::Identity.find_by(email: profile.email.to_s.downcase)
              existing || begin
                new_identity = true
                # Random unguessable password — OAuth identities don't have a
                # password but the column is required. They sign in via
                # the provider; password reset lets them set one later.
                Auth::Identity.create!(
                  email:    profile.email,
                  password: SecureRandom.urlsafe_base64(32)
                )
              end
            end

          oauth_row ||= Provider.new(provider: @provider, provider_uid: profile.provider_uid, identity: identity)
          oauth_row.assign_attributes(
            access_token:  tokens[:access_token],
            refresh_token: tokens[:refresh_token],
            expires_at:    tokens[:expires_in] ? Time.current + tokens[:expires_in].to_i : nil,
            token_type:    tokens[:token_type] || "Bearer",
            profile_data:  profile.raw
          )
          oauth_row.save!

          [oauth_row, identity, new_identity]
        end
      end
    end
  end
end
