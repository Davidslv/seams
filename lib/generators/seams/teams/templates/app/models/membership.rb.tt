# frozen_string_literal: true

module Teams
  class Membership < ApplicationRecord
    self.table_name = "team_memberships"

    ROLES = %w[owner admin member].freeze

    belongs_to :team, class_name: "Teams::Team"

    validates :user_id, presence: true, uniqueness: { scope: :team_id }
    validates :role, inclusion: { in: ROLES }

    scope :owners, -> { where(role: "owner") }
    scope :admins, -> { where(role: %w[owner admin]) }

    def owner?
      role == "owner"
    end

    def admin?
      %w[owner admin].include?(role)
    end
  end
end
