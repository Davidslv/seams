# frozen_string_literal: true

# What: creates the billing_invoices table.
# Why:  per-invoice audit trail for support and finance — when a
#       customer asks "did you charge me on the 3rd?" we don't have to
#       round-trip the gateway every time.
# Risk: append-only writes from webhook handlers; no live-traffic SQL.
class CreateBillingInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_invoices do |t|
      t.string     :gateway_ref,      null: false
      t.string     :customer_ref,     null: false   # Stripe customer id (cus_*)
      t.string     :subscription_ref                # Stripe subscription id (sub_*); nil for one-off invoices
      t.integer    :amount_cents,     null: false
      t.string     :currency,         null: false, default: "USD"
      t.string     :status,           null: false, default: "open"
      t.datetime   :paid_at
      t.timestamps
    end

    add_index :billing_invoices, :gateway_ref,      unique: true
    add_index :billing_invoices, :customer_ref
    add_index :billing_invoices, :subscription_ref, where: "subscription_ref IS NOT NULL"
    add_index :billing_invoices, %i[status created_at]
  end
end
