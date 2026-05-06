# frozen_string_literal: true

module Seams
  # Observability module — structured logging and timing primitives that
  # every engine should use instead of calling Rails.logger directly.
  #
  # Engines call Seams::Observability.adapter.info / .warn / .error /
  # .measure with structured context (engine name, actor id, etc.) so that
  # logs can be parsed and filtered uniformly by the host application's
  # log aggregator.
  module Observability
    class Error < Seams::Error; end

    class << self
      def adapter
        @adapter ||= build_adapter
      end

      def reset!
        @adapter = nil
      end

      private

      def build_adapter
        klass_name = Seams.configuration.observability_adapter
        Object.const_get(klass_name).new
      rescue NameError => e
        raise Seams::ConfigurationError,
              "Observability adapter #{klass_name.inspect} could not be loaded: #{e.message}"
      end
    end
  end
end
