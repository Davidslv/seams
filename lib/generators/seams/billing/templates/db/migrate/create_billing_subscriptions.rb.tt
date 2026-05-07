# frozen_string_literal: true

# What: creates the billing_subscriptions table.
# Why:  source of truth for "is this customer paying us right now?"
#       Synced from gateway webhooks (status, current_period_end).
# Risk: empty on creation, append-mostly thereafter. Status updates
#       happen in transactions of one row — no locking concerns.
class CreateBillingSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_subscriptions do |t|
      t.string   :customer_ref,        null: false
      t.string   :plan_ref,            null: false
      t.string   :gateway_ref,         null: false
      t.string   :status,              null: false, default: "incomplete"
      t.datetime :current_period_end
      t.timestamps
    end

    add_index :billing_subscriptions, :customer_ref
    add_index :billing_subscriptions, :gateway_ref, unique: true
    add_index :billing_subscriptions, :status
  end
end
