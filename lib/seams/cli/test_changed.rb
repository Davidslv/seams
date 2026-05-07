# frozen_string_literal: true

require "seams"

module Seams
  module CLI
    # Runs RSpec for every engine that has changed against the merge
    # base with `main` (or another base via the `base:` keyword).
    # Falls back to "run every engine's specs" when the merge base
    # cannot be resolved (CI on a shallow clone, no git, etc) — better
    # to over-run than to silently skip.
    #
    #   bin/rails seams:test:changed                 # base = main
    #   bin/rails seams:test:changed BASE=develop
    #
    # Returns true when every engine spec run passed; false otherwise.
    # The caller (rake task or bin/seams) translates that to an exit
    # code.
    class TestChanged
      DEFAULT_BASE         = "main"
      DEFAULT_ENGINES_ROOT = "engines"

      def initialize(base: DEFAULT_BASE, engines_root: DEFAULT_ENGINES_ROOT, output: $stdout)
        @base         = base
        @engines_root = engines_root
        @output       = output
      end

      def call
        engines = changed_engines
        if engines.empty?
          @output.puts("seams:test:changed — no engines changed since #{@base}; skipping.")
          return true
        end

        @output.puts("seams:test:changed — running specs for #{engines.size} engine(s):")
        engines.each { |name| @output.puts("  - #{name}") }
        @output.puts("")

        failed = engines.reject { |name| run_engine_specs(name) }
        if failed.empty?
          @output.puts("All affected engine specs passed.")
          true
        else
          @output.puts("Failed engines: #{failed.join(", ")}")
          false
        end
      end

      private

      def changed_engines
        return all_engines unless git_available?

        merge_base = resolve_merge_base
        return all_engines if merge_base.empty?

        engine_names_from_diff(merge_base)
      end

      # Array-form shell-out: no interpolation into a shell, so a
      # @base value like `; rm -rf /` passes as one argv element to
      # git rather than getting evaluated. shell_escape is defence in
      # depth on top of that.
      def resolve_merge_base
        capture_command(["git", "merge-base", shell_escape(@base), "HEAD"]).strip
      end

      def engine_names_from_diff(merge_base)
        diff = capture_command(["git", "diff", "--name-only", merge_base, "HEAD", "--",
                                "#{@engines_root}/*"])
        diff.lines
            .filter_map { |line| line.split("/")[1] }
            .uniq
            .sort
            .select { |name| File.directory?(File.join(@engines_root, name)) }
      end

      def capture_command(argv)
        IO.popen(argv, err: File::NULL, &:read)
      rescue StandardError
        ""
      end

      def all_engines
        return [] unless Dir.exist?(@engines_root)

        Dir.children(@engines_root)
           .select { |child| File.directory?(File.join(@engines_root, child)) }
           .reject { |child| child.start_with?(".") }
           .sort
      end

      def run_engine_specs(name)
        spec_dir = File.join(@engines_root, name, "spec")
        return true if Dir.glob(File.join(spec_dir, "**", "*_spec.rb")).empty?

        @output.puts("=== bundle exec rspec #{spec_dir} ===")
        system("bundle", "exec", "rspec", spec_dir)
      end

      def git_available?
        system("which git > /dev/null 2>&1")
      end

      # The base branch comes from a keyword arg or env var — both
      # untrusted. Allow only branch-safe characters before
      # interpolating into a shell-out (we never reach the shell
      # because we shell-escape, but defence in depth keeps the
      # intent explicit).
      def shell_escape(value)
        value.to_s.gsub(%r{[^A-Za-z0-9_\-/.]}, "")
      end
    end
  end
end
