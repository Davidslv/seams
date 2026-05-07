# frozen_string_literal: true

require "active_support/concern"

module Core
  # Multi-tenant row scoping. Auto-fills team_id from Core::Current.team
  # on create and adds a default scope that filters to the current
  # team's rows.
  #
  #   class Article < ApplicationRecord
  #     include Core::TenantScoped
  #   end
  #
  # Requires a `team_id` column on the model's table. Pair with the
  # Teams engine, or any model that exposes Core::Current.team.
  module TenantScoped
    extend ActiveSupport::Concern

    included do
      belongs_to :team, optional: true

      default_scope do
        if Core::Current.team
          where(team_id: Core::Current.team.id)
        else
          all
        end
      end

      before_validation :assign_team, on: :create
    end

    private

    def assign_team
      self.team_id ||= Core::Current.team&.id
    end
  end
end
