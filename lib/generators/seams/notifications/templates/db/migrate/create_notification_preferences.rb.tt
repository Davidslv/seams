# frozen_string_literal: true

# What: creates notification_preferences for per-user opt-outs.
# Why:  hosts need a place for "email me when X" toggles. Single
#       row per (user, channel, notification_type) — absence means
#       use defaults.
# Risk: tiny table, indexed for fast lookup.
class CreateNotificationPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :notification_preferences do |t|
      t.bigint  :user_id,           null: false
      t.string  :channel,           null: false  # "in_app" | "email" | "sms"
      t.string  :notification_type
      t.boolean :enabled,           null: false, default: true
      t.timestamps
    end

    add_index :notification_preferences, %i[user_id channel notification_type], unique: true,
                                                                                 name: "index_notification_prefs_unique"
  end
end
