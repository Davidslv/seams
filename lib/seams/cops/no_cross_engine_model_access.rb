# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Seams
      # Flags references to another engine's models from inside an
      # engine. Engines should communicate via events or via
      # explicitly-exposed concerns — never by reaching into another
      # engine's data layer.
      #
      # Configured per-engine via the `OwnEngine` and `OtherEngines`
      # options inside the engine's own .rubocop.yml. A registered
      # concern (e.g. `Billing::Billable`) is exempt — only constants
      # under the suspected ::Models namespace, or ones that look like
      # ActiveRecord classes by convention, are flagged.
      class NoCrossEngineModelAccess < Base
        MSG = "Engine `%<own>s` must not access `%<const>s` directly. " \
              "Use an event or a %<other>s-exposed concern instead."

        def on_const(node)
          return unless other_engines.any?
          return if node.parent&.const_type? # only flag the outermost const ref

          full_name = node.const_name.to_s
          parts     = full_name.split("::")
          return if parts.size < 2 # bare top-level constants are not "model access"

          top_level = parts.first
          return unless other_engines.include?(top_level)
          return if exposed_concern?(full_name)

          add_offense(
            node,
            message: format(MSG, own: own_engine, const: full_name, other: top_level)
          )
        end

        private

        def own_engine
          cop_config["OwnEngine"].to_s
        end

        def other_engines
          Array(cop_config["OtherEngines"]).map(&:to_s)
        end

        # A concern is a Ruby module that an engine intentionally exposes
        # for other engines to `include`. By convention, concerns live at
        # the top level of the engine namespace and are documented in the
        # engine's README.
        def exposed_concern?(full_name)
          parts = full_name.split("::")
          return false unless parts.size == 2

          # Heuristic: a single-segment "leaf" under the engine's
          # namespace (e.g. Billing::Billable) is treated as a concern.
          # Models live under deeper paths (Billing::Subscription is
          # still flagged because it does not match a configured
          # concern). A future iteration may make this configurable via
          # an `ExposedConcerns` allowlist.
          allowlist = Array(cop_config["ExposedConcerns"]).map(&:to_s)
          allowlist.include?(full_name)
        end
      end
    end
  end
end
