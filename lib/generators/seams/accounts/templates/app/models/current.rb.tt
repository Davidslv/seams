# frozen_string_literal: true

module Accounts
  # ActiveSupport::CurrentAttributes namespace for the Accounts engine.
  # Set once per request by the host (typically a before_action that
  # resolves the account from the URL or session); readable from
  # anywhere downstream without explicit threading.
  #
  # Setting `account=` automatically derives the matching Membership
  # for the currently signed-in identity (read from `Auth::Current`).
  # The cross-engine read into `Auth::Current.identity` is intentional:
  # the auth and accounts engines each own a per-request namespace;
  # the accounts engine reads identity to figure out which membership
  # is "current" but never writes to `Auth::Current`.
  #
  # Contract: `Auth::Current.identity` MUST be set before
  # `Accounts::Current.account =`. Hosts wire this in their
  # ApplicationController after their authentication concern runs.
  class Current < ActiveSupport::CurrentAttributes
    attribute :account, :membership

    def account=(value)
      super(value)
      self.membership =
        if value && defined?(Auth::Current) && Auth::Current.identity
          value.memberships.find_by(identity_id: Auth::Current.identity.id)
        end
    end

    def with_account(value, &)
      with(account: value, &)
    end

    def without_account(&)
      with(account: nil, membership: nil, &)
    end
  end
end
