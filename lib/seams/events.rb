# frozen_string_literal: true

module Seams
  # Events module — public API for inter-engine communication.
  #
  # Engines publish domain events through Seams::Events::Publisher and
  # subscribe to events from other engines via the same module. Subscribers
  # are expected to enqueue background jobs rather than perform side
  # effects synchronously, so that the publisher's transaction can commit
  # quickly and side effects can retry independently.
  module Events
    class Error < Seams::Error; end

    # Raised when an event name is published that no engine has registered.
    class UnregisteredEventError < Error; end

    # Raised when two engines try to register the same event name.
    class DuplicateEventError < Error; end

    # Raised when an event name doesn't follow the resource.action.engine
    # convention (e.g., "subscription.created.billing").
    class InvalidEventNameError < Error; end

    # Three dot-separated segments, lowercase, snake_case allowed.
    NAME_PATTERN = /\A[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\z/

    def self.valid_name?(name)
      NAME_PATTERN.match?(name.to_s)
    end

    def self.assert_valid_name!(name)
      return if valid_name?(name)

      raise InvalidEventNameError,
            "Event name #{name.inspect} must follow resource.action.engine " \
            "(e.g. subscription.created.billing)"
    end
  end
end
