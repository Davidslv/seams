# frozen_string_literal: true

require "rails/generators"
require "seams"

module Seams
  module Generators
    # Generates a new Rails engine under engines/<name>/, fully isolated
    # via `isolate_namespace`, with the Seams boundary cops pre-wired in
    # the engine's own .rubocop.yml and a Combustion-based spec_helper
    # for fast in-process tests.
    #
    # Run with: bin/rails generate seams:engine billing
    class EngineGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/

      def validate_name
        unless NAME_PATTERN.match?(name)
          raise Seams::GeneratorError,
                "Engine name #{name.inspect} must be lowercase letters, digits, " \
                "and underscores, starting with a letter."
        end

        engine_root = File.join(destination_root, "engines", name)
        return unless File.exist?(engine_root)

        raise Seams::GeneratorError, "Engine #{name.inspect} already exists at #{engine_root}"
      end

      def create_gemspec
        template "gemspec.tt", "engines/#{name}/#{name}.gemspec"
      end

      def create_lib
        template "lib/engine.rb.tt",  "engines/#{name}/lib/#{name}/engine.rb"
        template "lib/version.rb.tt", "engines/#{name}/lib/#{name}/version.rb"
        template "lib/root.rb.tt",    "engines/#{name}/lib/#{name}.rb"
      end

      def create_config
        template "config/routes.rb.tt", "engines/#{name}/config/routes.rb"
      end

      def create_app
        template "app/application_controller.rb.tt",
                 "engines/#{name}/app/controllers/#{name}/application_controller.rb"
      end

      def create_rubocop_config
        template "rubocop.yml.tt", "engines/#{name}/.rubocop.yml"
      end

      def create_spec_helper
        template "spec/spec_helper.rb.tt",  "engines/#{name}/spec/spec_helper.rb"
        template "spec/internal_app.rb.tt", "engines/#{name}/spec/internal/config/application.rb"
      end

      def create_readme
        template "README.md.tt", "engines/#{name}/README.md"
      end

      def report
        say ""
        say "  Engine `#{name}` generated at engines/#{name}/", :green
        say "  Run its specs with: bin/rails seams:test[#{name}]"
        say ""
      end

      private

      def module_name
        name.split("_").map(&:capitalize).join
      end
    end
  end
end
