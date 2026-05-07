# frozen_string_literal: true

require "rails_helper"

RSpec.describe Core::AuditLog do
  it "rejects unknown actions" do
    log = described_class.new(action: "made_up", auditable_type: "Article", auditable_id: 1)
    expect(log).not_to be_valid
  end

  describe ".for" do
    it "filters audit logs to a specific record" do
      article = double(class: double(name: "Article"), id: 7)
      described_class.create!(action: "create", auditable_type: "Article", auditable_id: 7)
      described_class.create!(action: "create", auditable_type: "Article", auditable_id: 8)

      expect(described_class.for(article).pluck(:auditable_id)).to eq([7])
    end
  end
end
