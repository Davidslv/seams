# frozen_string_literal: true

# What: creates billing_lifetime_passes — the one-time-paid OR privately
#       granted permanent-access record. Lives in its own table because
#       Subscription's renewal/period semantics don't apply.
# Why:  Lifetime Deals (LTDs) are a real revenue + early-adopter feedback
#       channel; the engine ships the mechanism so hosts can offer them
#       without rolling their own model. See README LTD section for the
#       trade-off (indefinite support, no recurring revenue).
# Risk: append-mostly (revoke is a soft delete via revoked_at, not a row
#       delete, so audit history survives). Unique index on
#       (customer_ref, plan_ref) prevents accidentally double-granting.
class CreateBillingLifetimePasses < ActiveRecord::Migration[7.1]
  def change
    create_table :billing_lifetime_passes do |t|
      t.string   :customer_ref,        null: false   # gateway-side customer id (cus_*)
      t.string   :plan_ref,            null: false   # billing_plans.gateway_ref
      t.string   :gateway_ref                        # Stripe Checkout Session id; nil for private grants
      t.bigint   :granted_by_user_id                 # admin host_user_id; nil for paid LTDs
      t.datetime :granted_at,          null: false
      t.datetime :revoked_at                         # soft-revoke (refund / ToS violation)
      t.bigint   :revoked_by_user_id                 # admin host_user_id who revoked
      t.text     :notes
      t.timestamps
    end

    add_index :billing_lifetime_passes, %i[customer_ref plan_ref], unique: true,
                                                                   name: "index_billing_ltd_unique"
    add_index :billing_lifetime_passes, :gateway_ref, unique: true,
                                                      where: "gateway_ref IS NOT NULL"
    add_index :billing_lifetime_passes, :revoked_at, where: "revoked_at IS NULL"
  end
end
