# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Identity do
  describe "validations" do
    it "requires an email" do
      identity = described_class.new(password: "secret123")
      expect(identity).not_to be_valid
      expect(identity.errors[:email]).to include("can't be blank")
    end

    it "requires the email to look like an email" do
      identity = described_class.new(email: "not-an-email", password: "secret123")
      expect(identity).not_to be_valid
      expect(identity.errors[:email].join).to match(/invalid/i)
    end

    it "normalises emails to lowercase" do
      identity = described_class.new(email: "  Foo@BAR.com  ", password: "secret123")
      identity.valid?
      expect(identity.email).to eq("foo@bar.com")
    end
  end

  describe ".authenticate" do
    it "returns the identity when the password matches" do
      identity = described_class.create!(email: "x@y.com", password: "secret123")
      expect(described_class.authenticate(email: "x@y.com", password: "secret123")).to eq(identity)
    end

    it "returns nil when the password does not match" do
      described_class.create!(email: "x@y.com", password: "secret123")
      expect(described_class.authenticate(email: "x@y.com", password: "wrong")).to be_nil
    end
  end

  describe "#staff?" do
    it "is false by default" do
      expect(described_class.new).not_to be_staff
    end

    it "is true when staff column is set" do
      expect(described_class.new(staff: true)).to be_staff
    end
  end

  describe "password reset (Rails 8 has_secure_password)" do
    it "issues a reset token via the instance method" do
      identity = described_class.create!(email: "x@y.com", password: "secret123")
      token = identity.password_reset_token
      expect(token).to be_a(String)
      expect(described_class.find_by_password_reset_token(token)).to eq(identity)
    end
  end
end
