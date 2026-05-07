# frozen_string_literal: true

# What: creates auth_api_tokens — Bearer-style API tokens issued to
#       Auth::User rows for programmatic access.
# Why:  the engine ships native API token support so hosts don't
#       roll their own. Plaintext is shown once at creation; only the
#       SHA-256 digest is persisted.
# Risk: append-mostly. Unique index on token_digest enforces no
#       collisions (cosmetic — SHA-256 collision space is huge).
#       Partial index on expires_at speeds up the .active scope.
class CreateAuthApiTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :auth_api_tokens do |t|
      t.references :user,         null: false, foreign_key: { to_table: :auth_users }
      t.string     :name,         null: false   # human label ("CI deploy key")
      t.string     :token_digest, null: false   # SHA-256 of the plaintext
      t.string     :token_prefix, null: false   # first ~12 chars for display
      t.datetime   :expires_at                  # nil = never expires
      t.datetime   :last_used_at                # nil = never used
      t.timestamps
    end

    add_index :auth_api_tokens, :token_digest, unique: true
    add_index :auth_api_tokens, :expires_at, where: "expires_at IS NOT NULL"
  end
end
