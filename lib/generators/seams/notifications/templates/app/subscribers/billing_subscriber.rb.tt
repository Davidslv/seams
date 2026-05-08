# frozen_string_literal: true

module Notifications
  # Consumes Billing events and enqueues a Notifications::CreateNotificationJob
  # (which creates the InApp Notification out-of-band — never inline,
  # see Seams::Events::Publisher docstring).
  #
  # Every subscribed event publishes the same canonical Wave-9 payload
  # shape:
  #   { gateway:, livemode:, account_id:, customer_ref:, ref:, object_id:, object: }
  #
  # `account_id` is the UUID of the Accounts::Account (the billing
  # tenant) the event belongs to. Notifications attaches the resulting
  # Notification row to that Account directly — the recipient model is
  # whatever class the host configured as the billing tenant
  # (`Billing.configuration.billable_class`, default
  # "Accounts::Account"). One human Identity may belong to many
  # Accounts; per-Account billing notifications belong with the tenant,
  # not with the human.
  #
  # +.attach!+ is idempotent across Rails autoreload via
  # +Seams::Events::Publisher.attach_class+ — each event registers its
  # subscriber by class NAME (a String), so dispatch re-resolves the
  # constant on every call. Edits to a +handle_*+ method take effect
  # without a server restart.
  class BillingSubscriber
    SUBSCRIBER_KEY = :notifications_billing_subscriber
    SUBSCRIBER_CLASS_NAME = "Notifications::BillingSubscriber"

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

      # Owner class the billing subscriber attaches the Notification row
      # to. Reads from `Billing.configuration.billable_class` so hosts
      # with a custom tenant model (a host-defined `Workspace`, etc.) get
      # the right `owner_type` without overriding this subscriber. Falls
      # back to the canonical `"Accounts::Account"` if billing isn't
      # configured.
      def owner_class_name
        return "Accounts::Account" unless defined?(Billing) && Billing.respond_to?(:configuration)

        Billing.configuration.billable_class.to_s.presence || "Accounts::Account"
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

      # Wave 9: every canonical billing payload carries `account_id:`
      # (the UUID of the Accounts::Account that owns the billing row)
      # right next to `customer_ref:`. We address the notification at
      # the tenant directly — no host-User lookup needed.
      def enqueue(payload, template)
        account_id = payload[:account_id]
        if account_id.nil? || account_id.to_s.empty?
          # Visible signal — a silent miss here looks identical to "no
          # recipient matched", which makes "billing notifications never
          # fire" hard to debug. Log loudly once per call.
          Seams::Observability.adapter.warn(
            "notifications.billing_subscriber.skip",
            engine: "notifications",
            reason: "billing event missing account_id",
            customer_ref: payload[:customer_ref]
          )
          return
        end

        Notifications::CreateNotificationJob.perform_later(
          owner_class: owner_class_name,
          owner_id:    account_id,
          template:    template,
          strategy:    "in_app"
        )
      end
    end
  end
end
