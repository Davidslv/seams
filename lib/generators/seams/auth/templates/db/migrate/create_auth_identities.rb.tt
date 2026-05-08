# frozen_string_literal: true

# What: creates the auth_identities table for the Auth engine.
# Why:  Auth::Identity owns credentials (password digest, email) and
#       acts as the canonical "who is logging in" record. Other engines
#       address the human via Identity, not via the host's own User.
# Risk: empty table on creation — no data migration needed.
class CreateAuthIdentities < ActiveRecord::Migration[7.1]
  def change
    create_table :auth_identities do |t|
      # `:text` (not `:string`) because `email` is encrypted via
      # ActiveRecord::Encryption (deterministic). Stripe-style envelope
      # ciphertext + base64 + IV/key-id headers expand a 30-char email
      # to ~150–250 bytes; on MySQL `:string` defaults to VARCHAR(255)
      # which silently truncates the cipher and breaks decryption.
      # https://guides.rubyonrails.org/active_record_encryption.html#about-storage-and-column-size
      t.text    :email,            null: false
      t.string  :password_digest,  null: false
      # Platform-admin flag. Identity-level (not Account-scoped) so
      # host admin tooling can bypass account scoping for support.
      # Default false — explicit opt-in only.
      t.boolean :staff,            null: false, default: false
      t.timestamps
    end

    add_index :auth_identities, :email, unique: true
    add_index :auth_identities, :staff, where: "staff = true"
  end
end
