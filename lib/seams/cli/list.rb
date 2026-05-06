# frozen_string_literal: true

require "seams"

module Seams
  module CLI
    # Implementation behind `bin/rails seams:list` — discovers every
    # engine under engines/, looks up its registered events in
    # Seams::EventRegistry, and prints a summary.
    class List
      DEFAULT_ENGINES_ROOT = "engines"

      def initialize(engines_root: DEFAULT_ENGINES_ROOT, output: $stdout)
        @engines_root = engines_root
        @output       = output
      end

      def call
        engines = discover_engines
        @output.puts("seams: #{engines.size} engine(s) installed")

        if engines.empty?
          @output.puts("  (no engines — generate one with `bin/rails generate seams:engine <name>`)")
          return
        end

        engines.each do |engine|
          print_engine(engine)
        end
      end

      private

      def discover_engines
        return [] unless Dir.exist?(@engines_root)

        Dir.children(@engines_root)
           .select { |child| File.directory?(File.join(@engines_root, child)) }
           .reject { |child| child.start_with?(".") }
           .sort
      end

      def print_engine(name)
        @output.puts("  - #{name}")
        events_for(name).each { |event| @output.puts("      emits: #{event}") }
      end

      def events_for(name)
        module_name = name.split("_").map(&:capitalize).join
        events = Seams::EventRegistry.all.select { |_, owner| owner.to_s == module_name }.keys
        events.empty? ? ["(no events)"] : events
      end
    end
  end
end
