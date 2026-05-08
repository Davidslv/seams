# frozen_string_literal: true

require "rails_helper"

RSpec.describe Accounts::Account do
  describe "validations" do
    it "requires a name" do
      account = described_class.new
      expect(account).not_to be_valid
      expect(account.errors[:name]).to include("can't be blank")
    end
  end

  describe "scopes" do
    it ".active excludes cancelled accounts" do
      live      = described_class.create!(name: "Live")
      cancelled = described_class.create!(name: "Cancelled", cancelled_at: 1.day.ago)

      expect(described_class.active).to     include(live)
      expect(described_class.active).not_to include(cancelled)
    end
  end

  describe "#active?" do
    it "is true when not cancelled and not incinerated" do
      expect(described_class.new).to be_active
    end

    it "is false when cancelled_at is set" do
      expect(described_class.new(cancelled_at: 1.day.ago)).not_to be_active
    end

    it "is false when incinerated_at is set" do
      expect(described_class.new(incinerated_at: 1.day.ago)).not_to be_active
    end
  end

  describe "#assign_external_account_id" do
    it "auto-assigns external_account_id on create when blank" do
      account = described_class.create!(name: "Acme")
      expect(account.external_account_id).to be_a(Integer)
      expect(account.external_account_id).to be > 0
    end
  end

  describe ".create_with_owner" do
    let(:identity) { Auth::Identity.create!(email: "owner-#{SecureRandom.hex(4)}@example.com", password: "verysecret") }
    let(:owner)    { Struct.new(:identity, :name).new(identity, "Ada") }

    it "creates an account, a system membership, and an owner membership" do
      account = described_class.create_with_owner(account: { name: "Acme" }, owner: owner)
      expect(account.memberships.pluck(:role)).to match_array(%w[system owner])
    end

    it "rolls back the account when the owner membership fails to save" do
      bad_owner = Struct.new(:identity, :name).new(identity, nil)

      expect {
        described_class.create_with_owner(account: { name: "Bad" }, owner: bad_owner)
      }.to raise_error(ActiveRecord::RecordInvalid)
       .and(change(described_class, :count).by(0))
    end
  end
end
