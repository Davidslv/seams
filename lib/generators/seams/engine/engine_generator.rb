# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "seams/generators/host_injector"
require "seams/generators/sibling_rubocop_writer"
require "seams/generators/dummy_app_writer"

module Seams
  module Generators
    # Generates a new Rails engine under engines/<name>/, fully isolated
    # via `isolate_namespace`, with the Seams boundary cops pre-wired in
    # the engine's own .rubocop.yml. After generating the new engine,
    # the cop config of every existing sibling engine is updated so
    # boundary enforcement covers the new engine without manual edits.
    #
    # Run with: bin/rails generate seams:engine billing
    class EngineGenerator < Rails::Generators::NamedBase
      include Seams::Generators::HostInjector

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
        # Phase 1.6 — engine-scoped abstract AR base.
        template "app/application_record.rb.tt",
                 "engines/#{name}/app/models/#{name}/application_record.rb"
      end

      # Phase 1.6 — i18n stub + standalone Gemfile + Rakefile so the
      # engine can be tested in isolation (cd engines/<name> && rake).
      def create_locales
        template "config/locales/en.yml.tt",
                 "engines/#{name}/config/locales/en.yml"
      end

      def create_engine_gemfile
        template "Gemfile.tt", "engines/#{name}/Gemfile"
      end

      def create_engine_rakefile
        template "Rakefile.tt", "engines/#{name}/Rakefile"
      end

      # Phase 1.6 — per-engine dummy app via the shared DummyAppWriter.
      # Generic engines start with an empty schema; canonical
      # generators (auth/billing/etc) overwrite this with their own
      # schema by calling DummyAppWriter.write! again with the right
      # SCHEMA body. Keeping this here means even a vanilla
      # `seams:engine reporting` ships a bootable spec/dummy.
      def create_dummy_app
        Seams::Generators::DummyAppWriter.write!(
          engine_path: File.join(destination_root, "engines", name),
          engine_module: module_name,
          mount_at: "/#{name}",
          schema: "# generic engine — no schema yet"
        )
      end

      def create_rubocop_config
        template "rubocop.yml.tt", "engines/#{name}/.rubocop.yml"
      end

      def create_spec_helper
        template "spec/spec_helper.rb.tt",   "engines/#{name}/spec/spec_helper.rb"
        template "spec/example_spec.rb.tt",  "engines/#{name}/spec/#{name}_spec.rb"
      end

      def create_license
        template "LICENSE.tt", "engines/#{name}/LICENSE"
      end

      def create_readme
        template "README.md.tt", "engines/#{name}/README.md"
      end

      def wire_into_host
        # Mount the engine into the host's routes (idempotent — skips
        # if the line already exists, so canonical generators that
        # call this and ALSO mount themselves are safe).
        host_inject_mount(engine_class: "#{module_name}::Engine", at: "/#{name}")

        # Drop a host-side initializer stub the user can fill in.
        # Skipped if a canonical generator (or the host) has already
        # created one.
        initializer_path = File.join(destination_root, "config/initializers/#{name}.rb")
        if File.exist?(initializer_path)
          say "  exist   config/initializers/#{name}.rb (kept)", :blue
        elsif File.directory?(File.join(destination_root, "config/initializers"))
          template "host_initializer.rb.tt", "config/initializers/#{name}.rb"
        end
      end

      def update_sibling_engines
        sibling_dirs = sibling_engine_dirs
        return if sibling_dirs.empty?

        Seams::Generators::SiblingRubocopWriter.rewrite!(
          engines_root: engines_root,
          dirs: (sibling_dirs + [name]).sort
        )

        say "  update  .rubocop.yml of #{sibling_dirs.size} sibling engine(s)", :green
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

      def engines_root
        File.join(destination_root, "engines")
      end

      def sibling_engine_dirs
        return [] unless Dir.exist?(engines_root)

        Dir.children(engines_root)
           .select { |child| File.directory?(File.join(engines_root, child)) }
           .reject { |child| child.start_with?(".") || child == name }
           .sort
      end
    end
  end
end
