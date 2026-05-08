# frozen_string_literal: true

# What: creates the billing_subscriptions table.
# Why:  source of truth for "is this customer paying us right now?"
#       Synced from gateway webhooks (status, current_period_end). Bound
#       to an Accounts::Account (the tenant) — not to an Identity. The
#       Stripe customer is the workspace, not the human; a single
#       human (Identity) with memberships in two Accounts has two
#       independent billing relationships.
# Risk: empty on creation, append-mostly thereafter. Status updates
#       happen in transactions of one row — no locking concerns.
class CreateBillingSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_subscriptions do |t|
      # Local tenant FK. UUID to match Accounts::Account#id; no DB-level
      # foreign key because billing and accounts may live in different
      # schemas / databases — cross-engine integrity is enforced at the
      # application layer (the AccountScoped concern + service objects).
      t.uuid     :account_id,          null: false
      t.string   :customer_ref,        null: false   # Stripe customer id (cus_*) for the Account
      t.string   :plan_ref,            null: false
      t.string   :gateway_ref,         null: false
      t.string   :status,              null: false, default: "incomplete"
      t.datetime :current_period_end
      t.timestamps
    end

    add_index :billing_subscriptions, :account_id
    add_index :billing_subscriptions, :customer_ref
    add_index :billing_subscriptions, :gateway_ref, unique: true
    add_index :billing_subscriptions, :status
  end
end
