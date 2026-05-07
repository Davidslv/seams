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
        return if File.read(application_rb).include?(snippet)

        say "  inject  config/application.rb (require_relative \"seams_engines\")", :green
        inject_into_file(
          application_rb,
          "\n#{snippet}\n",
          after: /Bundler\.require\(\*Rails\.groups\)\n/
        )
      end

      def create_host_rubocop
        # Generated engine .rubocop.yml files inherit from ../../.rubocop.yml
        # so the host needs one. We don't overwrite an existing config.
        return if File.exist?(File.join(destination_root, ".rubocop.yml"))

        template "rubocop.yml.tt", ".rubocop.yml"
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

      def wire_into_host
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

      def post_install_message
        say ""
        say "  Seams is installed. Generate your first engine with:", :green
        say "    bin/seams engine core   (or bin/rails generate seams:engine core)"
        say ""
        say "  Other useful commands:", :yellow
        say "    bin/seams list          - list engines + their events"
        say "    bin/seams core          - generate the canonical Core engine (concerns, audit log)"
        say "    bin/seams auth          - generate the canonical Auth engine"
        say "    bin/seams notifications - generate the canonical Notifications engine"
        say "    bin/seams billing       - generate the canonical Billing engine"
        say "    bin/seams teams         - generate the canonical Teams engine"
        say ""
      end
    end
  end
end
