# frozen_string_literal: true

require "rails_helper"

RSpec.describe Teams::Membership do
  let(:team) { Teams::Team.create!(name: "Acme") }

  it "rejects unknown roles" do
    m = described_class.new(team: team, identity_id: 1, role: "made_up")
    expect(m).not_to be_valid
  end

  it "is unique on (team_id, identity_id)" do
    described_class.create!(team: team, identity_id: 1, role: "member")
    dup = described_class.new(team: team, identity_id: 1, role: "admin")
    expect(dup).not_to be_valid
  end

  describe "#admin?" do
    it "is true for owner and admin roles" do
      expect(described_class.new(role: "owner")).to be_admin
      expect(described_class.new(role: "admin")).to be_admin
    end

    it "is false for member" do
      expect(described_class.new(role: "member")).not_to be_admin
    end
  end
end
