# frozen_string_literal: true

require "notifications/version"
require "notifications/configuration"
require "notifications/type_registry"
require "notifications/engine"
require "notifications/concerns/notifiable"
require "notifications/adapters/abstract"
require "notifications/adapters/action_mailer"
require "notifications/adapters/null_sms"

module Notifications
  class Error          < StandardError; end
  class AdapterError   < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    # Seed the TypeRegistry with the default cross-engine notification
    # types other engines emit (auth.signed_up, billing.invoice_paid,
    # etc). Hosts call this from their initializer; subsequent
    # +TypeRegistry.register+ calls override the defaults or extend the
    # set with host-specific types.
    def seed_default_types!
      TypeRegistry.register("welcome",
                            template: "welcome",
                            channels: %i[in_app email],
                            display:  "Welcome")
      TypeRegistry.register("billing.invoice_paid",
                            template: "billing/invoice_paid",
                            channels: %i[in_app email],
                            display:  "Invoice paid")
      TypeRegistry.register("billing.invoice_failed",
                            template: "billing/invoice_failed",
                            channels: %i[in_app email],
                            display:  "Invoice payment failed")
      TypeRegistry.register("billing.subscription_started",
                            template: "billing/subscription_started",
                            channels: %i[in_app email],
                            display:  "Subscription started")
      TypeRegistry.register("billing.subscription_canceled",
                            template: "billing/subscription_canceled",
                            channels: %i[in_app email],
                            display:  "Subscription canceled")
      TypeRegistry.register("billing.lifetime_purchased",
                            template: "billing/lifetime_purchased",
                            channels: %i[in_app email],
                            display:  "Lifetime access purchased")
    end

    def email_adapter
      configuration.email_adapter.constantize.new
    rescue NameError => e
      raise Notifications::AdapterError,
            "Notifications.configuration.email_adapter is set to " \
            "#{configuration.email_adapter.inspect}, which could not be resolved: #{e.message}"
    end

    def sms_adapter
      configuration.sms_adapter.constantize.new
    rescue NameError => e
      raise Notifications::AdapterError,
            "Notifications.configuration.sms_adapter is set to " \
            "#{configuration.sms_adapter.inspect}, which could not be resolved: #{e.message}"
    end
  end
end
