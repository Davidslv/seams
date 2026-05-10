# frozen_string_literal: true

require "rails/generators"
require "seams/generators/host_injector"

module Seams
  module Generators
    # Adds the Seams framework to a host Rails application:
    #
    #   - config/initializers/seams.rb        (configure adapters)
    #   - config/initializers/seams_engines.rb (load engines/* into autoload)
    #   - engines/.keep                       (where future engines live)
    #   - lib/tasks/seams.rake                (rake namespace)
    #
    # Run with: bin/rails generate seams:install
    class InstallGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector

      source_root File.expand_path("templates", __dir__)

      def create_initializer
        template "seams.rb.tt", "config/initializers/seams.rb"
      end

      def create_engines_directory
        empty_directory "engines"
        create_file "engines/.keep"
      end

      def create_rake_tasks
        template "seams.rake.tt", "lib/tasks/seams.rake"
      end

      def append_engines_to_eager_load
        template "seams_engines.rb.tt", "config/seams_engines.rb"
      end

      def wire_engines_into_application_rb
        # Each engine under engines/ must be required BEFORE
        # Rails.application.initialize! so its Railtie registers paths
        # (db/migrate, app/*) and initializers with the host. The
        # `require_relative` is injected directly after Bundler.require.
        application_rb = File.join(destination_root, "config/application.rb")
        return unless File.exist?(application_rb)

        snippet = %(require_relative "seams_engines")
        contents = File.read(application_rb)
        return if contents.include?(snippet)

        # The default Rails 8 application.rb contains
        # `Bundler.require(*Rails.groups)` verbatim. If a host has
        # customised it (Rails 4-style asset groups, multi-arg
        # Bundler.require, brace-form do-block, trailing comment, ...),
        # the regex misses and Thor silently warns "File unchanged!"
        # — leaving the host bootable but with engines never required.
        # That is the worst kind of failure: silent + production-bug.
        # Print a loud red warning so the user knows to wire it by hand.
        anchor = /Bundler\.require\(\*Rails\.groups\)\n/
        unless contents.match?(anchor)
          say "  WARNING config/application.rb has no `Bundler.require(*Rails.groups)` line — " \
              "add `#{snippet}` manually after Bundler.require so engines load before initialize!",
              :red
          return
        end

        say "  inject  config/application.rb (require_relative \"seams_engines\")", :green
        inject_into_file(application_rb, "\n#{snippet}\n", after: anchor)
      end

      def create_host_rubocop
        # Three cases:
        #   1. Host has no .rubocop.yml → write the seams baseline.
        #   2. Host already has one → don't overwrite, but inject an
        #      `engines/**/*` Exclude so host RuboCop (which may use
        #      rubocop-rails-omakase or another flavor) doesn't lint
        #      engine code under rules written for application code.
        #      Engines have their own self-contained .rubocop.yml.
        host_path = File.join(destination_root, ".rubocop.yml")
        unless File.exist?(host_path)
          template "rubocop.yml.tt", ".rubocop.yml"
          return
        end

        return if File.read(host_path).include?("engines/**/*")

        say "  inject  .rubocop.yml (Exclude engines + seams.rake)", :green
        append_to_file(host_path, <<~YML)

          # Engines have their own self-contained .rubocop.yml. Linting them
          # from the host runs gem-style code under whatever flavor of rules
          # the host uses (omakase / etc.) and produces noisy false positives.
          # The gem-generated lib/tasks/seams.rake is excluded for the same
          # reason.
          AllCops:
            Exclude:
              - "engines/**/*"
              - "lib/tasks/seams.rake"
        YML
      end

      def create_ruby_version
        # The host CI workflow does `ruby-version: ".ruby-version"`, so the
        # host needs a `.ruby-version` file. Rails 8's `rails new` doesn't
        # ship one. Don't overwrite if the host has pinned their own.
        return if File.exist?(File.join(destination_root, ".ruby-version"))

        template "ruby-version.tt", ".ruby-version"
      end

      def create_ci_workflow
        template "ci.yml.tt", ".github/workflows/ci.yml"
      end

      def create_deployment_templates
        # Skip any file the host already has — Rails 8 ships its own
        # Dockerfile and bin/docker-entrypoint.
        template_if_missing "Dockerfile.tt",         "Dockerfile"
        template_if_missing "docker-entrypoint.tt",  "bin/docker-entrypoint"
        template_if_missing "Procfile.tt",           "Procfile"
        template_if_missing "deploy.yml.tt",         "config/deploy.yml"

        full = File.join(destination_root, "bin/docker-entrypoint")
        File.chmod(0o755, full) if File.exist?(full)
      end

      def create_bin_seams
        template "bin_seams.tt", "bin/seams"
        full_path = File.join(destination_root, "bin/seams")
        File.chmod(0o755, full_path) if File.exist?(full_path)
      end

      # Phase 1.5 — per-host helper scripts and architecture doc.
      def create_helper_scripts
        template_if_missing "script/collate_coverage.rb.tt",   "script/collate_coverage.rb"
        template_if_missing "script/run_affected_tests.sh.tt", "script/run_affected_tests.sh"

        runner = File.join(destination_root, "script/run_affected_tests.sh")
        File.chmod(0o755, runner) if File.exist?(runner)
      end

      def create_architecture_doc
        template_if_missing "doc/ARCHITECTURE.md.tt", "doc/ARCHITECTURE.md"
      end

      def wire_into_host
        # Auto-add seams to the host Gemfile if not already present —
        # covers the `gem install seams` global-install path. Pinned to
        # a pessimistic 0.x to keep major-version bumps explicit.
        host_inject_gem("seams", "~> #{Seams::VERSION}")
        # Every Seams host needs rspec-rails so the per-engine
        # spec/dummy specs can actually run. Idempotent — skipped if
        # the host already has these gems.
        host_inject_gem("rspec-rails", "~> 7.1", group: :test)
      end

      private

      def template_if_missing(source, destination_relative)
        full = File.join(destination_root, destination_relative)
        if File.exist?(full)
          say "  exist   #{destination_relative} (kept)", :blue
        else
          template source, destination_relative
        end
      end

      public

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def post_install_message
        say ""
        say "  Seams is installed. Generate your first engine with:", :green
        say "    bin/seams core          (or bin/rails generate seams:core)"
        say ""
        say "  Canonical generators (run in this order):", :yellow
        say "    bin/seams core          - Core engine (concerns, audit log)"
        say "    bin/seams auth          - Auth engine (Identity, sessions, OAuth)"
        say "    bin/seams accounts      - Accounts engine (tenant + Membership + system actor)"
        say "    bin/seams notifications - Notifications engine"
        say "    bin/seams billing       - Billing engine"
        say "    bin/seams teams         - Teams engine"
        say ""
        say "  Optional engines (generate after the canonical six are in place):", :yellow
        say "    bin/seams admin         - Admin engine (Administrate-backed dashboards"
        say "                              for the canonical models, Pundit-gated,"
        say "                              audit-log auto-write). Requires auth + accounts."
        say ""
        say "  Follow-up generators (extend an already-installed engine):", :yellow
        say "    bin/rails generate seams:auth:add_oauth_provider <name>"
        say "                            - add a new OAuth provider adapter"
        say "                              (e.g. linkedin, apple, microsoft)"
        say ""
        say "  Other useful commands:", :yellow
        say "    bin/seams list                          - list engines + their events"
        say "    bin/seams resolve --eject <engine>/<file>"
        say "                                            - mark a host file as host-owned"
        say "                                              (skipped on regenerate)"
        say "    bin/seams resolve --list-markers <engine>"
        say "                                            - list insertion-point markers"
        say "    bin/seams resolve --list-ejected        - list every ejected file under engines/"
        say ""
        say "  Recommended order: core -> auth -> accounts -> notifications -> billing -> teams.", :yellow
        say "  Optional: append `admin` last for an Administrate-backed admin surface.", :yellow
        say "  See doc/CURRENT_ATTRIBUTES.md (after install) for the per-request namespace cascade.", :yellow
        say "  See doc/WRITING_FOLLOW_UP_GENERATORS.md to write your own follow-up generator.", :yellow
        say ""
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
