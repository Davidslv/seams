# frozen_string_literal: true

# What: creates billing_webhook_events for idempotent webhook handling.
# Why:  Stripe explicitly recommends deduping by event id because they
#       retry indefinitely until the endpoint returns 2xx
#       (https://docs.stripe.com/webhooks#handle-duplicate-events).
#       Without this table the welcome-email subscriber would re-send
#       on every retry.
# Risk: empty on creation, append-only thereafter. Unique index on
#       gateway_event_id is the deduper.
class CreateBillingWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_webhook_events do |t|
      t.string   :gateway,            null: false   # "stripe" | "paddle" | ...
      t.string   :gateway_event_id,   null: false   # provider's evt_* id
      t.string   :event_type,         null: false
      t.boolean  :livemode,           null: false, default: false
      t.timestamps
    end

    add_index :billing_webhook_events, %i[gateway gateway_event_id], unique: true
    add_index :billing_webhook_events, :event_type
  end
end
