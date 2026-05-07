# frozen_string_literal: true

module Notifications
  # Registry of typed notification semantics — distinct from the STI
  # strategy classes (InApp / Email / Sms), which are *delivery
  # channels*, not *what the notification is about*.
  #
  # A NotificationType pairs a stable name (e.g. "billing.invoice_paid")
  # with a template path, the channels it can fan out to, and a human
  # display name. Hosts register types up front in an initializer so
  # the host has a closed-set list to power preference UIs and audit
  # queries.
  #
  #   # config/initializers/notifications.rb
  #   Notifications::TypeRegistry.register("billing.invoice_paid",
  #                                        template: "billing/invoice_paid",
  #                                        channels: %i[in_app email],
  #                                        display: "Invoice paid")
  #
  #   user.notify_typed(type: "billing.invoice_paid")
  #
  # The engine seeds a small default set on boot (see
  # +Notifications.seed_default_types!+); hosts override or extend
  # in their initializer.
  module TypeRegistry
    Type = Struct.new(:name, :template, :channels, :display, keyword_init: true) do
      def supports_channel?(channel)
        channels.map(&:to_sym).include?(channel.to_sym)
      end

      def to_s
        name
      end
    end

    UnknownType = Class.new(StandardError)

    @types = {}
    @mutex = Mutex.new

    module_function

    def register(name, template:, channels:, display: nil)
      @mutex.synchronize do
        @types[name.to_s] = Type.new(
          name:     name.to_s,
          template: template.to_s,
          channels: Array(channels).map(&:to_sym),
          display:  display || name.to_s.tr("._", " ").capitalize
        )
      end
    end

    def find(name)
      @types[name.to_s]
    end

    def fetch(name)
      find(name) || raise(UnknownType, "no notification type registered as #{name.inspect}")
    end

    def all
      @types.values
    end

    def names
      @types.keys
    end

    def reset!
      @mutex.synchronize { @types = {} }
    end
  end
end
