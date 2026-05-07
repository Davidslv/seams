# frozen_string_literal: true

require "active_support/concern"

module Teams
  # Mix into any model whose rows belong to a single team. Sets up
  # the belongs_to + a default_scope that filters to `Current.team`
  # whenever it's set, so every query in a request thread is
  # automatically scoped without each finder needing to remember.
  #
  #   class Project < ApplicationRecord
  #     include Teams::AccountScoped
  #   end
  #
  #   Current.team = team
  #   Project.create!(name: "...")  # team_id auto-assigned to team.id
  #   Project.all                   # only team's projects
  #
  # Pairs with Core's `TenantScoped` — same shape, different ownership
  # model: TenantScoped binds to the host's tenant abstraction;
  # AccountScoped binds specifically to a Teams::Team.
  #
  # `Current.team` MUST be set by host middleware (typically a
  # before_action that resolves the team from the URL or session).
  # When unset, the default_scope is a no-op, so background jobs
  # (Active Job runs without Current state) see every row — wire
  # `Current.team =` into your job's #perform if you need scoping
  # there.
  module AccountScoped
    extend ActiveSupport::Concern

    included do
      belongs_to :team, class_name: "Teams::Team"

      default_scope -> { where(team_id: Current.team&.id) if Current.team }
      before_validation :assign_current_team, on: :create
    end

    private

    def assign_current_team
      self.team_id ||= Current.team&.id if Current.team
    end
  end
end
