# frozen_string_literal: true

# What: creates the accounts table for the Accounts engine.
# Why:  Accounts::Account is the tenant boundary. Every other engine
#       that scopes its data to a tenant binds to this row.
# Risk: empty table on creation — no data migration needed.
#
# UUID primary key (not bigint): account ids appear in shareable URLs
# and we don't want to leak row counts. external_account_id is a
# bigint kept alongside for slug encoding so URL slugs stay short.
class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :accounts, id: :uuid do |t|
      t.string   :name,                 null: false
      t.bigint   :external_account_id,  null: false
      # Soft cancel: account is unusable but data is still recoverable.
      t.datetime :cancelled_at
      # Hard delete grace marker: when set, the host's incinerator job
      # permanently destroys the row + cascade.
      t.datetime :incinerated_at
      t.timestamps
    end

    add_index :accounts, :external_account_id, unique: true
    add_index :accounts, :cancelled_at
  end
end
