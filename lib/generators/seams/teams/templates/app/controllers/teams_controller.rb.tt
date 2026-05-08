# frozen_string_literal: true

module Teams
  class TeamsController < ApplicationController
    before_action :set_team, only: %i[show edit update destroy]

    def index
      @teams = Teams::Team.joins(:memberships).where(memberships: { identity_id: current_identity_id })
    end

    def show; end
    def new
      @team = Teams::Team.new
    end

    def edit; end

    def create
      @team = Teams::Team.new(team_params)
      Teams::Team.transaction do
        @team.save!
        @team.memberships.create!(identity_id: current_identity_id, role: "owner")
      end

      Seams::Events::Publisher.publish(
        "team.created.teams", team_id: @team.id, creator_identity_id: current_identity_id
      )
      redirect_to @team, notice: "Team created"
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def update
      if @team.update(team_params)
        redirect_to @team, notice: "Team updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @team.destroy
      redirect_to teams_path, notice: "Team deleted"
    end

    private

    def set_team
      @team = Teams::Team.find(params[:id])
    end

    def team_params
      params.require(:team).permit(:name, :slug)
    end

    # Resolves the signed-in human's id from `Auth::Current.identity`
    # (the Auth engine's per-request namespace). Gated on
    # `defined?(Auth::Current)` so it's safe in hosts that don't ship
    # auth. Override in your host if you wire auth differently.
    def current_identity_id
      if defined?(Auth::Current) && Auth::Current.respond_to?(:identity) && Auth::Current.identity
        return Auth::Current.identity.id
      end

      nil
    end
  end
end
