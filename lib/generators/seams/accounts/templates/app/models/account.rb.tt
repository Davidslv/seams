# frozen_string_literal: true

module Accounts
  # The tenant boundary. One Account per "workspace" / "company" /
  # "tenant" — every other engine that wants to scope its data to a
  # tenant binds to this row.
  #
  # Identity (Auth::Identity) is the human; Account is the workspace;
  # Membership joins them. The same human (Identity) can have
  # memberships in multiple Accounts.
  #
  # UUID primary key (not bigint) so account ids can appear in
  # shareable URLs without leaking row counts. The host User is gone
  # post-Wave-9; downstream engines reference Identity (`identity_id`)
  # or Account (`account_id`).
  class Account < ApplicationRecord
    self.table_name        = "accounts"
    self.primary_key       = "id"
    self.implicit_order_column = "created_at"

    has_many :memberships, class_name: "Accounts::Membership",
                           foreign_key: :account_id, dependent: :destroy

    validates :name, presence: true

    scope :active,    -> { where(cancelled_at: nil) }
    scope :cancelled, -> { where.not(cancelled_at: nil) }

    before_create :assign_external_account_id

    after_create_commit :publish_account_created
    after_update_commit :publish_account_cancelled, if: :saved_change_to_cancelled_at?

    # Returns self so polymorphic helpers that expect `record.account`
    # work uniformly across an Account row and any account-scoped row.
    def account
      self
    end

    def system_membership
      memberships.find_by(role: "system")
    end

    def active?
      cancelled_at.nil? && incinerated_at.nil?
    end

    def cancelled?
      cancelled_at.present?
    end

    # Hard-delete grace period: a cancelled account becomes
    # incinerated when the host job decides the grace window is up.
    def incinerated?
      incinerated_at.present?
    end

    # Wraps Account creation + System + Owner membership in a single
    # transaction so the audit trail always has a System actor and the
    # human creating the account has an Owner row.
    #
    #   Accounts::Account.create_with_owner(
    #     account: { name: "Acme" },
    #     owner:   identity_or_owner_struct
    #   )
    #
    # `owner` must respond to `identity` and `name`. The Identity link
    # is the human's row in `auth_identities`.
    def self.create_with_owner(account:, owner:)
      transaction do
        record = create!(**account)
        record.memberships.create!(
          role:        "system",
          name:        "System",
          identity_id: nil,
          active:      true
        )
        record.memberships.create!(
          role:        "owner",
          name:        owner.name,
          identity_id: owner.identity.id,
          verified_at: Time.current,
          active:      true
        )
        record
      end
    end

    private

    def assign_external_account_id
      self.external_account_id ||= self.class.next_external_account_id
    end

    # Per-class sequence so external_account_id stays unique without a
    # DB-side sequence (UUID PKs make per-row IDs cheap, but
    # external_account_id is a slug-friendly bigint). Hosts that want
    # a different sequence can override this method.
    def self.next_external_account_id
      loop do
        candidate = SecureRandom.random_number(2**62)
        break candidate unless exists?(external_account_id: candidate)
      end
    end

    def publish_account_created
      Seams::Events::Publisher.publish(
        "account.created.accounts",
        account_id:        id,
        owner_identity_id: memberships.where(role: "owner").pick(:identity_id)
      )
    end

    def publish_account_cancelled
      return if cancelled_at.nil?

      Seams::Events::Publisher.publish(
        "account.cancelled.accounts",
        account_id:                  id,
        cancelled_by_identity_id:    Accounts::Current.membership&.identity_id
      )
    end
  end
end
