# frozen_string_literal: true

require "rails_helper"

RSpec.describe Billing::Subscription do
  let(:valid_attrs) do
    { customer_ref: "cus_x", plan_ref: "price_x", gateway_ref: "sub_x", status: "active" }
  end

  describe "validations" do
    it "requires gateway_ref" do
      sub = described_class.new(valid_attrs.merge(gateway_ref: nil))
      expect(sub).not_to be_valid
    end

    it "rejects unknown statuses" do
      sub = described_class.new(valid_attrs.merge(status: "made_up"))
      expect(sub).not_to be_valid
    end
  end

  describe "#active?" do
    it "is true for active and trialing" do
      expect(described_class.new(valid_attrs.merge(status: "active"))).to be_active
      expect(described_class.new(valid_attrs.merge(status: "trialing"))).to be_active
    end

    it "is false for canceled" do
      expect(described_class.new(valid_attrs.merge(status: "canceled"))).not_to be_active
    end
  end
end
