# frozen_string_literal: true

module Notifications
  # Engine-scoped configuration. Override in
  # config/initializers/notifications.rb of the host application:
  #
  #   Notifications.configure do |c|
  #     c.email_adapter = "Notifications::Adapters::Mailgun"
  #     c.sms_adapter   = "Notifications::Adapters::Twilio"
  #   end
  class Configuration
    attr_accessor :email_adapter, :sms_adapter, :default_from

    def initialize
      @email_adapter = "Notifications::Adapters::ActionMailer"
      @sms_adapter   = "Notifications::Adapters::NullSms"
      @default_from  = "no-reply@example.com"
    end
  end
end
