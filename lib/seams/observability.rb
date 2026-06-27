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
    # Base class for observability errors.
    class Error < Seams::Error; end

    class << self
      # The configured observability adapter, instantiated lazily.
      # @return [Seams::Observability::Adapter] the adapter instance.
      # @raise [Seams::ConfigurationError] if the configured class can't be loaded.
      def adapter
        @adapter ||= build_adapter
      end

      # Drop the memoized adapter so the next call rebuilds it. Test hook.
      # @return [void]
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
