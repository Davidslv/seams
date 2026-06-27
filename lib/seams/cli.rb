# frozen_string_literal: true

require "seams"
require "seams/cli/list"
require "seams/cli/test_changed"
require "seams/cli/quality"
require "seams/cli/resolve"

module Seams
  # Top-level CLI aggregator. Each public method delegates to a
  # single-purpose CLI class so the rake tasks (and bin/seams) have
  # one entry point. Returns true on success, false on failure —
  # callers translate that into a process exit code.
  #
  #   Seams::CLI.list                            # bin/rails seams:list
  #   Seams::CLI.test_changed(base: "main")      # seams:test:changed
  #   Seams::CLI.quality                         # seams:quality:all
  #   Seams::CLI.resolve(mode: :eject, ...)      # bin/seams resolve --eject ...
  module CLI
    module_function

    # List every engine and the events it emits/subscribes to.
    # @param engines_root [String] directory holding the engines.
    # @param output [IO] stream to write the report to.
    # @return [Boolean] true on success.
    def list(engines_root: "engines", output: $stdout)
      Seams::CLI::List.new(engines_root: engines_root, output: output).call
    end

    # Run the specs of every engine changed since +base+.
    # @param base [String] the git ref to diff against.
    # @param engines_root [String] directory holding the engines.
    # @param output [IO] stream to write progress to.
    # @return [Boolean] true if all selected suites pass.
    def test_changed(base: "main", engines_root: "engines", output: $stdout)
      Seams::CLI::TestChanged.new(
        base: base,
        engines_root: engines_root,
        output: output
      ).call
    end

    # Run rubocop across every engine.
    # @param engines_root [String] directory holding the engines.
    # @param output [IO] stream to write progress to.
    # @return [Boolean] true if every engine lints clean.
    def quality(engines_root: "engines", output: $stdout)
      Seams::CLI::Quality.new(engines_root: engines_root, output: output).call
    end

    # Drive the eject / insertion-point escape hatch.
    # @param mode [Symbol] :eject, :list_markers, or :list_ejected.
    # @param argument [String, nil] mode-specific argument (e.g. "<engine>/<file>").
    # @param engines_root [String] directory holding the engines.
    # @param output [IO] stream for normal output.
    # @param error [IO] stream for error output.
    # @return [Boolean] true on success.
    def resolve(mode:, argument: nil, engines_root: "engines", output: $stdout, error: $stderr)
      Seams::CLI::Resolve.new(
        mode: mode,
        argument: argument,
        engines_root: engines_root,
        output: output,
        error: error
      ).call
    end
  end
end
