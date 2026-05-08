# frozen_string_literal: true

# What: creates the accounts_memberships join table.
# Why:  joins Auth::Identity to Accounts::Account with a role.
#       identity_id is NULLABLE: rows with NULL identity_id are
#       system actors used for audit-log writes that don't have a
#       human behind them (background jobs, webhook ingestion).
# Risk: append-mostly. Unique compound index on (account_id,
#       identity_id) ensures an Identity has at most one Membership
#       per Account; system rows (NULL identity_id) bypass that
#       constraint by virtue of the NULL.
class CreateAccountsMemberships < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :accounts_memberships, id: :uuid do |t|
      t.references :account,      type: :uuid, null: false,
                                  foreign_key: { to_table: :accounts }, index: false
      # NULL = system actor. Otherwise references Auth::Identity. No
      # FK to auth_identities because the auth and accounts engines
      # may live in different schemas / databases in production —
      # cross-engine integrity is enforced at the application layer.
      # bigint to match auth_identities' default integer PK (the same
      # convention every other engine — billing, teams — follows).
      t.bigint     :identity_id,  null: true
      # Denormalised display name so the Identity (and its email)
      # can be soft-deleted / anonymised without breaking the
      # account's audit trail.
      t.string     :name,         null: false
      t.string     :role,         null: false, default: "member"
      t.boolean    :active,       null: false, default: true
      t.datetime   :verified_at
      t.timestamps
    end

    add_index :accounts_memberships, %i[account_id identity_id], unique: true,
                                                                 name: "index_accounts_memberships_unique"
    add_index :accounts_memberships, %i[account_id role]
    add_index :accounts_memberships, :identity_id
    # Postgres treats NULLs as distinct in unique indexes, so the
    # compound index above does NOT prevent two `(account_id, NULL)`
    # rows. Wave 9 invariant: every Account has EXACTLY ONE system
    # actor (created by `Account.create_with_owner`). Enforce it at
    # the DB level with a partial unique index over the system rows.
    add_index :accounts_memberships, :account_id, unique: true,
              where: "role = 'system'",
              name: "index_accounts_memberships_one_system_per_account"
  end
end
