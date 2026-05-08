# frozen_string_literal: true

require_relative "../rails_helper"

# End-to-end login flow: signup → signed-in session → signout.
# Lives under spec/runtime so it boots the dummy app's full Rack stack
# (routing + sessions + cookies) rather than just the model layer.
RSpec.describe "Auth login flow", type: :request do
  describe "signup → signin → signout round-trip" do
    let(:email)    { "round-trip-#{SecureRandom.hex(4)}@example.com" }
    let(:password) { "verysecret" }

    it "creates an identity, opens an Auth::Session, then revokes it on signout" do
      expect {
        post "/auth/registration",
             params: { identity: { email: email, password: password } }
      }.to change(Auth::Identity, :count).by(1)

      identity = Auth::Identity.find_by(email: email)
      expect(identity).not_to be_nil

      expect {
        post "/auth/session",
             params: { email: email, password: password }
      }.to change(Auth::Session, :count).by(1)

      session = Auth::Session.last
      expect(session.identity).to eq(identity)
      expect(session.expires_at).to be > Time.current

      delete "/auth/session"
      expect(Auth::Session.where(id: session.id)).to be_empty
    end
  end

  describe "signin with the wrong password" do
    it "does not create a session" do
      create(:auth_identity, email: "ada@example.com", password: "verysecret")

      expect {
        post "/auth/session", params: { email: "ada@example.com", password: "wrong" }
      }.not_to change(Auth::Session, :count)
    end
  end
end
