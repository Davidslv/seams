# frozen_string_literal: true

module Notifications
  # Consumes Billing events and enqueues a Notifications::CreateNotificationJob
  # (which creates the InApp Notification out-of-band — never inline,
  # see Seams::Events::Publisher docstring).
  #
  # Every subscribed event publishes the same canonical payload shape:
  #   { gateway:, livemode:, customer_ref:, ref:, object_id:, object: }
  #
  # `customer_ref` is the gateway-side customer id (e.g. cus_xxx). The
  # host User is resolved via `stripe_customer_id` — the column
  # `Billing::Billable` documents on the host's User model.
  #
  # +.attach!+ is idempotent across Rails autoreload via
  # +Seams::Events::Publisher.attach_class+ — each event registers its
  # subscriber by class NAME (a String), so dispatch re-resolves the
  # constant on every call. Edits to a +handle_*+ method take effect
  # without a server restart.
  class BillingSubscriber
    SUBSCRIBER_KEY = :notifications_billing_subscriber
    SUBSCRIBER_CLASS_NAME = "Notifications::BillingSubscriber"
    HOST_USER_CLASS_NAME = "User"

    # (event_name => [handler_method, template]). Handler methods are
    # one-line wrappers around #enqueue — kept separate (rather than a
    # single block-capturing handler) so each registration goes through
    # +attach_class+ and survives Rails autoreload.
    EVENT_HANDLERS = {
      "subscription.created.billing"  => [:handle_subscription_created,  "billing/subscription_started"],
      "subscription.updated.billing"  => [:handle_subscription_updated,  "billing/subscription_updated"],
      "subscription.canceled.billing" => [:handle_subscription_canceled, "billing/subscription_canceled"],
      "invoice.paid.billing"          => [:handle_invoice_paid,          "billing/invoice_paid"],
      "invoice.failed.billing"        => [:handle_invoice_failed,        "billing/invoice_failed"],
      # Lifetime Deal events (issue #2 section 3A.LTD)
      "lifetime.granted.billing"      => [:handle_lifetime_granted,      "billing/lifetime_granted"],
      "lifetime.purchased.billing"    => [:handle_lifetime_purchased,    "billing/lifetime_purchased"]
    }.freeze

    class << self
      def attach!
        EVENT_HANDLERS.each do |event, (method_name, _template)|
          Seams::Events::Publisher.attach_class(
            SUBSCRIBER_KEY,
            event,
            class_name:  SUBSCRIBER_CLASS_NAME,
            method_name: method_name
          )
        end
      end

      private

      def handle_subscription_created(payload)
        enqueue(payload, EVENT_HANDLERS.fetch("subscription.created.billing").last)
      end

      def handle_subscription_updated(payload)
        enqueue(payload, EVENT_HANDLERS.fetch("subscription.updated.billing").last)
      end

      def handle_subscription_canceled(payload)
        enqueue(payload, EVENT_HANDLERS.fetch("subscription.canceled.billing").last)
      end

      def handle_invoice_paid(payload)
        enqueue(payload, EVENT_HANDLERS.fetch("invoice.paid.billing").last)
      end

      def handle_invoice_failed(payload)
        enqueue(payload, EVENT_HANDLERS.fetch("invoice.failed.billing").last)
      end

      def handle_lifetime_granted(payload)
        enqueue(payload, EVENT_HANDLERS.fetch("lifetime.granted.billing").last)
      end

      def handle_lifetime_purchased(payload)
        enqueue(payload, EVENT_HANDLERS.fetch("lifetime.purchased.billing").last)
      end

      def enqueue(payload, template)
        host_user_id = host_user_id_for(payload[:customer_ref])
        return unless host_user_id

        Notifications::CreateNotificationJob.perform_later(
          owner_class: HOST_USER_CLASS_NAME,
          owner_id:    host_user_id,
          template:    template,
          strategy:    "in_app"
        )
      end

      def host_user_id_for(customer_ref)
        return nil if customer_ref.nil? || customer_ref.to_s.empty?

        unless defined?(::User) && ::User.column_names.include?("stripe_customer_id")
          # Visible signal — a silent miss here looks identical to "no
          # user matched", which makes "billing notifications never
          # fire for ANY user" hard to debug. Log loudly once per call.
          Seams::Observability.adapter.warn(
            "notifications.billing_subscriber.skip",
            engine: "notifications",
            reason: "host User class is not defined or has no stripe_customer_id column"
          )
          return nil
        end

        ::User.where(stripe_customer_id: customer_ref).pick(:id)
      end
    end
  end
end
