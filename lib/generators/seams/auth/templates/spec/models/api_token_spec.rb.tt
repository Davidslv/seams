# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::ApiToken do
  describe "validations" do
    it "requires identity, name, token_digest, token_prefix" do
      token = described_class.new
      expect(token).not_to be_valid
      %i[identity name token_digest token_prefix].each do |attr|
        expect(token.errors[attr]).not_to be_empty
      end
    end

    it "enforces token_digest uniqueness at the model level" do
      create(:auth_api_token, token_digest: "fixed-digest")
      duplicate = build(:auth_api_token, token_digest: "fixed-digest")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:token_digest]).to include("has already been taken")
    end
  end

  describe ".digest" do
    it "is a SHA-256 hexdigest of the plaintext" do
      expected = Digest::SHA256.hexdigest("seam_abc123")
      expect(described_class.digest("seam_abc123")).to eq(expected)
    end

    it "returns the same digest for the same input" do
      expect(described_class.digest("foo")).to eq(described_class.digest("foo"))
    end
  end

  describe ".find_by_plaintext" do
    it "returns the token whose digest matches the plaintext" do
      plaintext = "seam_known_plaintext"
      record    = create(:auth_api_token, plaintext: plaintext)
      expect(described_class.find_by_plaintext(plaintext)).to eq(record)
    end

    it "returns nil for an unknown plaintext" do
      create(:auth_api_token)
      expect(described_class.find_by_plaintext("seam_does_not_exist")).to be_nil
    end

    it "returns nil for a blank plaintext (does not match nil-digest rows)" do
      expect(described_class.find_by_plaintext("")).to be_nil
      expect(described_class.find_by_plaintext(nil)).to be_nil
    end
  end

  describe "#expired?" do
    it "is false when expires_at is nil" do
      expect(build(:auth_api_token, expires_at: nil)).not_to be_expired
    end

    it "is false when expires_at is in the future" do
      expect(build(:auth_api_token, expires_at: 1.hour.from_now)).not_to be_expired
    end

    it "is true when expires_at is in the past" do
      expect(build(:auth_api_token, expires_at: 1.hour.ago)).to be_expired
    end
  end

  describe "scopes" do
    it ".active includes never-expiring + future-expiring; excludes past-expiring" do
      live   = create(:auth_api_token, expires_at: nil)
      future = create(:auth_api_token, expires_at: 1.day.from_now)
      past   = create(:auth_api_token, expires_at: 1.day.ago)

      expect(described_class.active).to include(live, future)
      expect(described_class.active).not_to include(past)
    end
  end

  describe "#touch_last_used!" do
    it "updates last_used_at" do
      token = create(:auth_api_token, last_used_at: nil)
      expect { token.touch_last_used! }
        .to change { token.reload.last_used_at }.from(nil)
    end
  end
end
