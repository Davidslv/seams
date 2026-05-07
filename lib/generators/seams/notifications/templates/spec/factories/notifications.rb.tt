# frozen_string_literal: true

# Factories for Notifications engine specs. Each strategy gets its
# own factory inheriting from :notification with the right STI type
# locked in. Sequences keep recipient/template values unique.
FactoryBot.define do
  factory :notification, class: "Notifications::Notification" do
    sequence(:template) { |n| "default-#{n}" }
    type                { "Notifications::Strategies::InApp" }
    association :owner, factory: :notifications_user

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

  factory :notifications_user, class: "User" do
    sequence(:email) { |n| "user-#{n}@example.com" }
  end

  factory :notification_delivery, class: "Notifications::Delivery" do
    association :notification, factory: :in_app_notification
    sent_at { Time.current }
  end

  factory :notification_preference, class: "Notifications::NotificationPreference" do
    sequence(:user_id) { |n| n }
    channel            { "email" }
    notification_type  { "default" }
    enabled            { true }
  end
end
