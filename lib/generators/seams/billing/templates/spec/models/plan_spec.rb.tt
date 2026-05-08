# frozen_string_literal: true

require "rails_helper"

RSpec.describe Billing::Plan do
  describe "validations" do
    it "requires gateway_ref" do
      plan = build(:billing_plan, gateway_ref: nil)
      expect(plan).not_to be_valid
    end

    it "rejects unknown intervals" do
      plan = build(:billing_plan, interval: "decade")
      expect(plan).not_to be_valid
    end
  end

  describe "#lifetime_inventory_remaining" do
    it "is nil for plans with no cap" do
      plan = create(:billing_lifetime_plan, max_lifetime_units: nil)
      expect(plan.lifetime_inventory_remaining).to be_nil
    end

    it "is the cap minus issued passes" do
      plan = create(:billing_lifetime_plan, max_lifetime_units: 3)
      create(:billing_lifetime_pass, plan_ref: plan.gateway_ref)
      expect(plan.lifetime_inventory_remaining).to eq(2)
    end

    it "floors at zero (no negative remaining)" do
      plan = create(:billing_lifetime_plan, max_lifetime_units: 1)
      2.times { create(:billing_lifetime_pass, plan_ref: plan.gateway_ref) }
      expect(plan.lifetime_inventory_remaining).to eq(0)
    end
  end

  describe "#enforce_lifetime_inventory_or_raise!" do
    it "no-ops on non-lifetime plans even if max_lifetime_units is set" do
      plan = create(:billing_plan, interval: "month", max_lifetime_units: 1)
      Billing::Plan.transaction do
        expect { plan.enforce_lifetime_inventory_or_raise! }.not_to raise_error
      end
    end

    it "no-ops on lifetime plans with nil max_lifetime_units (unlimited)" do
      plan = create(:billing_lifetime_plan, max_lifetime_units: nil)
      # Even if some passes exist, nil cap means no enforcement.
      create(:billing_lifetime_pass, plan_ref: plan.gateway_ref)
      Billing::Plan.transaction do
        expect { plan.enforce_lifetime_inventory_or_raise! }.not_to raise_error
      end
    end

    it "passes when remaining inventory > 0" do
      plan = create(:billing_lifetime_plan, max_lifetime_units: 5)
      create(:billing_lifetime_pass, plan_ref: plan.gateway_ref)
      Billing::Plan.transaction do
        expect { plan.enforce_lifetime_inventory_or_raise! }.not_to raise_error
      end
    end

    it "raises Billing::Plan::SoldOut when the cap is exhausted" do
      plan = create(:billing_lifetime_plan, max_lifetime_units: 1)
      create(:billing_lifetime_pass, plan_ref: plan.gateway_ref)
      Billing::Plan.transaction do
        expect { plan.enforce_lifetime_inventory_or_raise! }
          .to raise_error(Billing::Plan::SoldOut, /sold out/)
      end
    end

    it "issues a SELECT ... FOR UPDATE row-lock under the hood" do
      plan = create(:billing_lifetime_plan, max_lifetime_units: 5)
      # We can't directly inspect the lock, but we can confirm
      # `lock!` is invoked (which is what produces the FOR UPDATE).
      expect(plan).to receive(:lock!).and_call_original
      Billing::Plan.transaction do
        plan.enforce_lifetime_inventory_or_raise!
      end
    end
  end
end
