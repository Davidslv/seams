# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Seams
      # Flags references to another engine's data classes from inside an
      # engine. Engines should communicate via events or via
      # explicitly-exposed concerns — never by reaching into another
      # engine's data layer.
      #
      # Configured per-engine via the `OwnEngine`, `OtherEngines`, and
      # `ExposedConcerns` options inside the engine's own .rubocop.yml.
      #
      # The cop deliberately ignores Rails framework constants that
      # every engine exposes (`Engine`, `VERSION`, `ApplicationController`,
      # `ApplicationRecord`, `ApplicationJob`, `ApplicationMailer`) and
      # any class whose name ends in one of the configured suffixes
      # (`Controller`, `Job`, `Mailer`, `Helper`, `Component`, `Engine`).
      # Concerns (`Billing::Billable`, `Billing::Concerns::Billable`)
      # are exempt when listed in `ExposedConcerns`.
      #
      # `<Engine>::Current` is also exempt by design: every engine ships
      # its own `ActiveSupport::CurrentAttributes` namespace
      # (`Auth::Current`, `Accounts::Current`, `Teams::Current`, etc.)
      # and these per-request state holders are intentionally readable
      # from anywhere in the host. Treating them as boundary-violations
      # would force every cross-engine read of per-request identity /
      # account / team to go through a host-defined shim, which defeats
      # the purpose of `CurrentAttributes` as a shared per-request bus.
      # The exception is documented in `doc/CURRENT_ATTRIBUTES.md`.
      class NoCrossEngineModelAccess < Base
        MSG = "Engine `%<own>s` must not access `%<const>s` directly. " \
              "Use an event or a %<other>s-exposed concern instead."

        DEFAULT_IGNORED_LEAF_NAMES = %w[
          Engine
          VERSION
          ApplicationController
          ApplicationRecord
          ApplicationJob
          ApplicationMailer
          ApplicationHelper
          ApplicationCable
          Routes
          Current
        ].freeze

        DEFAULT_IGNORED_LEAF_SUFFIXES = %w[
          Controller
          Job
          Mailer
          Helper
          Component
          Channel
          Engine
        ].freeze

        def on_const(node)
          return unless flaggable?(node)

          full_name = node.const_name.to_s
          top_level = full_name.split("::").first

          assert_own_engine_configured!

          add_offense(
            node,
            message: format(MSG, own: own_engine, const: full_name, other: top_level)
          )
        end

        private

        def flaggable?(node)
          parts = const_parts_under_other_engine(node)
          return false unless parts

          full_name = parts.join("::")
          return false if exposed_concern?(full_name)
          return false if framework_constant?(parts)
          return false if ignored_suffix?(parts.last)
          return false if inside_defined_check?(node)

          true
        end

        # `defined?(Teams::Team)` is a soft existence check — the
        # constant is not actually accessed for value, just probed for
        # presence. Skip the cop in that case so guards like
        # `Teams::Team if defined?(Teams::Team)` don't false-fire.
        # Walks parents up to a few levels so `defined?(Teams::Team.foo)`
        # (where the const's parent is a `send` node, not the `defined?`)
        # is also exempted.
        def inside_defined_check?(node)
          ancestor = node.parent
          5.times do
            return false unless ancestor
            return true  if ancestor.defined_type?

            ancestor = ancestor.parent
          end
          false
        end

        # Returns the segments of the constant if `node` is the
        # outermost reference to a multi-segment constant whose first
        # segment is a sibling engine. Returns nil otherwise.
        def const_parts_under_other_engine(node)
          return nil if other_engines.empty?
          return nil if node.parent&.const_type?

          parts = node.const_name.to_s.split("::")
          return nil if parts.size < 2
          return nil unless other_engines.include?(parts.first)

          parts
        end

        def own_engine
          name = cop_config["OwnEngine"]
          name&.to_s
        end

        def assert_own_engine_configured!
          return if own_engine && !own_engine.empty?

          raise RuboCop::Error,
                "Seams/NoCrossEngineModelAccess requires `OwnEngine` to be set in " \
                ".rubocop.yml so it knows which engine the file under inspection belongs to."
        end

        def other_engines
          Array(cop_config["OtherEngines"]).map(&:to_s)
        end

        def exposed_concern?(full_name)
          allowlist = Array(cop_config["ExposedConcerns"]).map(&:to_s)
          allowlist.include?(full_name)
        end

        def framework_constant?(parts)
          DEFAULT_IGNORED_LEAF_NAMES.include?(parts.last)
        end

        def ignored_suffix?(leaf_name)
          DEFAULT_IGNORED_LEAF_SUFFIXES.any? { |suffix| leaf_name.end_with?(suffix) }
        end
      end
    end
  end
end
