# frozen_string_literal: true

require "seams"

module Seams
  module CLI
    # Runs the four quality gates the host's `bin/audit` script also
    # runs (RuboCop, Brakeman, bundler-audit, SimpleCov collation), in
    # one shot, and reports a unified summary. Each tool that is not
    # installed in the host's bundle is skipped with a note rather
    # than failing — hosts opt in by adding the gem.
    #
    #   bin/rails seams:quality:all
    #
    # Returns true when every gate that ran passed; false otherwise.
    class Quality
      # Default directory that holds the generated engines.
      DEFAULT_ENGINES_ROOT = "engines"

      def initialize(engines_root: DEFAULT_ENGINES_ROOT, output: $stdout)
        @engines_root = engines_root
        @output       = output
        @results      = {}
      end

      # Run the quality gates across every engine.
      # @return [Boolean] true when every gate that ran passed.
      def call
        run_rubocop
        run_brakeman
        run_bundler_audit
        run_simplecov_collation

        print_summary
        @results.values.all? { |status| %i[pass skipped].include?(status) }
      end

      private

      def run_rubocop
        if gem_installed?("rubocop")
          @output.puts("=== rubocop --parallel ===")
          @results[:rubocop] = system("bundle", "exec", "rubocop", "--parallel") ? :pass : :fail
        else
          @output.puts("rubocop not installed — skipping.")
          @results[:rubocop] = :skipped
        end
      end

      def run_brakeman
        if gem_installed?("brakeman")
          @output.puts("=== brakeman ===")
          @results[:brakeman] =
            system("bundle", "exec", "brakeman", "--no-pager", "--no-progress", "--quiet") ? :pass : :fail
        else
          @output.puts("brakeman not installed — skipping.")
          @results[:brakeman] = :skipped
        end
      end

      def run_bundler_audit
        if gem_installed?("bundler-audit")
          @output.puts("=== bundle-audit check --update ===")
          @results[:bundler_audit] = system("bundle", "exec", "bundle-audit", "check", "--update") ? :pass : :fail
        else
          @output.puts("bundler-audit not installed — skipping.")
          @results[:bundler_audit] = :skipped
        end
      end

      # Calls the host's script/collate_coverage.rb (shipped by
      # Phase 1.5). Skipped if the script is not present (older host)
      # or no per-engine resultset files exist yet.
      def run_simplecov_collation
        script = "script/collate_coverage.rb"
        unless File.exist?(script)
          @output.puts("script/collate_coverage.rb not present — skipping coverage collation.")
          @results[:coverage] = :skipped
          return
        end

        @output.puts("=== ruby script/collate_coverage.rb ===")
        @results[:coverage] = system("ruby", script) ? :pass : :fail
      end

      def gem_installed?(gem_name)
        Gem::Specification.find_by_name(gem_name)
        true
      rescue Gem::LoadError
        false
      end

      def print_summary
        @output.puts("")
        @output.puts("seams:quality summary")
        @results.each do |gate, status|
          @output.puts("  #{gate.to_s.ljust(15)} #{status}")
        end
      end
    end
  end
end
