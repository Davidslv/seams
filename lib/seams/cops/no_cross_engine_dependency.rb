# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Seams
      # Flags `require`/`require_relative` calls that pull source files
      # out of another engine. Engines should depend on each other only
      # through public events (Seams::Events::Publisher) and
      # explicitly-exposed concerns — not by requiring private files.
      class NoCrossEngineDependency < Base
        MSG = "Engine `%<own>s` must not require `%<path>s` from another engine. " \
              "Communicate via events or via `%<other>s`'s exposed concerns."

        # @!method require_call?(node)
        def_node_matcher :require_call?, <<~PATTERN
          (send nil? {:require :require_relative} (str $_))
        PATTERN

        def on_send(node)
          path = require_call?(node)
          return unless path

          offending_engine = other_engine_for(path)
          return unless offending_engine

          add_offense(
            node,
            message: format(MSG, own: own_engine, path: path,
                                 other: capitalize(offending_engine))
          )
        end

        private

        def own_engine
          cop_config["OwnEngine"].to_s
        end

        def other_engines
          Array(cop_config["OtherEngines"]).map(&:to_s)
        end

        def other_engine_for(path)
          # Match either "billing/foo" or "../../billing/foo" — the engine
          # name is whichever directory segment matches another engine.
          segments = path.split("/")
          other_engines.find { |engine| segments.include?(engine) }
        end

        def capitalize(name)
          name.split(/[_-]/).map(&:capitalize).join
        end
      end
    end
  end
end
