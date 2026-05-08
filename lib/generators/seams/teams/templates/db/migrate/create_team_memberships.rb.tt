# frozen_string_literal: true

# What: creates the team_memberships join table.
# Why:  many-to-many between teams and Auth::Identity rows, plus a
#       role column (owner / admin / member) for cheap RBAC. Teams
#       are peers to Accounts post-Wave-9, so the join is to Identity
#       directly — not to an Accounts::Membership.
# Risk: append-mostly. Unique index on (team_id, identity_id) prevents
#       duplicate memberships. No FK to auth_identities because the
#       auth and teams engines may live in different schemas /
#       databases in production — cross-engine integrity is enforced
#       at the application layer.
class CreateTeamMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :team_memberships do |t|
      t.references :team,        null: false, foreign_key: { to_table: :teams }, index: true
      t.bigint     :identity_id, null: false
      t.string     :role,        null: false, default: "member"
      t.timestamps
    end

    add_index :team_memberships, %i[team_id identity_id], unique: true
    add_index :team_memberships, :identity_id
  end
end
