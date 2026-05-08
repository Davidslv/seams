# frozen_string_literal: true

module Auth
  # Sign-in service. Validates credentials, creates a session, returns
  # a Result struct: ok?, identity, session, error.
  class AuthenticateIdentity
    Result = Struct.new(:ok?, :identity, :session, :error, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(email:, password:)
      @email    = email
      @password = password
    end

    def call
      identity = Auth::Identity.authenticate(email: @email, password: @password)
      return Result.new(ok?: false, error: "Invalid email or password") unless identity

      session = identity.sessions.create!
      Seams::Events::Publisher.publish(
        "identity.signed_in.auth",
        identity_id: identity.id,
        session_id:  session.id
      )
      Result.new(ok?: true, identity: identity, session: session)
    end
  end
end
