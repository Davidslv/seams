# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::Session do
  let(:identity) { Auth::Identity.create!(email: "x@y.com", password: "secret123") }

  describe "creation" do
    it "auto-assigns a token and expiry" do
      session = identity.sessions.create!
      expect(session.token).to be_present
      expect(session.expires_at).to be > Time.current
    end
  end

  describe "#expired?" do
    it "is false for a fresh session" do
      expect(identity.sessions.create!).not_to be_expired
    end

    it "is true once expires_at has passed" do
      session = identity.sessions.create!(expires_at: 1.minute.ago)
      expect(session).to be_expired
    end
  end

  describe ".active" do
    it "excludes expired sessions" do
      live    = identity.sessions.create!
      _stale  = identity.sessions.create!(expires_at: 1.minute.ago)
      expect(described_class.active).to contain_exactly(live)
    end
  end
end
