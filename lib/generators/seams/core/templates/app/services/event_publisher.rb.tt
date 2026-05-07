# frozen_string_literal: true

module Core
  # Thin convenience wrapper around Seams::Events::Publisher. Adds
  # the request id, actor id, and team id from Core::Current to every
  # payload so subscribers don't have to thread that context through
  # by hand.
  #
  #   Core::EventPublisher.publish("subscription.created.billing", id: 42)
  module EventPublisher
    module_function

    def publish(event_name, payload = {})
      enriched = payload.merge(
        actor_id:   Core::Current.user&.id,
        team_id:    Core::Current.team&.id,
        request_id: Core::Current.request_id
      ).compact

      Seams::Events::Publisher.publish(event_name, enriched)
    end
  end
end
