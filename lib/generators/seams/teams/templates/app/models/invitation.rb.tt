# frozen_string_literal: true

module Teams
  class Invitation < ApplicationRecord
    self.table_name = "team_invitations"

    belongs_to :team, class_name: "Teams::Team"

    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :token, presence: true, uniqueness: true
    validates :role, inclusion: { in: Teams::Membership::ROLES }

    before_validation :assign_token, on: :create
    before_validation :assign_expiry, on: :create

    scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }

    def expired?
      expires_at <= Time.current
    end

    def accepted?
      accepted_at.present?
    end

    private

    def assign_token
      self.token ||= SecureRandom.urlsafe_base64(32)
    end

    def assign_expiry
      self.expires_at ||= Time.current + Teams.configuration.invitation_ttl
    end
  end
end
