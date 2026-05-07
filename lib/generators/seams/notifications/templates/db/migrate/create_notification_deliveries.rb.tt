# frozen_string_literal: true

# What: creates notification_deliveries — one row per successful send.
# Why:  audit trail for support and ops ("when did we last send X to
#       user Y?") without round-tripping the upstream gateway.
# Risk: append-only writes from Notification#send!. Indexed by
#       notification_id for join queries from the bell view.
class CreateNotificationDeliveries < ActiveRecord::Migration[7.1]
  def change
    create_table :notification_deliveries do |t|
      t.references :notification, null: false, foreign_key: true, index: true
      t.datetime   :sent_at,      null: false
      t.timestamps
    end
  end
end
