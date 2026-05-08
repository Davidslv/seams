# frozen_string_literal: true

# What: creates the auth_users table for the Auth engine.
# Why:  every host application that mounts Auth::Engine needs a place
#       to store password digests and per-user state.
# Risk: empty table on creation — no data migration needed.
class CreateAuthUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :auth_users do |t|
      # `:text` (not `:string`) because `email` is encrypted via
      # ActiveRecord::Encryption (deterministic). Stripe-style envelope
      # ciphertext + base64 + IV/key-id headers expand a 30-char email
      # to ~150–250 bytes; on MySQL `:string` defaults to VARCHAR(255)
      # which silently truncates the cipher and breaks decryption.
      # https://guides.rubyonrails.org/active_record_encryption.html#about-storage-and-column-size
      t.text    :email,            null: false
      t.string  :password_digest,  null: false
      t.bigint  :host_user_id
      t.timestamps
    end

    add_index :auth_users, :email, unique: true
    add_index :auth_users, :host_user_id, where: "host_user_id IS NOT NULL"
  end
end
