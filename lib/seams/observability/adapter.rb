# frozen_string_literal: true

require "seams/observability"

module Seams
  module Observability
    # Abstract base class for observability adapters. Concrete adapters
    # bridge to the host application's logger / APM (Rails.logger,
    # Datadog, OpenTelemetry, etc.) — engines never speak to those
    # libraries directly.
    class Adapter
      # Log a debug-level message with structured context.
      # @param _message [String] the log message.
      # @param _context [Hash] structured key/value context (engine, actor id, ...).
      # @return [void]
      # @raise [NotImplementedError] unless a subclass overrides it.
      def debug(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #debug"
      end

      # Log an info-level message with structured context.
      # @param (see #debug)
      # @return [void]
      # @raise [NotImplementedError] unless a subclass overrides it.
      def info(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #info"
      end

      # Log a warn-level message with structured context.
      # @param (see #debug)
      # @return [void]
      # @raise [NotImplementedError] unless a subclass overrides it.
      def warn(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #warn"
      end

      # Log an error-level message with structured context.
      # @param (see #debug)
      # @return [void]
      # @raise [NotImplementedError] unless a subclass overrides it.
      def error(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #error"
      end

      # Time the given block and emit the duration as structured context.
      # @param _operation [String] a label for the timed operation.
      # @param _context [Hash] structured key/value context.
      # @return [Object] whatever the block returns.
      # @raise [NotImplementedError] unless a subclass overrides it.
      def measure(_operation, **_context, &)
        raise NotImplementedError, "#{self.class} must implement #measure"
      end
    end
  end
end
