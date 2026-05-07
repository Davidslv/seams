# frozen_string_literal: true

# What: creates the team_invitations table.
# Why:  invitation lifecycle (sent / accepted / expired / revoked) is
#       distinct from membership and we want to keep the audit trail
#       even after the recipient joins.
# Risk: append-mostly. Token uniqueness is the security guarantee.
class CreateTeamInvitations < ActiveRecord::Migration[7.1]
  def change
    create_table :team_invitations do |t|
      t.references :team,        null: false, foreign_key: { to_table: :teams }, index: true
      t.string     :email,       null: false
      t.string     :token,       null: false
      t.string     :role,        null: false, default: "member"
      t.datetime   :expires_at,  null: false
      t.datetime   :accepted_at
      t.timestamps
    end

    add_index :team_invitations, :token, unique: true
    add_index :team_invitations, %i[team_id email], unique: true,
                                                    where: "accepted_at IS NULL"
  end
end
