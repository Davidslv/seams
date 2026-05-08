# frozen_string_literal: true

# What: creates auth_oauth_providers — links Auth::User to external
#       OAuth identities (Google, GitHub, etc.). One row per (user,
#       provider) pair.
# Why:  the engine ships native OAuth support so hosts don't roll their
#       own. Tokens are encrypted at the column level via
#       ActiveRecord::Encryption — the host must run
#       `bin/rails db:encryption:init` to seed the keys.
# Risk: append-mostly. profile_data is a json column for the raw
#       provider response (sub/login/etc) so we can re-derive things
#       like display name without re-fetching.
class CreateAuthOauthProviders < ActiveRecord::Migration[7.1]
  def change
    create_table :auth_oauth_providers do |t|
      t.references :user,         null: false, foreign_key: { to_table: :auth_users }
      t.string     :provider,     null: false
      # `:text` because `provider_uid` is encrypted via
      # ActiveRecord::Encryption (deterministic) — see Wave 11. Same
      # ciphertext-overflow concern as auth_users.email.
      t.text       :provider_uid, null: false
      # encrypts :access_token / :refresh_token store ciphertext as
      # text. ActiveRecord::Encryption handles the (de)cipher.
      t.text       :access_token
      t.text       :refresh_token
      t.datetime   :expires_at
      t.string     :token_type,   default: "Bearer"
      t.jsonb      :profile_data, null: false, default: {}
      t.timestamps
    end

    add_index :auth_oauth_providers, %i[provider provider_uid], unique: true
    add_index :auth_oauth_providers, %i[user_id provider],      unique: true
  end
end
