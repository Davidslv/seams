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
    #
    # Subscribers run **synchronously** in the publisher's thread (the
    # default ActiveSupport::Notifications adapter has no other mode).
    # They should therefore enqueue background jobs for any side effect
    # that talks to the network or could fail — never perform the side
    # effect inline. Seams does not enforce this; treat it as a
    # convention that the boundary review catches.
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
          name = event_name.to_s
          subscriptions << name

          adapter.subscribe(name) do |*args|
            yield(args.last)
          end
        end

        def unsubscribe(subscriber)
          adapter.unsubscribe(subscriber)
        end

        # Returns the list of event names that engines have subscribed
        # to during this process's lifetime. Useful for reporting and
        # for the post-boot validation hook below.
        def subscriptions
          @subscriptions ||= []
        end

        # Walks every subscription and returns the names that no engine
        # has registered as an emitted event. Hosts can call this from
        # an after_initialize block (or in a CI smoke test) to catch
        # typos like subscribing to "user.signed_up.atuh".
        def orphan_subscriptions
          subscriptions.reject { |name| EventRegistry.registered?(name) }.uniq
        end

        def adapter
          @adapter ||= build_adapter
        end

        def reset!
          @adapter       = nil
          @subscriptions = nil
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
