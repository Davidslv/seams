# frozen_string_literal: true

module Auth
  # Sign-up service. Creates the user + first session in a transaction
  # and publishes user.signed_up.auth on success.
  #
  # Returns a Result struct: ok?, user, session, error.
  class RegisterUser
    Result = Struct.new(:ok?, :user, :session, :error, keyword_init: true)

    # Whitelist of extra attributes a caller can hand in via
    # `attributes:`. Anything outside this list is dropped — closes the
    # mass-assignment hole where `host_user_id`, `password_reset_token`
    # etc. could be set from forwarded params. Add to the list as the
    # auth_users schema grows.
    PERMITTED_EXTRA_ATTRIBUTES = %i[host_user_id].freeze

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
      user, session = nil
      Auth::User.transaction do
        user    = Auth::User.create!(@attributes.merge(
          email: @email, password: @password, password_confirmation: @password_confirmation
        ))
        session = user.sessions.create!
      end

      # `auth_user_id` is the id of the Auth::User row; `host_user_id`
      # is the host application's user id (may be nil if the host
      # hasn't linked the auth record to its own User yet). Subscribers
      # that look up host models should always use `host_user_id`.
      Seams::Events::Publisher.publish(
        "user.signed_up.auth",
        auth_user_id: user.id,
        host_user_id: user.host_user_id,
        email: user.email
      )
      Result.new(ok?: true, user: user, session: session)
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
