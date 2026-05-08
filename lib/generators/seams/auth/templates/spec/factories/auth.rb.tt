# frozen_string_literal: true

# Factories for Auth engine specs. Tests that need a saved record use
# `create(:auth_identity)` etc.; tests that only need attributes use
# `build(:auth_identity)`. Sequence on email keeps uniqueness happy
# across the full spec run.
FactoryBot.define do
  factory :auth_identity, class: "Auth::Identity" do
    sequence(:email) { |n| "identity-#{n}@example.com" }
    password         { "verysecret" }
    staff            { false }
  end

  factory :auth_session, class: "Auth::Session" do
    association :identity, factory: :auth_identity
    token       { SecureRandom.hex(32) }
    expires_at  { 30.days.from_now }
  end

  factory :auth_oauth_provider, class: "Auth::OAuth::Provider" do
    association :identity, factory: :auth_identity
    provider          { "google" }
    sequence(:provider_uid) { |n| "google-uid-#{n}" }
    access_token      { "fake-access-token" }
    refresh_token     { "fake-refresh-token" }
    expires_at        { 1.hour.from_now }
  end

  factory :auth_api_token, class: "Auth::ApiToken" do
    association :identity, factory: :auth_identity
    name              { "Test token" }
    transient do
      plaintext { "seam_#{SecureRandom.urlsafe_base64(32)}" }
    end
    token_digest      { Auth::ApiToken.digest(plaintext) }
    token_prefix      { plaintext[0, Auth::ApiToken::PREFIX_DISPLAY] }
  end
end
