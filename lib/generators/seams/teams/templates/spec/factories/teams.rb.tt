# frozen_string_literal: true

# Factories for Teams engine specs. Sequences keep names unique
# across the spec run so uniqueness validations don't trip.
#
# `:team_membership` associates with the auth engine's
# `:auth_identity` factory — ensure the auth_identities table is
# present in the engine's dummy schema (it is, see
# `TeamsGenerator#dummy_schema`).
FactoryBot.define do
  factory :team, class: "Teams::Team" do
    sequence(:name) { |n| "Team #{n}" }
    sequence(:slug) { |n| "team-#{n}" }
  end

  factory :team_membership, class: "Teams::Membership" do
    association :team
    role { "member" }

    # Denormalises identity_id from a built/created :auth_identity
    # rather than relying on belongs_to magic — Membership has no
    # `belongs_to :identity` because Auth::Identity lives in a peer
    # engine (no cross-engine model access at the ActiveRecord level,
    # per the Seams/NoCrossEngineModelAccess cop). Hosts call
    # `create(:team_membership, identity: existing_identity)` or pass
    # `identity_id:` directly.
    transient do
      identity { nil }
    end

    after(:build) do |membership, evaluator|
      membership.identity_id ||= evaluator.identity&.id || FactoryBot.create(:auth_identity).id
    end

    factory :team_admin_membership do
      role { "admin" }
    end
  end

  factory :team_invitation, class: "Teams::Invitation" do
    association :team
    sequence(:email) { |n| "invitee-#{n}@example.com" }
    role       { "member" }
    token      { SecureRandom.hex(16) }
    expires_at { 7.days.from_now }
  end
end
