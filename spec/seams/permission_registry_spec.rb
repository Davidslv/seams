# frozen_string_literal: true

require "seams/permission_registry"

RSpec.describe Seams::PermissionRegistry do
  before { described_class.reset! }

  describe ".register" do
    it "stores the ability code and the owning engine" do
      described_class.register("invoice.read.billing", owned_by: "Billing")

      expect(described_class.registered?("invoice.read.billing")).to be(true)
      expect(described_class.owner_of("invoice.read.billing")).to eq("Billing")
    end

    it "raises when the same ability is registered by two different engines" do
      described_class.register("invoice.read.billing", owned_by: "Billing")

      expect do
        described_class.register("invoice.read.billing", owned_by: "Auth")
      end.to raise_error(Seams::Permissions::DuplicateAbilityError, /already registered/)
    end

    it "is idempotent when the same engine re-registers the same ability" do
      described_class.register("invoice.read.billing", owned_by: "Billing")

      expect do
        described_class.register("invoice.read.billing", owned_by: "Billing")
      end.not_to raise_error
    end

    it "validates the resource.action.engine naming convention" do
      expect do
        described_class.register("nope", owned_by: "X")
      end.to raise_error(Seams::Permissions::InvalidAbilityNameError)
    end
  end

  describe ".all" do
    it "returns the full registry as an enumerable hash" do
      described_class.register("a.b.c", owned_by: "C")
      described_class.register("d.e.f", owned_by: "F")

      expect(described_class.all).to eq("a.b.c" => "C", "d.e.f" => "F")
    end
  end

  describe ".reset!" do
    it "clears all registered abilities" do
      described_class.register("a.b.c", owned_by: "C")
      described_class.reset!

      expect(described_class.all).to be_empty
    end
  end
end
