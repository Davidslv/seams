# frozen_string_literal: true

require "rails_helper"

RSpec.describe Core::Auditable do
  # Stub a named ActiveRecord class. The polymorphic `auditable_type`
  # column needs `self.class.name` to be non-nil; `Class.new(...)`
  # returns an anonymous class whose `.name` is nil, which breaks the
  # `dependent: :nullify` cleanup on destroy.
  before do
    stub_const("Article", Class.new(ActiveRecord::Base) {
      self.table_name = "articles"
      include Core::Auditable
    })
  end

  let(:model_class) { Article }

  it "creates an audit log on create" do
    expect { model_class.create!(title: "Hi") }
      .to change(Core::AuditLog, :count).by(1)
  end

  it "records the changed attributes on update" do
    article = model_class.create!(title: "Hi")
    expect { article.update!(title: "Bye") }
      .to change(Core::AuditLog, :count).by(1)

    last = Core::AuditLog.recent.first
    expect(last.action).to eq("update")
    expect(last.payload).to include("title" => "Bye")
  end

  it "creates an audit log on destroy" do
    article = model_class.create!(title: "Hi")
    expect { article.destroy }
      .to change(Core::AuditLog, :count).by(1)
  end
end
