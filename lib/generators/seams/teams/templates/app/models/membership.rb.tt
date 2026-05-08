# frozen_string_literal: true

module Teams
  # Joins a Teams::Team to an Auth::Identity with a role. Wave 9 made
  # teams a peer engine to accounts: the join is direct to Identity
  # (not to an Accounts::Membership). `identity_id` is a bare bigint
  # FK with no `belongs_to :identity` because Auth::Identity lives in
  # a sibling engine and cross-engine ActiveRecord access is forbidden
  # by the Seams/NoCrossEngineModelAccess cop. Look up the human via
  # the auth engine's API or by `Auth::Identity.find(identity_id)` from
  # host code.
  class Membership < ApplicationRecord
    self.table_name = "team_memberships"

    # Teams roles are independent of Accounts roles by design — a
    # team is its own RBAC unit. Hosts that want a single role across
    # both should denormalise that themselves.
    ROLES = %w[owner admin member].freeze

    belongs_to :team, class_name: "Teams::Team"

    validates :identity_id, presence: true, uniqueness: { scope: :team_id }
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
