# frozen_string_literal: true

module Auth
  module OAuth
    # Contract every OAuth provider adapter must implement. Subclass
    # this in the host application to wire additional providers
    # (Apple Sign In, Microsoft, GitLab, etc.) and register the
    # subclass in `Auth.configuration.oauth_providers`.
    #
    # The Auth engine ships two concrete adapters: Auth::OAuth::Google
    # and Auth::OAuth::Github. See those files for fully-worked
    # examples + the docs URLs each was verified against.
    #
    # All adapters are stateless. Build them per-request via
    # +Auth::OAuth.build(:provider_name)+ which reads credentials from
    # +Auth.configuration.oauth_providers+.
    class Abstract
      # Returned by #fetch_user_info — the normalised user representation
      # downstream code uses to find-or-create the local OAuth row.
      Profile = Struct.new(:provider_uid, :email, :email_verified, :name, :avatar_url, :raw,
                           keyword_init: true)

      def initialize(client_id:, client_secret:, scopes: [])
        @client_id     = client_id
        @client_secret = client_secret
        @scopes        = scopes
      end

      # The URL the host redirects the user to. State is the
      # CSRF-protection token the host generates and re-verifies on
      # callback.
      def authorize_url(state:, redirect_uri:)
        raise NotImplementedError, "#{self.class} must implement #authorize_url"
      end

      # Exchange the `code` query param from the callback for an
      # access token. Returns a hash with keys :access_token,
      # :refresh_token (may be nil), :expires_in (may be nil),
      # :token_type, :scope.
      def exchange_code(code:, redirect_uri:)
        raise NotImplementedError, "#{self.class} must implement #exchange_code"
      end

      # Fetch the user's profile from the provider's userinfo
      # endpoint. Returns a Profile struct.
      def fetch_user_info(access_token:)
        raise NotImplementedError, "#{self.class} must implement #fetch_user_info"
      end

      protected

      attr_reader :client_id, :client_secret, :scopes

      # Single Faraday connection per adapter instance. Subclasses set
      # the base URL; we share timeout + retry config across providers.
      def conn(base_url)
        Faraday.new(url: base_url) do |f|
          f.request :url_encoded
          f.options.timeout      = 10
          f.options.open_timeout = 5
          f.adapter Faraday.default_adapter
        end
      end

      def parse_json(response, action:)
        return {} if response.body.to_s.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError => e
        raise Auth::OAuthError,
              "OAuth #{provider_name} #{action}: response was not valid JSON (#{e.message})"
      end

      def assert_success!(response, action:)
        return if response.success?

        body = response.body.to_s[0, 200]
        raise Auth::OAuthError,
              "OAuth #{provider_name} #{action}: HTTP #{response.status} — #{body}"
      end

      def provider_name
        self.class.name.to_s.split("::").last.downcase
      end
    end
  end
end
