# frozen_string_literal: true

require_relative "../rails_helper"

# End-to-end login flow: signup → signed-in session → signout.
# Lives under spec/runtime so it boots the dummy app's full Rack stack
# (routing + sessions + cookies) rather than just the model layer.
RSpec.describe "Auth login flow", type: :request do
  describe "signup → signin → signout round-trip" do
    let(:email)    { "round-trip-#{SecureRandom.hex(4)}@example.com" }
    let(:password) { "verysecret" }

    it "creates a user, opens an Auth::Session, then revokes it on signout" do
      expect {
        post "/auth/registration",
             params: { user: { email: email, password: password } }
      }.to change(Auth::User, :count).by(1)

      user = Auth::User.find_by(email: email)
      expect(user).not_to be_nil

      expect {
        post "/auth/session",
             params: { email: email, password: password }
      }.to change(Auth::Session, :count).by(1)

      session = Auth::Session.last
      expect(session.user).to eq(user)
      expect(session.expires_at).to be > Time.current

      delete "/auth/session"
      expect(Auth::Session.where(id: session.id)).to be_empty
    end
  end

  describe "signin with the wrong password" do
    it "does not create a session" do
      create(:auth_user, email: "ada@example.com", password: "verysecret")

      expect {
        post "/auth/session", params: { email: "ada@example.com", password: "wrong" }
      }.not_to change(Auth::Session, :count)
    end
  end
end
