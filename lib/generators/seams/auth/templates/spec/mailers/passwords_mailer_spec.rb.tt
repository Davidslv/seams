# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::PasswordsMailer, type: :mailer do
  describe "#reset_email" do
    let(:identity) { create(:auth_identity, email: "ada@example.com") }

    it "sends to the identity's email" do
      mail = described_class.reset_email(identity)
      expect(mail.to).to eq(["ada@example.com"])
    end

    it "uses the engine's reset subject" do
      mail = described_class.reset_email(identity)
      expect(mail.subject).to match(/reset/i)
    end

    it "embeds a Rails 8 signed_id reset token in the link so the email is actionable" do
      mail = described_class.reset_email(identity)
      # Rails 8 signed_id tokens are url-safe base64 with embedded
      # purpose + expiry. The mailer generates the token at send time
      # (so its expiry is as late as possible), which means we can't
      # pre-generate a token in the spec and string-match — every
      # call to `password_reset_token` produces a different signed_id
      # because the exp timestamp moves. Instead extract the token
      # from the rendered link and verify it round-trips back to the
      # original Identity.
      body  = mail.body.encoded
      match = body.match(/token=([^"&\s]+)/)
      expect(match).not_to be_nil, "no `token=` query param found in: #{body}"
      raw_token = CGI.unescape(match[1])
      resolved  = Auth::Identity.find_by_password_reset_token(raw_token)
      expect(resolved).to eq(identity)
    end
  end
end
