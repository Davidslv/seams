# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Seams
      # Ensures every `queue_as` call uses a queue name that has been
      # registered in the host application's `.rubocop.yml`. Catches typos
      # and prevents jobs from being silently routed to a queue that no
      # worker is listening on.
      class KnownQueueNames < Base
        MSG = "Queue `%<name>s` is not registered. Add it to .rubocop.yml " \
              "under Seams/KnownQueueNames#KnownQueues, or pick one of: %<known>s."

        # @!method queue_as_literal?(node)
        def_node_matcher :queue_as_literal?, <<~PATTERN
          (send nil? :queue_as ${sym str})
        PATTERN

        def on_send(node)
          literal = queue_as_literal?(node)
          return unless literal

          name = literal.value.to_s
          return if known_queues.include?(name)

          add_offense(
            node,
            message: format(MSG, name: name, known: known_queues.join(", "))
          )
        end

        private

        def known_queues
          Array(cop_config["KnownQueues"]).map(&:to_s)
        end
      end
    end
  end
end
