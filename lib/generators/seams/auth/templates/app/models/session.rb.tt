# frozen_string_literal: true

module Auth
  class Session < ApplicationRecord
    self.table_name = "auth_sessions"

    belongs_to :user, class_name: "Auth::User"

    before_create :assign_token
    before_create :assign_expiry

    scope :active, -> { where("expires_at > ?", Time.current) }

    def expired?
      expires_at <= Time.current
    end

    private

    def assign_token
      self.token ||= SecureRandom.hex(32)
    end

    def assign_expiry
      self.expires_at ||= Time.current + Auth.configuration.session_ttl
    end
  end
end
