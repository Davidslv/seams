# frozen_string_literal: true

module Notifications
  # Per-Identity channel + notification-type toggle. Absence of a row
  # means "use defaults" (everything enabled). Presence with
  # enabled: false means the Identity opted out.
  #
  # Keyed by `identity_id` (not the polymorphic Notification owner):
  # channel preferences belong with the human, not with whatever
  # other model a Notification happens to be addressed at (an
  # Account, a Membership, a host-defined model).
  class NotificationPreference < ApplicationRecord
    self.table_name = "notification_preferences"

    # Mirrors the keys of Notifications::Notifiable::STRATEGY_CLASSES
    # but kept as plain strings here because the column stores strings.
    CHANNELS = %w[in_app email sms].freeze

    validates :identity_id, :channel, presence: true
    validates :channel, inclusion: { in: CHANNELS }
    validates :identity_id, uniqueness: { scope: %i[channel notification_type] }

    def self.enabled?(identity_id:, channel:, notification_type: nil)
      pref = find_by(identity_id: identity_id, channel: channel, notification_type: notification_type) ||
             find_by(identity_id: identity_id, channel: channel, notification_type: nil)
      pref ? pref.enabled : true
    end
  end
end
