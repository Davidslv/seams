# frozen_string_literal: true

require "rails/generators"
require "seams"

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
        template "spec/spec_helper.rb.tt",   "engines/#{name}/spec/spec_helper.rb"
        template "spec/example_spec.rb.tt",  "engines/#{name}/spec/#{name}_spec.rb"
      end

      def create_license
        template "LICENSE.tt", "engines/#{name}/LICENSE"
      end

      def create_readme
        template "README.md.tt", "engines/#{name}/README.md"
      end

      def update_sibling_engines
        sibling_dirs = sibling_engine_dirs
        all_dirs     = (sibling_dirs + [name]).sort
        return if sibling_dirs.empty?

        all_dirs.each do |engine_dir|
          rewrite_other_engines_for(engine_dir, all_dirs - [engine_dir])
        end

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

      def rewrite_other_engines_for(sibling, others)
        rubocop_path = File.join(engines_root, sibling, ".rubocop.yml")
        return unless File.exist?(rubocop_path)

        sibling_module  = others.map { |o| o.split("_").map(&:capitalize).join }
        content         = File.read(rubocop_path)
        content         = replace_other_engines_block(content, sibling_module, others)
        File.write(rubocop_path, content)
      end

      # Replaces the `OtherEngines:` lists under both
      # `Seams/NoCrossEngineModelAccess` and `Seams/NoCrossEngineDependency`.
      # Module-name list goes under ModelAccess (CamelCase); directory
      # name list goes under Dependency (snake_case).
      def replace_other_engines_block(content, modules_list, dirs_list)
        content = replace_block(content, "Seams/NoCrossEngineModelAccess", modules_list)
        replace_block(content, "Seams/NoCrossEngineDependency", dirs_list)
      end

      def replace_block(content, cop_name, values)
        formatted = values.map { |v| "    - #{v}" }.join("\n")
        formatted = formatted.empty? ? "  OtherEngines: []" : "  OtherEngines:\n#{formatted}"

        content.sub(
          /(#{Regexp.escape(cop_name)}:.*?\n)(  OtherEngines:.*?(?=\n[A-Z]|\Z))/m,
          "\\1#{formatted}"
        )
      end
    end
  end
end
