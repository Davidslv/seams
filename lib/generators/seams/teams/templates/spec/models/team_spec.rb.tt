# frozen_string_literal: true

require "rails_helper"

RSpec.describe Teams::Team do
  describe "validations" do
    it "requires a name" do
      expect(described_class.new(name: "")).not_to be_valid
    end

    it "auto-assigns slug from name" do
      team = described_class.new(name: "My Team!")
      team.valid?
      expect(team.slug).to eq("my-team")
    end

    it "rejects duplicate slugs" do
      described_class.create!(name: "Acme")
      dup = described_class.new(name: "Acme")
      expect(dup).not_to be_valid
    end
  end
end
