# frozen_string_literal: true

module Auth
  class Engine < ::Rails::Engine
    isolate_namespace Auth

    config.generators do |g|
      g.test_framework :rspec
    end

    # Zeitwerk's default inflector lower-cases everything between
    # underscores, so an `oauth/` directory maps to `Oauth::` (single-O)
    # instead of the `OAuth::` (camel-OA) namespace we use for the
    # provider model + authenticator + callbacks controller (and the
    # lib/ adapters Google/Github/Abstract). Single-entry inflection so
    # the override only affects directories named exactly "oauth" — a
    # host's own `oauth_provider.rb` (no trailing directory) stays on
    # the default mapping.
    initializer "auth.zeitwerk_inflections", before: :set_autoload_paths do
      Rails.autoloaders.main.inflector.inflect("oauth" => "OAuth")
    end

    initializer "auth.register_events" do
      Seams::EventRegistry.register("user.signed_up.auth",   emitted_by: "Auth")
      Seams::EventRegistry.register("user.signed_in.auth",   emitted_by: "Auth")
      Seams::EventRegistry.register("user.signed_out.auth",  emitted_by: "Auth")
      Seams::EventRegistry.register("session.expired.auth",  emitted_by: "Auth")
      # API token lifecycle (issue #2 section 2A)
      Seams::EventRegistry.register("api_token.issued.auth", emitted_by: "Auth")
      Seams::EventRegistry.register("api_token.revoked.auth", emitted_by: "Auth")
    end

    initializer "auth.append_migrations" do |app|
      unless app.root == root
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
