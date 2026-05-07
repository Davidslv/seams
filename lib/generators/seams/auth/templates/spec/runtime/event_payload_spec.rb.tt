# frozen_string_literal: true

require_relative "../rails_helper"

# Pins the event payload contract for the four user.* events. Other
# engines' subscribers depend on host_user_id being present alongside
# auth_user_id — see Notifications::AuthSubscriber.
RSpec.describe "Auth event payloads", type: :integration do
  let(:captured) { [] }

  before do
    @sub = Seams::Events::Publisher.adapter.subscribe("user.signed_up.auth") do |*args|
      captured << args.last
    end
  end

  after { Seams::Events::Publisher.adapter.unsubscribe(@sub) if @sub }

  it "user.signed_up.auth carries auth_user_id, host_user_id, and email" do
    Auth::RegisterUser.call(
      email: "ada-#{SecureRandom.hex(4)}@example.com",
      password: "verysecret",
      attributes: { host_user_id: 4242 }
    )

    payload = captured.last
    expect(payload).to include(:auth_user_id, :host_user_id, :email)
    expect(payload[:auth_user_id]).to be_a(Integer)
    expect(payload[:host_user_id]).to eq(4242)
  end

  it "host_user_id is nil when the auth user isn't linked to a host record" do
    Auth::RegisterUser.call(email: "lone-#{SecureRandom.hex(4)}@example.com", password: "verysecret")
    expect(captured.last[:host_user_id]).to be_nil
  end
end
