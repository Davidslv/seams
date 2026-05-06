# frozen_string_literal: true

require "seams/observability"

module Seams
  module Observability
    # Abstract base class for observability adapters. Concrete adapters
    # bridge to the host application's logger / APM (Rails.logger,
    # Datadog, OpenTelemetry, etc.) — engines never speak to those
    # libraries directly.
    class Adapter
      def debug(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #debug"
      end

      def info(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #info"
      end

      def warn(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #warn"
      end

      def error(_message, **_context)
        raise NotImplementedError, "#{self.class} must implement #error"
      end

      def measure(_operation, **_context, &)
        raise NotImplementedError, "#{self.class} must implement #measure"
      end
    end
  end
end
