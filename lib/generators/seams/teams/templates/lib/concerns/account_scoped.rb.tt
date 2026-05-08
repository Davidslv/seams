# frozen_string_literal: true

require "active_support/concern"

module Teams
  # Mix into any model whose rows belong to a single team. Sets up
  # the belongs_to + a default_scope that filters to
  # `Teams::Current.team`. When `Teams::Current.team` is unset the
  # scope returns `none` (an empty relation) — see "fail-closed"
  # below.
  #
  #   class Project < ApplicationRecord
  #     include Teams::AccountScoped
  #   end
  #
  #   Teams::Current.team = team
  #   Project.create!(name: "...")  # team_id auto-assigned to team.id
  #   Project.all                   # only team's projects
  #
  # Pairs with Core's `TenantScoped` — same shape, different ownership
  # model: TenantScoped binds to the host's tenant abstraction;
  # AccountScoped binds specifically to a Teams::Team.
  #
  # ### Fail-closed default
  #
  # When `Teams::Current.team` is nil, the default_scope returns
  # `none` rather than `all`. Same rationale as Accounts::AccountScoped:
  # the alternative (return all rows across all teams when no team is
  # bound) is the canonical multi-team data-leak bug. Fail-closed
  # surfaces "I have no rows" — a noisy symptom the developer fixes
  # immediately — instead of a silent leak.
  #
  # Opt-out paths (use deliberately):
  #   * `.unscoped`               — full Active Record bypass.
  #   * `.with_no_team_scope`     — drops the team_id filter only,
  #                                 preserves any other default_scopes.
  #
  # Background jobs MUST set `Teams::Current.team =` before querying,
  # or call `.with_no_team_scope` explicitly.
  module AccountScoped
    extend ActiveSupport::Concern

    included do
      belongs_to :team, class_name: "Teams::Team"

      # The default_scope ALWAYS applies a where(:team_id) clause —
      # either filtered to the current team, or filtered to a
      # never-matching sentinel (`team_id IS NULL`). This shape lets
      # `unscope(where: :team_id)` in `with_no_team_scope` reverse the
      # filter cleanly; using `none` here would create a NullRelation
      # that `unscope` cannot un-do.
      default_scope -> {
        team = Teams::Current.team
        if team
          where(team_id: team.id)
        else
          where(team_id: nil)
        end
      }
      before_validation :assign_current_team, on: :create
    end

    class_methods do
      # Returns the relation as it would be without the team_id
      # filter, preserving any other default_scopes the model
      # declares. Use deliberately — name-it-loud opt-out for seed
      # scripts, migrations, and platform tooling.
      def with_no_team_scope
        unscope(where: :team_id)
      end
    end

    private

    def assign_current_team
      self.team_id ||= Teams::Current.team&.id if Teams::Current.team
    end
  end
end
