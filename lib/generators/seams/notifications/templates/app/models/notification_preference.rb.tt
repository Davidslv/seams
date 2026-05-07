# frozen_string_literal: true

module Notifications
  # Per-user channel + notification-type toggle. Absence of a row
  # means "use defaults" (everything enabled). Presence with
  # enabled: false means the user opted out.
  class NotificationPreference < ApplicationRecord
    self.table_name = "notification_preferences"

    # Mirrors the keys of Notifications::Notifiable::STRATEGY_CLASSES
    # but kept as plain strings here because the column stores strings.
    CHANNELS = %w[in_app email sms].freeze

    validates :user_id, :channel, presence: true
    validates :channel, inclusion: { in: CHANNELS }
    validates :user_id, uniqueness: { scope: %i[channel notification_type] }

    def self.enabled?(user_id:, channel:, notification_type: nil)
      pref = find_by(user_id: user_id, channel: channel, notification_type: notification_type) ||
             find_by(user_id: user_id, channel: channel, notification_type: nil)
      pref ? pref.enabled : true
    end
  end
end
