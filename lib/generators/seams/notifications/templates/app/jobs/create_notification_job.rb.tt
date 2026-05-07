# frozen_string_literal: true

module Notifications
  # Creates a Notification row and enqueues its send. Subscribers
  # enqueue this job rather than doing the DB write inline — see
  # Seams::Events::Publisher (subscribers run synchronously in the
  # publisher's thread; never block the publisher).
  class CreateNotificationJob < ApplicationJob
    queue_as :notifications

    STRATEGIES = {
      "in_app" => "Notifications::Strategies::InApp",
      "email"  => "Notifications::Strategies::Email",
      "sms"    => "Notifications::Strategies::Sms"
    }.freeze

    def perform(owner_class:, owner_id:, template:, strategy:)
      klass_name = STRATEGIES.fetch(strategy.to_s) do
        raise ArgumentError, "Unknown strategy: #{strategy.inspect}"
      end

      owner = owner_class.constantize.find_by(id: owner_id)
      return unless owner

      notif          = klass_name.constantize.new(owner: owner, template: template)
      notif.schedule = IceCube::Schedule.new(Time.current)
      notif.save!
      notif.send_async
    end
  end
end
