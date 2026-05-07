# frozen_string_literal: true

module Teams
  class Team < ApplicationRecord
    self.table_name = "teams"

    has_many :memberships, class_name: "Teams::Membership", dependent: :destroy
    has_many :invitations, class_name: "Teams::Invitation", dependent: :destroy

    validates :name, presence: true, length: { maximum: 100 }
    validates :slug, presence: true, uniqueness: true,
                     format: { with: /\A[a-z0-9-]+\z/, message: "may only contain lowercase letters, digits and dashes" }

    before_validation :assign_slug, on: :create

    def owner_membership
      memberships.find_by(role: "owner")
    end

    def member?(host_user_id)
      memberships.exists?(user_id: host_user_id)
    end

    private

    def assign_slug
      self.slug ||= name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
    end
  end
end
