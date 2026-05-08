# frozen_string_literal: true

# Factories for Notifications engine specs. Each strategy gets its
# own factory inheriting from :notification with the right STI type
# locked in. Sequences keep recipient/template values unique.
#
# Wave 9: the default Notification owner is :auth_identity (the
# canonical "human" model). The legacy :notifications_user factory
# is retained as an alias so older specs / generator-spec assertions
# keep working.
FactoryBot.define do
  factory :notification, class: "Notifications::Notification" do
    sequence(:template) { |n| "default-#{n}" }
    type                { "Notifications::Strategies::InApp" }
    association :owner, factory: :auth_identity

    factory :in_app_notification, class: "Notifications::Strategies::InApp" do
      type { "Notifications::Strategies::InApp" }
    end

    factory :email_notification, class: "Notifications::Strategies::Email" do
      type      { "Notifications::Strategies::Email" }
      sequence(:recipient) { |n| "to-#{n}@example.com" }
    end

    factory :sms_notification, class: "Notifications::Strategies::Sms" do
      type      { "Notifications::Strategies::Sms" }
      sequence(:recipient) { |n| "+1555010#{format('%04d', n)}" }
    end
  end

  factory :auth_identity, class: "Auth::Identity" do
    sequence(:email) { |n| "identity-#{n}@example.com" }
  end

  # Backwards-compatible alias for specs that still reference
  # :notifications_user. Returns an Auth::Identity (the polymorphic
  # owner doesn't care about the class name as long as it's an AR
  # record with an id).
  factory :notifications_user, parent: :auth_identity

  factory :notification_delivery, class: "Notifications::Delivery" do
    association :notification, factory: :in_app_notification
    sent_at { Time.current }
  end

  factory :notification_preference, class: "Notifications::NotificationPreference" do
    sequence(:identity_id) { |n| n }
    channel                { "email" }
    notification_type      { "default" }
    enabled                { true }
  end
end
