# frozen_string_literal: true

require "logger"
require "seams/observability/adapter"

module Seams
  module Observability
    module Adapters
      # Default observability adapter — wraps Rails.logger (or a stdout
      # Logger when Rails isn't booted) and emits messages tagged with
      # the seams namespace plus structured key=value context.
      class RailsLogger < Seams::Observability::Adapter
        def initialize(logger: nil)
          super()
          @logger = logger || default_logger
        end

        %i[debug info warn error].each do |level|
          define_method(level) do |message, **context|
            @logger.public_send(level, format_message(message, context))
          end
        end

        def measure(operation, **context)
          start  = monotonic_ms
          result = yield
          duration = (monotonic_ms - start).round(2)
          info(operation, **context, duration_ms: duration)
          result
        rescue StandardError => e
          duration = (monotonic_ms - start).round(2)
          error(operation, **context, duration_ms: duration, error: "#{e.class}: #{e.message}")
          raise
        end

        private

        def format_message(message, context)
          tags = ["[seams]"]
          tags << "[#{context.delete(:engine)}]" if context[:engine]
          parts = context.map { |k, v| "#{k}=#{v}" }
          ([tags.join(" "), message] + parts).join(" ").strip
        end

        def monotonic_ms
          Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1_000.0
        end

        def default_logger
          if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
            ::Rails.logger
          else
            ::Logger.new($stdout)
          end
        end
      end
    end
  end
end
