# frozen_string_literal: true

require "fileutils"

module Seams
  module Generators
    # Rewrites the OtherEngines lists inside every engine's .rubocop.yml
    # so each engine is configured with every OTHER engine as a
    # boundary. Used by both the seams:engine and seams:remove
    # generators — generation adds the new engine, removal prunes the
    # gone one.
    #
    # The replacement is scoped tightly to the OtherEngines key so we
    # never clobber the surrounding ExposedConcerns / Enabled / OwnEngine
    # values. The previous version of this code used a too-greedy
    # lookahead that ate the next sibling key.
    module SiblingRubocopWriter
      module_function

      MODULE_ACCESS_KEY = "Seams/NoCrossEngineModelAccess"
      DEPENDENCY_KEY    = "Seams/NoCrossEngineDependency"

      # @param engines_root [String] absolute or relative path to engines/
      # @param dirs         [Array<String>] directory names of the engines
      #                     that currently exist on disk
      def rewrite!(engines_root:, dirs:)
        dirs.each do |engine_dir|
          others        = (dirs - [engine_dir]).sort
          others_module = others.map { |d| camelcase(d) }
          rubocop_path  = File.join(engines_root, engine_dir, ".rubocop.yml")
          next unless File.exist?(rubocop_path)

          content = File.read(rubocop_path)
          content = replace_other_engines(content, MODULE_ACCESS_KEY, others_module)
          content = replace_other_engines(content, DEPENDENCY_KEY,    others)
          File.write(rubocop_path, content)
        end
      end

      def camelcase(name)
        name.split("_").map(&:capitalize).join
      end

      # Matches `<cop_key>:` and the very next `OtherEngines:` line under
      # it, replacing only the value of OtherEngines. We don't try to
      # span multiple following keys — the regex stops as soon as it has
      # consumed either the inline `[]` form or the indented list form.
      def replace_other_engines(content, cop_key, values)
        formatted_block(values).then do |formatted|
          content.sub(other_engines_regex(cop_key), "\\1#{formatted}\n")
        end
      end

      def formatted_block(values)
        return "  OtherEngines: []" if values.empty?

        "  OtherEngines:\n#{values.map { |v| "    - #{v}" }.join("\n")}"
      end

      def other_engines_regex(cop_key)
        prefix     = "#{Regexp.escape(cop_key)}:[^\\n]*\\n(?:[ \\t]+[^\\n]+\\n)*?"
        empty_form = "[ \\t]*\\[\\][ \\t]*\\n"
        list_form  = "[ \\t]*\\n(?:    -[ \\t]+[^\\n]+\\n)*"
        Regexp.new("(#{prefix})  OtherEngines:(?:#{empty_form}|#{list_form})")
      end
    end
  end
end
