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
        # Publish a domain event to every subscriber.
        #
        # @param event_name [String, Symbol] the event name, in
        #   +resource.action.engine+ form (e.g. "subscription.created.billing").
        # @param payload [Hash] data handed to each subscriber block.
        # @raise [Seams::Events::InvalidEventNameError] if the name is malformed.
        # @raise [Seams::Events::UnregisteredEventError] if no engine has
        #   registered the event via {Seams::EventRegistry.register}.
        # @return [void]
        # @example
        #   Seams::Events::Publisher.publish("invoice.paid.billing", invoice_id: 42)
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

        # Subscribe a block to an event. Subscribers run **synchronously**
        # in the publisher's thread — enqueue a background job for any
        # network side effect rather than performing it inline. For a
        # reload-safe, idempotent subscription prefer {attach_class}.
        #
        # @param event_name [String, Symbol] the event to listen for.
        # @yieldparam payload [Hash] the published payload.
        # @return [Object] an adapter-specific subscriber handle.
        # @example
        #   Seams::Events::Publisher.subscribe("identity.signed_up.auth") do |payload|
        #     WelcomeJob.perform_later(payload[:identity_id])
        #   end
        def subscribe(event_name, &)
          Events.assert_valid_name!(event_name)
          name = event_name.to_s
          subscriptions << name unless subscriptions.include?(name)

          adapter.subscribe(name) do |*args|
            yield(args.last)
          end
        end

        # Idempotent variant of #subscribe. The first call attaches and
        # remembers the (key, event_name) pair on Seams::Events::Publisher
        # itself — a Rails autoreload that re-evaluates the subscriber
        # class file does NOT lose this state, because Publisher is in
        # the gem and isn't reloaded. Subsequent calls with the same
        # (key, event_name) are no-ops, preventing the "welcome email
        # fires N times after N reloads" bug.
        #
        # Synchronized so concurrent boot threads (e.g. Puma cluster
        # pre-fork) can't race-attach the same subscriber twice.
        #
        # CAVEAT — Rails autoreload staleness:
        # The block passed here closes over its lexical binding, which
        # in practice means the subscriber CLASS object as it existed
        # when +attach!+ first ran. After Rails reloads the subscriber
        # file, the constant points at a fresh class object, but THIS
        # block still calls into the old one — so edits to the
        # subscriber's methods are invisible until a full server
        # restart. For new code, prefer #attach_class which re-resolves
        # the constant on every dispatch and so is reload-safe.
        #
        # Use a per-subscriber-class symbol as the key:
        #
        #   Publisher.attach_once(:notifications_auth_subscriber,
        #     "identity.signed_up.auth") { |payload| ... }
        def attach_once(key, event_name, &)
          attach_once_mutex.synchronize do
            attached_keys[[key, event_name.to_s]] ||= subscribe(event_name, &)
          end
        end

        # Reload-safe alternative to #attach_once. Stores the subscriber
        # class as a STRING name and re-resolves +Object.const_get+ on
        # every dispatch — so when Rails autoreload swaps the constant
        # for a freshly-loaded class object, the next event reaches the
        # new code without a server restart.
        #
        # The +class_name+ MUST be a String (e.g. "Notifications::AuthSubscriber").
        # Passing the class object itself defeats the fix: it captures a
        # reference to the pre-reload object and exhibits exactly the
        # staleness bug this method exists to avoid.
        #
        # The named class method is invoked via +send+, so it may be
        # +private+ — keeping subscribers' handlers out of their public
        # surface. Idempotent on (key, event_name) like #attach_once.
        #
        # Example:
        #
        #   Publisher.attach_class(
        #     :notifications_auth_subscriber,
        #     "identity.signed_up.auth",
        #     class_name:  "Notifications::AuthSubscriber",
        #     method_name: :handle_signed_up
        #   )
        def attach_class(key, event_name, class_name:, method_name:)
          unless class_name.is_a?(String)
            raise ArgumentError,
                  "attach_class requires class_name as a String (got #{class_name.class}). " \
                  "Passing the class object captures a stale reference across Rails reloads — " \
                  "the very bug this method exists to prevent."
          end

          method_symbol = method_name.to_sym

          attach_once_mutex.synchronize do
            attached_keys[[key, event_name.to_s]] ||= subscribe(event_name) do |payload|
              Object.const_get(class_name).send(method_symbol, payload)
            end
          end
        end

        # Detach a subscriber handle from the adapter.
        # @param subscriber [Object] the handle a subscribe call returned.
        # @return [void]
        def unsubscribe(subscriber)
          adapter.unsubscribe(subscriber)
        end

        # Internal — exposed for spec teardown only.
        def attached_keys
          @attached_keys ||= {}
        end

        def attach_once_mutex
          @attach_once_mutex ||= Mutex.new
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
        # typos like subscribing to "identity.signed_up.atuh".
        def orphan_subscriptions
          subscriptions.reject { |name| EventRegistry.registered?(name) }.uniq
        end

        # The configured event-bus adapter, instantiated lazily.
        # @return [Seams::Events::Adapter] the adapter instance.
        # @raise [Seams::ConfigurationError] if the configured class can't be loaded.
        def adapter
          @adapter ||= build_adapter
        end

        # Tears down everything Publisher has registered with the
        # adapter and clears the bookkeeping. Without the unsubscribe
        # step, ActiveSupport::Notifications keeps the prior process's
        # subscribers alive in its global registry — so test runs that
        # call +reset!+ between examples accumulate stale subscribers
        # that fire (and may raise on now-gone constants) on every
        # publish in the next example.
        def reset!
          @attached_keys&.each_value do |subscriber|
            adapter.unsubscribe(subscriber) if subscriber
          end
          @adapter       = nil
          @subscriptions = nil
          @attached_keys = nil
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
