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
      # The exception is documented in `doc/reference/CURRENT_ATTRIBUTES.md`.
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

        ASSOCIATION_MACROS = %i[
          belongs_to
          has_one
          has_many
          has_and_belongs_to_many
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

        # Association macros name the target class via a `class_name:`
        # STRING (`belongs_to :account, class_name: "Accounts::Account"`),
        # which `on_const` cannot see — string literals are not constant
        # nodes, so this exact pattern used to sail through the cop.
        # Flag the option when the named class lives in another engine.
        #
        # `class_name:` given as a constant is already caught by
        # `on_const`, so only string values are flagged here (no double
        # offense). `polymorphic: true` associations are exempt: the
        # target class is decided at runtime by the owning record.
        def on_send(node)
          pair = string_class_name_pair(node)
          return unless pair

          full_name = pair.value.value.to_s.delete_prefix("::")
          return unless cross_engine_class_name?(full_name)

          assert_own_engine_configured!

          add_offense(
            pair,
            message: format(MSG, own: own_engine, const: full_name,
                                 other: full_name.split("::").first)
          )
        end

        private

        # Returns the `class_name: "..."` pair of an association macro
        # when its value is a string literal worth checking; nil
        # otherwise (not an association, no options, polymorphic, or a
        # constant value already covered by `on_const`).
        def string_class_name_pair(node)
          options = association_options(node)
          return nil unless options
          return nil if polymorphic_option?(options)

          pair = class_name_pair(options)
          return nil unless pair

          pair.value.str_type? ? pair : nil
        end

        def association_options(node)
          return nil unless association_macro?(node)

          options = node.last_argument
          options if options&.hash_type?
        end

        def association_macro?(node)
          node.receiver.nil? && ASSOCIATION_MACROS.include?(node.method_name)
        end

        def polymorphic_option?(options)
          options.pairs.any? do |pair|
            pair.key.sym_type? && pair.key.value == :polymorphic && pair.value.true_type?
          end
        end

        def class_name_pair(options)
          options.pairs.find { |pair| pair.key.sym_type? && pair.key.value == :class_name }
        end

        def cross_engine_class_name?(full_name)
          parts = full_name.split("::")
          return false if parts.size < 2
          return false unless other_engines.include?(parts.first)
          return false if exposed_concern?(full_name)

          true
        end

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
