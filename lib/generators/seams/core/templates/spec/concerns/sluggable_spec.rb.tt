# frozen_string_literal: true

require "rails_helper"

RSpec.describe Core::Sluggable do
  let(:model_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = "teams"
      include Core::Sluggable
      sluggable_from :name
    end
  end

  it "auto-assigns a slug from the source attribute" do
    record = model_class.create!(name: "Acme Corp!")
    expect(record.slug).to eq("acme-corp")
  end

  it "appends a numeric suffix on collision" do
    model_class.create!(name: "Acme")
    second = model_class.create!(name: "Acme")
    expect(second.slug).to eq("acme-2")
  end

  it "respects an explicitly-set slug" do
    record = model_class.create!(name: "Whatever", slug: "my-custom")
    expect(record.slug).to eq("my-custom")
  end
end
