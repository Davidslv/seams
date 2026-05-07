# frozen_string_literal: true

require "seams"
require "seams/cli/list"
require "seams/cli/test_changed"
require "seams/cli/quality"

module Seams
  # Top-level CLI aggregator. Each public method delegates to a
  # single-purpose CLI class so the rake tasks (and bin/seams) have
  # one entry point. Returns true on success, false on failure —
  # callers translate that into a process exit code.
  #
  #   Seams::CLI.list                            # bin/rails seams:list
  #   Seams::CLI.test_changed(base: "main")      # seams:test:changed
  #   Seams::CLI.quality                         # seams:quality:all
  module CLI
    module_function

    def list(engines_root: "engines", output: $stdout)
      Seams::CLI::List.new(engines_root: engines_root, output: output).call
    end

    def test_changed(base: "main", engines_root: "engines", output: $stdout)
      Seams::CLI::TestChanged.new(
        base: base,
        engines_root: engines_root,
        output: output
      ).call
    end

    def quality(engines_root: "engines", output: $stdout)
      Seams::CLI::Quality.new(engines_root: engines_root, output: output).call
    end
  end
end
