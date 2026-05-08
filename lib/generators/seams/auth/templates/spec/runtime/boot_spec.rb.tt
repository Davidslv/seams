# frozen_string_literal: true

require_relative "../rails_helper"

RSpec.describe "Auth engine boot", type: :integration do
  it "loads the engine" do
    expect(defined?(Auth::Engine)).to eq("constant")
  end

  it "registers the four canonical auth events" do
    %w[identity.signed_up.auth identity.signed_in.auth identity.signed_out.auth session.expired.auth].each do |event|
      expect(Seams::EventRegistry.registered?(event)).to be(true)
    end
  end

  it "creates the auth tables from the dummy schema" do
    expect(ActiveRecord::Base.connection.table_exists?(:auth_identities)).to be(true)
    expect(ActiveRecord::Base.connection.table_exists?(:auth_sessions)).to   be(true)
  end

  it "exposes the canonical concerns + service objects + Configuration" do
    expect(defined?(Auth::Authenticatable)).to       eq("constant")
    expect(defined?(Auth::Authentication)).to        eq("constant")
    expect(defined?(Auth::RegisterIdentity)).to      eq("constant")
    expect(defined?(Auth::AuthenticateIdentity)).to  eq("constant")
    expect(defined?(Auth::ResetPassword)).to         eq("constant")
    expect(defined?(Auth::Configuration)).to         eq("constant")
    expect(defined?(Auth::Current)).to               eq("constant")
  end
end
