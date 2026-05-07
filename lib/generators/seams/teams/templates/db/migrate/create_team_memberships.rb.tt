# frozen_string_literal: true

# What: creates the team_memberships join table.
# Why:  many-to-many between teams and host users, plus a role column
#       (owner / admin / member) for cheap RBAC.
# Risk: append-mostly. Unique index on (team_id, user_id) prevents
#       duplicate memberships.
class CreateTeamMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :team_memberships do |t|
      t.references :team,   null: false, foreign_key: { to_table: :teams }, index: true
      t.bigint     :user_id, null: false
      t.string     :role,    null: false, default: "member"
      t.timestamps
    end

    add_index :team_memberships, %i[team_id user_id], unique: true
    add_index :team_memberships, :user_id
  end
end
