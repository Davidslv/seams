# frozen_string_literal: true

require_relative "../rails_helper"

# Pins the event payload contract for the four identity.* events.
# Subscribers in other engines (notifications etc.) depend on
# identity_id being present.
RSpec.describe "Auth event payloads", type: :integration do
  let(:captured) { [] }

  before do
    @sub = Seams::Events::Publisher.adapter.subscribe("identity.signed_up.auth") do |*args|
      captured << args.last
    end
  end

  after { Seams::Events::Publisher.adapter.unsubscribe(@sub) if @sub }

  it "identity.signed_up.auth carries identity_id and email" do
    Auth::RegisterIdentity.call(
      email: "ada-#{SecureRandom.hex(4)}@example.com",
      password: "verysecret"
    )

    payload = captured.last
    expect(payload).to include(:identity_id, :email)
    expect(payload[:identity_id]).to be_a(Integer)
  end
end
