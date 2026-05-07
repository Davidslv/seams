# frozen_string_literal: true

# Factories for Teams engine specs. Sequences keep names unique
# across the spec run so uniqueness validations don't trip.
FactoryBot.define do
  factory :teams_user, class: "User" do
    sequence(:email) { |n| "user-#{n}@example.com" }
  end

  factory :team, class: "Teams::Team" do
    sequence(:name) { |n| "Team #{n}" }
    sequence(:slug) { |n| "team-#{n}" }
  end

  factory :team_membership, class: "Teams::Membership" do
    association :team
    association :user, factory: :teams_user
    role { "member" }

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
