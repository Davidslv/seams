# frozen_string_literal: true

require "seams/events"
require "seams/event_registry"

module Seams
  module Events
    # Public API for publishing and subscribing to inter-engine events.
    #
    # Engines should always go through this module rather than calling the
    # underlying adapter directly — it enforces the naming convention,
    # checks the EventRegistry, and gives subscribers a simple
    # block-takes-payload interface regardless of which adapter is in use.
    module Publisher
      class << self
        def publish(event_name, payload = {})
          Events.assert_valid_name!(event_name)
          name = event_name.to_s

          unless EventRegistry.registered?(name)
            raise UnregisteredEventError,
                  "Event #{name.inspect} has not been registered. " \
                  "Declare it in the engine that emits it via " \
                  "Seams::EventRegistry.register(#{name.inspect}, emitted_by: '<EngineName>')."
          end

          adapter.publish(name, payload)
        end

        def subscribe(event_name, &)
          Events.assert_valid_name!(event_name)
          adapter.subscribe(event_name.to_s) do |*args|
            payload = args.last
            yield(payload)
          end
        end

        def unsubscribe(subscriber)
          adapter.unsubscribe(subscriber)
        end

        def adapter
          @adapter ||= build_adapter
        end

        def reset!
          @adapter = nil
        end

        private

        def build_adapter
          klass_name = Seams.configuration.event_bus_adapter
          Object.const_get(klass_name).new
        rescue NameError => e
          raise Seams::ConfigurationError,
                "Event bus adapter #{klass_name.inspect} could not be loaded: #{e.message}"
        end
      end
    end
  end
end
