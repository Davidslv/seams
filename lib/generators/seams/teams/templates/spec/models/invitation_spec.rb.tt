# frozen_string_literal: true

require "rails_helper"

RSpec.describe Teams::Invitation do
  let(:team) { Teams::Team.create!(name: "Acme") }

  it "auto-assigns a token and expiry" do
    inv = team.invitations.create!(email: "x@y.com", role: "member")
    expect(inv.token).to be_present
    expect(inv.expires_at).to be > Time.current
  end

  it "is expired once expires_at passes" do
    inv = team.invitations.create!(email: "x@y.com", role: "member", expires_at: 1.minute.ago)
    expect(inv).to be_expired
  end

  it "rejects two pending invitations to the same email for the same team" do
    team.invitations.create!(email: "x@y.com", role: "member")
    expect do
      team.invitations.create!(email: "x@y.com", role: "admin")
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
