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
          (send nil? ${:require :require_relative} (str $_))
        PATTERN

        def on_send(node)
          method, path = require_call?(node)
          return unless path

          offending_engine = other_engine_for(method, path)
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

        # For a plain `require`, only the FIRST path segment identifies
        # the library — `require "billing/foo"` loads the sibling engine,
        # but `require "rspec/core/rake_task"` loads rspec-core no matter
        # what its deeper segments are called. Matching ANY segment (the
        # old behaviour) false-fired on every generated host with an
        # engine named `core`, because engine Rakefiles require
        # "rspec/core/rake_task".
        #
        # For `require_relative`, the path is anchored inside the
        # engine's own tree: it only reaches a sibling engine when it
        # first climbs OUT via `../`. Resolve the climb and check the
        # first segment after it — `../../billing/foo` is a genuine
        # cross-engine reach, while `core/something` (no climb) is just
        # a subdirectory of the requiring file.
        def other_engine_for(method, path)
          candidate =
            if method == :require_relative
              first_segment_after_climb(path)
            else
              path.split("/").first
            end

          other_engines.find { |engine| engine == candidate }
        end

        # Returns the first path segment after the leading `../` (or
        # `./`) climb, or nil when the path never leaves the requiring
        # file's own directory.
        def first_segment_after_climb(path)
          segments = path.split("/")
          climbed  = segments.take_while { |segment| [".", ".."].include?(segment) }
          return nil unless climbed.include?("..")

          segments.drop(climbed.size).first
        end

        def capitalize(name)
          name.split(/[_-]/).map(&:capitalize).join
        end
      end
    end
  end
end
