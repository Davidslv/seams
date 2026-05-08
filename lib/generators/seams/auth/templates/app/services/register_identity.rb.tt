# frozen_string_literal: true

module Auth
  # Sign-up service. Creates the identity + first session in a transaction
  # and publishes identity.signed_up.auth on success.
  #
  # Returns a Result struct: ok?, identity, session, error.
  class RegisterIdentity
    Result = Struct.new(:ok?, :identity, :session, :error, keyword_init: true)

    # Whitelist of extra attributes a caller can hand in via
    # `attributes:`. Anything outside this list is dropped — closes the
    # mass-assignment hole where internal columns could be set from
    # forwarded params. Add to the list as the auth_identities schema
    # grows. NB: `staff` is intentionally NOT here — promotion is an
    # admin operation, not a sign-up surface.
    PERMITTED_EXTRA_ATTRIBUTES = %i[].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(email:, password:, password_confirmation: nil, attributes: {})
      @email                 = email
      @password              = password
      @password_confirmation = password_confirmation
      @attributes            = sanitize(attributes)
    end

    def call
      identity, session = nil
      Auth::Identity.transaction do
        identity = Auth::Identity.create!(@attributes.merge(
          email: @email, password: @password, password_confirmation: @password_confirmation
        ))
        session  = identity.sessions.create!
      end

      Seams::Events::Publisher.publish(
        "identity.signed_up.auth",
        identity_id: identity.id,
        email:       identity.email
      )
      Result.new(ok?: true, identity: identity, session: session)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok?: false, error: e.message)
    end

    private

    def sanitize(attrs)
      return {} if attrs.nil? || attrs.empty?

      attrs.to_h.transform_keys(&:to_sym).slice(*PERMITTED_EXTRA_ATTRIBUTES)
    end
  end
end
