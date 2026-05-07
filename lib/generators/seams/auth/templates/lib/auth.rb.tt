# frozen_string_literal: true

require "auth/version"
require "auth/configuration"
require "auth/engine"
require "auth/concerns/authenticatable"
require "auth/concerns/authentication"

module Auth
  class Error               < StandardError; end
  class OAuthError          < Error; end
  class OAuthProviderUnknown < OAuthError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    # Build a configured OAuth adapter for the given provider key.
    # Reads `Auth.configuration.oauth_providers[name]` for the adapter
    # class + client_id + client_secret + scopes; raises if the
    # provider isn't configured.
    def oauth(provider_name)
      conf = configuration.oauth_providers[provider_name.to_sym]
      raise OAuthProviderUnknown, "OAuth provider #{provider_name.inspect} is not configured" unless conf

      adapter_class = Object.const_get(conf.fetch(:adapter))
      adapter_class.new(
        client_id:     conf.fetch(:client_id),
        client_secret: conf.fetch(:client_secret),
        scopes:        conf[:scopes] || adapter_class::DEFAULT_SCOPES
      )
    end
  end
end
