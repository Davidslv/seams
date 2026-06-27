# frozen_string_literal: true

require "seams"

module Seams
  module CLI
    # Implementation behind `bin/rails seams:list` — discovers every
    # engine under engines/, looks up its registered events in
    # Seams::EventRegistry, and prints a summary.
    class List
      # Default directory that holds the generated engines.
      DEFAULT_ENGINES_ROOT = "engines"

      # Matches the top-level `module Foo` declaration in an engine file.
      MODULE_DECLARATION = /\bmodule\s+([A-Z][A-Za-z0-9_]*)\b/

      def initialize(engines_root: DEFAULT_ENGINES_ROOT, output: $stdout)
        @engines_root = engines_root
        @output       = output
      end

      # Discover the engines, gather their events, and print the report.
      # @return [Boolean] true on success.
      def call
        engines = discover_engines
        @output.puts("seams: #{engines.size} engine(s) installed")

        if engines.empty?
          @output.puts("  (no engines — generate one with `bin/rails generate seams:engine <name>`)")
          return
        end

        engines.each { |engine| print_engine(engine) }
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
        events_for(name).each        { |event| @output.puts("      emits:      #{event}") }
        subscriptions_for(name).each { |event| @output.puts("      subscribes: #{event}") }
        depends_on(name).each        { |dep|   @output.puts("      depends on: #{dep}") }
      end

      def events_for(name)
        module_name = module_name_for(name)
        events      = Seams::EventRegistry.all.select { |_, owner| owner.to_s == module_name }.keys
        events.empty? ? ["(no events)"] : events
      end

      # Returns the event names this engine subscribes to. Looks in
      # both the engine.rb itself AND in `app/subscribers/**/*.rb` —
      # the canonical seams convention, where each subscriber class
      # calls `Publisher.attach_class(KEY, "event.name", ...)` (or the
      # legacy `attach_once`) from an `attach!` class method that the
      # engine's `config.after_initialize` block invokes. Without
      # scanning `app/subscribers/` this method silently reported zero
      # subscribers for every generated engine, hiding the
      # cross-engine dependency graph this command exists to surface.
      def subscriptions_for(name)
        subscription_sources_for(name)
          .filter_map { |path| File.read(path) if File.exist?(path) }
          .flat_map do |content|
            content.scan(/Publisher\.(?:subscribe|attach_once|attach_class)\([^"']*["']([^"']+)["']/m)
                   .flatten
          end
          .uniq
      end

      def subscription_sources_for(name)
        engine_rb       = File.join(@engines_root, name, "lib", name, "engine.rb")
        subscriber_glob = File.join(@engines_root, name, "app", "subscribers", "**", "*.rb")

        # Dir.glob is already sorted on every supported Ruby version.
        [engine_rb, *Dir.glob(subscriber_glob)]
      end

      # Walks the subscribe-list and resolves each event back to the
      # engine that emits it (via the canonical "name.action.<engine>"
      # naming convention). Returns the set of distinct engine names
      # this one depends on.
      def depends_on(name)
        subscriptions_for(name)
          .map { |event| event.split(".").last }
          .reject { |dep| dep.nil? || dep == name }
          .uniq
          .sort
      end

      # Tries to find the engine's actual Ruby module name by reading
      # its lib/<name>.rb. Falls back to a CamelCase conversion of the
      # directory name (so `oauth2` becomes `Oauth2` rather than
      # crashing) when the file is missing or doesn't declare a module.
      def module_name_for(name)
        root_file = File.join(@engines_root, name, "lib", "#{name}.rb")

        if File.exist?(root_file)
          match = File.read(root_file).match(MODULE_DECLARATION)
          return match[1] if match
        end

        name.split("_").map(&:capitalize).join
      end
    end
  end
end
