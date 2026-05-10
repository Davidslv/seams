# frozen_string_literal: true

require "rails/generators"
require "seams"
require "seams/generators/follow_up_generator"

module Seams
  module Generators
    module Auth
      # Adds a new OAuth provider adapter to an already-generated Auth
      # engine. The first showcase follow-up generator built on top of
      # the Wave 10 Phase 1 insertion-point machinery.
      #
      # Run with:
      #
      #   bin/rails generate seams:auth:add_oauth_provider linkedin
      #   bin/rails generate seams:auth:add_oauth_provider apple
      #   bin/rails generate seams:auth:add_oauth_provider microsoft
      #
      # What it does:
      #
      #   1. Creates engines/auth/lib/auth/oauth/<name>.rb (subclasses
      #      Auth::OAuth::Abstract, with TODOs the host fills in).
      #   2. Splices a configuration entry into
      #      engines/auth/lib/auth/configuration.rb at the
      #      `auth.configuration.oauth_providers` marker.
      #   3. Creates engines/auth/spec/lib/auth/oauth/<name>_spec.rb
      #      covering the abstract contract.
      #
      # The existing `scope "/oauth/:provider"` route in
      # engines/auth/config/routes.rb already handles every configured
      # provider via the `:provider` param — the generator does NOT
      # splice into auth.routes.after_oauth or any other route marker.
      # Likewise, the `_oauth_buttons.html.erb` partial iterates
      # `Auth.configuration.oauth_providers.each_key`, so the new entry
      # auto-renders without a partial edit.
      #
      # Idempotent on rerun: the underlying Splicer detects the splice
      # has already happened and skips. The adapter file itself is
      # written via `template`, which Thor's --skip flag (default)
      # leaves alone if it already exists.
      class AddOauthProviderGenerator < Seams::Generators::FollowUpGenerator
        engine_name "auth"

        source_root File.expand_path("templates", __dir__)

        argument :name, type: :string, banner: "<provider>",
                        desc: "The provider name (e.g. linkedin, apple, microsoft)"

        # Provider names share the engine-name regex: lowercase letters,
        # digits, underscores, starting with a letter. Hyphens, mixed
        # case, and dots are normalised to underscores by `snake_name`.
        NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/

        CONFIGURATION_FILE = "lib/auth/configuration.rb"
        CONFIGURATION_MARKER = "auth.configuration.oauth_providers"

        def normalise_name
          @snake_name = name.to_s.strip.downcase
                            .gsub(/[^a-z0-9]+/, "_").squeeze("_")
                            .gsub(/^_|_$/, "")

          if @snake_name.empty?
            raise Seams::GeneratorError,
                  "Provider name #{name.inspect} normalises to an empty string. " \
                  "Pass a name like `linkedin`, `apple`, or `microsoft`."
          end

          return if NAME_PATTERN.match?(@snake_name)

          raise Seams::GeneratorError,
                "Provider name #{name.inspect} must be lowercase letters, digits, " \
                "and underscores, starting with a letter."
        end

        def assert_engine_present
          assert_marker_exists!(file: CONFIGURATION_FILE, marker: CONFIGURATION_MARKER)
        end

        def create_adapter
          template "adapter.rb.tt", engine_path("lib/auth/oauth/#{snake_name}.rb")
        end

        def splice_configuration_entry
          splice(
            file: CONFIGURATION_FILE,
            marker: CONFIGURATION_MARKER,
            content: configuration_entry
          )
        end

        def create_adapter_spec
          template "adapter_spec.rb.tt",
                   engine_path("spec/lib/auth/oauth/#{snake_name}_spec.rb")
        end

        # rubocop:disable Metrics/AbcSize
        def report_summary
          say ""
          say "  Auth OAuth provider `#{snake_name}` added.", :green
          say ""
          say "  Files:", :yellow
          say "    engines/auth/lib/auth/oauth/#{snake_name}.rb"
          say "    engines/auth/spec/lib/auth/oauth/#{snake_name}_spec.rb"
          say "  Spliced:", :yellow
          say "    engines/auth/lib/auth/configuration.rb @ #{CONFIGURATION_MARKER}"
          say ""
          say "  Routes: the existing `scope \"/oauth/:provider\"` block matches", :blue
          say "          every configured provider — no route splice needed."
          say "  View:   the engine's _oauth_buttons.html.erb partial iterates", :blue
          say "          Auth.configuration.oauth_providers — no partial edit needed."
          say ""
          say "  Next steps:", :yellow
          say "    1. Set #{upper_name}_OAUTH_CLIENT_ID and #{upper_name}_OAUTH_CLIENT_SECRET in your environment."
          say "    2. Replace the TODO placeholders in lib/auth/oauth/#{snake_name}.rb with"
          say "       the provider's real OAuth endpoints + userinfo mapping."
          say "    3. Run the spec: bin/rails seams:test[auth] (or rspec the new file)."
          say "    4. Test the OAuth flow against the provider's sandbox."
          say ""
          say "  Want to customise the adapter beyond the TODOs (override behaviour, change the", :blue
          say "  spec shape, etc.)? Eject it so subsequent regenerations of auth leave it alone:"
          say "    bin/seams resolve --eject auth/lib/auth/oauth/#{snake_name}.rb"
          say ""
        end
        # rubocop:enable Metrics/AbcSize

        private

        # Exposed to the templates via ERB binding.
        attr_reader :snake_name

        def camel_name
          snake_name.split("_").map(&:capitalize).join
        end

        def upper_name
          snake_name.upcase
        end

        # The hash entry to splice after the marker. Two-space indent
        # inside the entry so the splicer's auto-detected outer indent
        # (8 spaces, matching the marker line) lands the inner keys at
        # 10 spaces — same shape Phase 2A's marker placement implies.
        def configuration_entry
          <<~RUBY
            #{snake_name}: {
              adapter:       "Auth::OAuth::#{camel_name}",
              client_id:     ENV.fetch("#{upper_name}_OAUTH_CLIENT_ID", nil),
              client_secret: ENV.fetch("#{upper_name}_OAUTH_CLIENT_SECRET", nil),
              scopes:        %w[profile email]
            },
          RUBY
        end
      end
    end
  end
end
