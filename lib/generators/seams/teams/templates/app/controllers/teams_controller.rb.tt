# frozen_string_literal: true

module Teams
  class TeamsController < ApplicationController
    before_action :set_team, only: %i[show edit update destroy]

    def index
      @teams = Teams::Team.joins(:memberships).where(memberships: { user_id: current_user_id })
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
        @team.memberships.create!(user_id: current_user_id, role: "owner")
      end

      Seams::Events::Publisher.publish(
        "team.created.teams", team_id: @team.id, owner_id: current_user_id
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

    def current_user_id
      respond_to?(:current_user) && current_user&.id
    end
  end
end
