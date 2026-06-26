# frozen_string_literal: true

require "seams/permission_registry"

RSpec.describe Seams::Permissions do
  before { Seams::PermissionRegistry.reset! }

  describe ".valid_name?" do
    it "accepts a resource.action.engine code" do
      expect(described_class.valid_name?("invoice.read.billing")).to be(true)
    end

    it "rejects a code that isn't three dot-separated segments" do
      expect(described_class.valid_name?("nope")).to be(false)
    end
  end

  describe ".assert_valid_name!" do
    it "raises for an invalid ability name" do
      expect do
        described_class.assert_valid_name!("nope")
      end.to raise_error(described_class::InvalidAbilityNameError)
    end
  end

  describe ".can?" do
    before { Seams::PermissionRegistry.register("invoice.read.billing", owned_by: "Billing") }

    it "returns true when the role is granted the ability directly" do
      Seams.configure { |c| c.permission_grants = { "member" => ["invoice.read.billing"] } }

      expect(described_class.can?(role: "member", ability: "invoice.read.billing")).to be(true)
    end

    it "returns false when the grant map gives the role nothing" do
      Seams.configure { |c| c.permission_grants = {} }

      expect(described_class.can?(role: "member", ability: "invoice.read.billing")).to be(false)
    end

    it "lets admin inherit an ability granted to member" do
      Seams.configure { |c| c.permission_grants = { "member" => ["invoice.read.billing"] } }

      expect(described_class.can?(role: "admin", ability: "invoice.read.billing")).to be(true)
    end

    it "lets owner inherit an ability granted to member" do
      Seams.configure { |c| c.permission_grants = { "member" => ["invoice.read.billing"] } }

      expect(described_class.can?(role: "owner", ability: "invoice.read.billing")).to be(true)
    end

    it "does not let member inherit an ability granted only to admin" do
      Seams.configure { |c| c.permission_grants = { "admin" => ["invoice.read.billing"] } }

      expect(described_class.can?(role: "member", ability: "invoice.read.billing")).to be(false)
    end

    it "lets the system role bypass every check regardless of the map" do
      Seams.configure { |c| c.permission_grants = {} }

      expect(described_class.can?(role: "system", ability: "invoice.read.billing")).to be(true)
    end

    it "tolerates symbol keys and values in the grant map" do
      Seams.configure { |c| c.permission_grants = { member: [:"invoice.read.billing"] } }

      expect(described_class.can?(role: "member", ability: "invoice.read.billing")).to be(true)
    end

    it "raises rather than returning false for an unregistered ability" do
      expect do
        described_class.can?(role: "member", ability: "invoice.delete.billing")
      end.to raise_error(described_class::UnregisteredAbilityError, /not registered/)
    end
  end
end
