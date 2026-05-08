# frozen_string_literal: true

# Factories for Accounts engine specs. Sequences keep names unique
# across the full spec run. The :membership factory associates with
# the auth engine's :auth_identity factory — ensure both engines
# are loaded in the dummy app or include the auth_identities table
# in this engine's dummy schema.
FactoryBot.define do
  factory :account, class: "Accounts::Account" do
    sequence(:name) { |n| "Account #{n}" }
    sequence(:external_account_id) { |n| 1_000_000 + n }
  end

  factory :membership, class: "Accounts::Membership" do
    association :account
    association :identity, factory: :auth_identity
    sequence(:name) { |n| "Member #{n}" }
    role   { "member" }
    active { true }

    # Denormalises identity_id from the association rather than
    # relying on belongs_to magic — Membership has no `belongs_to
    # :identity` because the auth engine and accounts engine are
    # peer engines (no cross-engine model access at the
    # ActiveRecord level).
    after(:build) do |membership, evaluator|
      membership.identity_id = evaluator.identity&.id
    end

    transient do
      identity { nil }
    end

    factory :owner_membership do
      role { "owner" }
    end

    factory :admin_membership do
      role { "admin" }
    end

    factory :system_membership do
      role        { "system" }
      identity    { nil }
      identity_id { nil }
      name        { "System" }
    end
  end
end
