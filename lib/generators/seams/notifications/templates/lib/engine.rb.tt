# frozen_string_literal: true

module Notifications
  class Engine < ::Rails::Engine
    isolate_namespace Notifications

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "notifications.register_events" do
      Seams::EventRegistry.register("notification.queued.notifications",     emitted_by: "Notifications")
      Seams::EventRegistry.register("notification.delivered.notifications",  emitted_by: "Notifications")
      Seams::EventRegistry.register("notification.failed.notifications",     emitted_by: "Notifications")
    end

    initializer "notifications.append_migrations" do |app|
      unless app.root == root
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    config.after_initialize do
      require "notifications/concerns/notifiable"
      Notifications::AuthSubscriber.attach!
      Notifications::BillingSubscriber.attach! if defined?(Billing::Engine)
    end
  end
end
