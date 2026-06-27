# frozen_string_literal: true

require "seams/permissions"

module Seams
  # Tracks every ability code that an engine has declared it understands,
  # along with the engine that owns it. Acts as the single source of truth
  # for authorisation lookups and prevents two engines from claiming the
  # same ability code.
  module PermissionRegistry
    @registry = {}
    @mutex    = Mutex.new

    class << self
      # Declare that an engine understands an ability code. Call this from
      # the engine that owns the ability so authorisation lookups have a
      # single source of truth.
      #
      # @param ability [String, Symbol] the ability code (e.g. "billing.manage").
      # @param owned_by [String] the owning engine (e.g. "Billing").
      # @raise [Seams::Permissions::DuplicateAbilityError] if another engine owns it.
      # @return [String] the owning engine name.
      # @example
      #   Seams::PermissionRegistry.register("billing.manage", owned_by: "Billing")
      def register(ability, owned_by:)
        Permissions.assert_valid_name!(ability)
        ability = ability.to_s

        @mutex.synchronize do
          existing = @registry[ability]

          if existing && existing != owned_by
            raise Permissions::DuplicateAbilityError,
                  "Ability #{ability.inspect} already registered by #{existing.inspect}; " \
                  "cannot also be registered by #{owned_by.inspect}"
          end

          @registry[ability] = owned_by
        end
      end

      def registered?(ability)
        @registry.key?(ability.to_s)
      end

      def owner_of(ability)
        @registry[ability.to_s]
      end

      def all
        @registry.dup
      end

      def reset!
        @mutex.synchronize { @registry.clear }
      end
    end
  end
end
