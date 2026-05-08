# frozen_string_literal: true

module Teams
  class Team < ApplicationRecord
    self.table_name = "teams"

    has_many :memberships, class_name: "Teams::Membership", foreign_key: :team_id, dependent: :destroy
    has_many :invitations, class_name: "Teams::Invitation", dependent: :destroy

    validates :name, presence: true, length: { maximum: 100 }
    validates :slug, presence: true, uniqueness: true,
                     format: { with: /\A[a-z0-9-]+\z/, message: "may only contain lowercase letters, digits and dashes" }

    before_validation :assign_slug, on: :create

    def owner_membership
      memberships.find_by(role: "owner")
    end

    # Predicate for "is this Identity a member of this team?". Pass the
    # Auth::Identity's id (the team_memberships.identity_id column).
    def member?(identity_id)
      memberships.exists?(identity_id: identity_id)
    end

    private

    def assign_slug
      self.slug ||= name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
    end
  end
end
