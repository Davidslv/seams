# frozen_string_literal: true

# What: adds password_reset_token + password_reset_token_sent_at to
#       auth_users so users can request a "I forgot my password" email.
# Why:  password reset is the most-supported flow we don't ship out
#       of the box; without it sign-up + sign-in is a closed loop the
#       user can't recover from.
# Risk: nullable columns added to an existing table — no backfill,
#       no downtime concerns. Unique index on the token is partial
#       (where NOT NULL) so it's cheap on rows that aren't resetting.
class AddPasswordResetToAuthUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :auth_users, :password_reset_token,         :string
    add_column :auth_users, :password_reset_token_sent_at, :datetime

    add_index  :auth_users, :password_reset_token, unique: true,
                                                   where: "password_reset_token IS NOT NULL"
  end
end
