# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::PasswordsMailer, type: :mailer do
  describe "#reset_email" do
    let(:user) do
      create(:auth_user,
             email:                       "ada@example.com",
             password_reset_token:        "raw-token-123",
             password_reset_token_sent_at: Time.current)
    end

    it "sends to the user's email" do
      mail = described_class.reset_email(user)
      expect(mail.to).to eq(["ada@example.com"])
    end

    it "uses the engine's reset subject" do
      mail = described_class.reset_email(user)
      expect(mail.subject).to match(/reset/i)
    end

    it "embeds the password_reset_token so the link in the email actually works" do
      mail = described_class.reset_email(user)
      expect(mail.body.encoded).to include("raw-token-123")
    end
  end
end
