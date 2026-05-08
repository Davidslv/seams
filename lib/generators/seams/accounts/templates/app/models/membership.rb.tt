# frozen_string_literal: true

module Accounts
  # Joins an Auth::Identity to an Accounts::Account with a role.
  #
  # `identity_id` is **nullable**: when set, the row represents a real
  # human in this Account (an owner, admin, or member). When NULL, the
  # row is a system actor — the audit-log writer for changes that
  # don't have a human behind them (background jobs, webhook
  # ingestion, scheduled tasks). Every Account ships with exactly one
  # `role: :system, identity_id: nil` row, created by
  # `Account.create_with_owner`.
  #
  # An Identity can have at most one Membership per Account
  # (enforced by the unique compound index in the migration); the
  # role lives on the Membership, not the Identity.
  class Membership < ApplicationRecord
    self.table_name           = "accounts_memberships"
    self.primary_key          = "id"
    self.implicit_order_column = "created_at"

    ROLES = %w[owner admin member system].freeze

    belongs_to :account, class_name: "Accounts::Account"

    validates :name, presence: true
    validates :role, inclusion: { in: ROLES }
    validates :identity_id,
              uniqueness: { scope: :account_id, allow_nil: true,
                            message: "already has a membership in this account" }

    scope :owner,  -> { where(role: "owner") }
    scope :admin,  -> { where(role: %w[owner admin]) }
    scope :member, -> { where(role: "member") }
    # `:active` excludes the system actor — callers that want every
    # actor (including system) should query without the scope.
    scope :active, -> { where(active: true).where.not(role: "system") }
    scope :system_actors, -> { where(role: "system") }

    after_create_commit :publish_membership_created
    after_update_commit :publish_role_changed, if: :saved_change_to_role?
    after_destroy_commit :publish_membership_removed

    def owner?
      role == "owner"
    end

    def admin?
      %w[owner admin].include?(role)
    end

    def system?
      role == "system"
    end

    # Can `self` perform admin-level changes against `other` (another
    # Membership)? Owners can change anyone, admins can change anyone
    # except an owner, members and the system actor cannot change
    # anyone. Pairs with `can_change?` for the slightly more
    # permissive change-anything-non-destructive rule.
    def can_administer?(other)
      return false if system?
      return false unless admin?
      return true  if owner?

      !other.owner?
    end

    # Like `can_administer?` but allows admins to change other admins
    # (just not owners). Used for invite/remove flows where two
    # admins should be able to manage each other.
    def can_change?(other)
      return false if system?
      return false unless admin?
      return true  if owner?

      !other.owner?
    end

    private

    def publish_membership_created
      Seams::Events::Publisher.publish(
        "membership.created.accounts",
        account_id:    account_id,
        membership_id: id,
        identity_id:   identity_id,
        role:          role
      )
    end

    def publish_role_changed
      from_role, to_role = saved_change_to_role
      Seams::Events::Publisher.publish(
        "membership.role_changed.accounts",
        account_id:                account_id,
        membership_id:             id,
        from_role:                 from_role,
        to_role:                   to_role,
        changed_by_identity_id:    Accounts::Current.membership&.identity_id
      )
    end

    def publish_membership_removed
      Seams::Events::Publisher.publish(
        "membership.removed.accounts",
        account_id:                  account_id,
        membership_id:               id,
        identity_id:                 identity_id,
        removed_by_identity_id:      Accounts::Current.membership&.identity_id
      )
    end
  end
end
