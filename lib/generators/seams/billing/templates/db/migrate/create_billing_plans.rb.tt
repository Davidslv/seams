# frozen_string_literal: true

# What: creates billing_plans, the local mirror of Stripe Prices.
# Why:  the pricing page renders from this table without a per-request
#       Stripe round-trip; webhooks keep it in sync if a plan changes
#       upstream.
# Risk: small table, append-mostly. Unique index on gateway_ref.
class CreateBillingPlans < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_plans do |t|
      t.string  :gateway_ref,        null: false   # price_* from Stripe
      t.string  :name,               null: false
      t.text    :description
      t.integer :amount_cents,       null: false, default: 0
      t.string  :currency,           null: false, default: "usd"
      t.string  :interval,           null: false, default: "month"
      t.integer :trial_period_days
      t.boolean :active,             null: false, default: true
      t.jsonb   :features,           null: false, default: {}
      # LTD inventory cap. nil = unlimited. Only meaningful when
      # interval == "lifetime"; ignored otherwise. The pricing page +
      # admin grant flow read Plan#lifetime_inventory_remaining to
      # gate purchases / grants.
      t.integer :max_lifetime_units
      t.timestamps
    end

    add_index :billing_plans, :gateway_ref, unique: true
    add_index :billing_plans, :active
  end
end
