# frozen_string_literal: true

# What: creates the teams table for the Teams engine.
# Why:  the Team is the unit of multi-tenant ownership (billing
#       customer, project scope, RBAC root) — every host that mounts
#       Teams::Engine needs it.
# Risk: empty on creation, append-mostly thereafter.
class CreateTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :teams, :slug, unique: true
  end
end
