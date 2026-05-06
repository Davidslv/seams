# frozen_string_literal: true

require "seams/events"

module Seams
  module Events
    # Abstract base class for event-bus adapters. Real adapters wrap a
    # transport (ActiveSupport::Notifications, an external queue, etc.) and
    # implement the three primitives below.
    class Adapter
      def publish(_event_name, _payload)
        raise NotImplementedError, "#{self.class} must implement #publish"
      end

      def subscribe(_event_name, &)
        raise NotImplementedError, "#{self.class} must implement #subscribe"
      end

      def unsubscribe(_subscriber)
        raise NotImplementedError, "#{self.class} must implement #unsubscribe"
      end
    end
  end
end
