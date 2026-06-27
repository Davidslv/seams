# frozen_string_literal: true

require "seams/events"

module Seams
  module Events
    # Abstract base class for event-bus adapters. Real adapters wrap a
    # transport (ActiveSupport::Notifications, an external queue, etc.) and
    # implement the three primitives below.
    class Adapter
      # Deliver an event (a name plus a Hash payload) to the transport.
      # @return [void]
      # @raise [NotImplementedError] unless a subclass overrides it.
      def publish(_event_name, _payload)
        raise NotImplementedError, "#{self.class} must implement #publish"
      end

      # Register a block to run when the named event is published.
      # @return [Object] a transport-specific subscriber handle.
      # @raise [NotImplementedError] unless a subclass overrides it.
      def subscribe(_event_name, &)
        raise NotImplementedError, "#{self.class} must implement #subscribe"
      end

      # Detach a previously-registered subscriber (the handle {#subscribe} returned).
      # @return [void]
      # @raise [NotImplementedError] unless a subclass overrides it.
      def unsubscribe(_subscriber)
        raise NotImplementedError, "#{self.class} must implement #unsubscribe"
      end
    end
  end
end
