# frozen_string_literal: true

require "active_support/concern"

module Teams
  # Mix into the host's user-facing model:
  #
  #   class User < ApplicationRecord
  #     include Teams::Teamable
  #   end
  #
  # Adds a team-membership query API plus helpers that hide the
  # cross-table joins behind familiar Rails idioms.
  module Teamable
    extend ActiveSupport::Concern

    included do
      has_many :team_memberships, class_name: "Teams::Membership",
                                  foreign_key: :user_id, dependent: :destroy
      has_many :teams, through: :team_memberships, source: :team
    end

    def member_of?(team)
      team_memberships.exists?(team_id: team.id)
    end

    def admin_of?(team)
      team_memberships.where(team_id: team.id, role: %w[owner admin]).exists?
    end

    def owner_of?(team)
      team_memberships.exists?(team_id: team.id, role: "owner")
    end
  end
end
