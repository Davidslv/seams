# frozen_string_literal: true

require "rails_helper"

RSpec.describe Accounts::Membership do
  let(:account)  { Accounts::Account.create!(name: "Acme") }
  let(:identity) do
    Auth::Identity.create!(email: "x-#{SecureRandom.hex(4)}@example.com", password: "verysecret")
  end

  describe "validations" do
    it "requires a name" do
      m = described_class.new(account: account, role: "member")
      expect(m).not_to be_valid
      expect(m.errors[:name]).to include("can't be blank")
    end

    it "rejects unknown roles" do
      m = described_class.new(account: account, name: "x", role: "spectator")
      expect(m).not_to be_valid
      expect(m.errors[:role].join).to match(/included in the list/i)
    end

    it "enforces one Membership per (account, identity)" do
      described_class.create!(account: account, identity_id: identity.id, name: "First", role: "member")
      duplicate = described_class.new(account: account, identity_id: identity.id, name: "Second", role: "member")
      expect(duplicate).not_to be_valid
    end

    it "allows multiple system rows (NULL identity_id) per account" do
      first = described_class.create!(account: account, identity_id: nil, name: "System", role: "system")
      second = described_class.new(account: account, identity_id: nil, name: "System 2", role: "system")
      expect(first).to be_persisted
      expect(second).to be_valid
    end
  end

  describe "scopes" do
    let!(:owner) do
      described_class.create!(account: account, identity_id: identity.id, name: "O", role: "owner")
    end
    let(:other_identity) do
      Auth::Identity.create!(email: "y-#{SecureRandom.hex(4)}@example.com", password: "verysecret")
    end
    let!(:admin)  { described_class.create!(account: account, identity_id: other_identity.id, name: "A", role: "admin") }
    let!(:system) { described_class.create!(account: account, identity_id: nil, name: "System", role: "system") }

    it ".admin includes owner and admin" do
      expect(described_class.admin).to include(owner, admin)
      expect(described_class.admin).not_to include(system)
    end

    it ".active excludes the system actor" do
      expect(described_class.active).to     include(owner, admin)
      expect(described_class.active).not_to include(system)
    end
  end

  describe "predicates" do
    it "owner? / admin? / system?" do
      owner = described_class.new(role: "owner")
      admin = described_class.new(role: "admin")
      system = described_class.new(role: "system")

      expect(owner).to be_owner
      expect(owner).to be_admin
      expect(admin).not_to be_owner
      expect(admin).to be_admin
      expect(system).to be_system
    end
  end

  describe "#can_administer? / #can_change?" do
    let(:owner)  { described_class.new(role: "owner") }
    let(:admin)  { described_class.new(role: "admin") }
    let(:member) { described_class.new(role: "member") }
    let(:system) { described_class.new(role: "system") }

    it "owner can administer everyone" do
      expect(owner.can_administer?(admin)).to be(true)
      expect(owner.can_administer?(member)).to be(true)
    end

    it "admin can administer admins and members but not owners" do
      expect(admin.can_administer?(member)).to be(true)
      expect(admin.can_administer?(admin)).to be(true)
      expect(admin.can_administer?(owner)).to be(false)
    end

    it "member cannot administer anyone" do
      expect(member.can_administer?(admin)).to be(false)
      expect(member.can_administer?(member)).to be(false)
    end

    it "system actor never administers" do
      expect(system.can_administer?(member)).to be(false)
    end
  end
end
