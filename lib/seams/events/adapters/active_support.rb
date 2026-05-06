# frozen_string_literal: true

require "active_support"
require "active_support/isolated_execution_state"
require "active_support/notifications"
require "seams/events/adapter"

module Seams
  module Events
    module Adapters
      # Default in-process adapter, backed by ActiveSupport::Notifications.
      # Suitable for monolithic deployments — every engine in the host app
      # shares the same process, so subscribers fire synchronously after
      # the publisher's call returns.
      class ActiveSupport < Seams::Events::Adapter
        def publish(event_name, payload)
          payload = { payload: payload } unless payload.is_a?(Hash)
          ::ActiveSupport::Notifications.instrument(event_name, payload)
        end

        def subscribe(event_name, &)
          ::ActiveSupport::Notifications.subscribe(event_name, &)
        end

        def unsubscribe(subscriber)
          ::ActiveSupport::Notifications.unsubscribe(subscriber)
        end
      end
    end
  end
end
