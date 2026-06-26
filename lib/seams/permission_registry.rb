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
