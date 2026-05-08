# frozen_string_literal: true

# What: creates the auth_sessions table for the Auth engine.
# Why:  Auth::Session backs the encrypted cookie set on sign-in; we
#       store the token + expiry so sign-out can revoke just one device.
# Risk: empty table on creation — no data migration needed.
class CreateAuthSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :auth_sessions do |t|
      t.references :identity,    null: false, foreign_key: { to_table: :auth_identities }, index: true
      t.string     :token,       null: false
      t.datetime   :expires_at,  null: false
      t.timestamps
    end

    add_index :auth_sessions, :token, unique: true
    add_index :auth_sessions, :expires_at
  end
end
