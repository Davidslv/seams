# frozen_string_literal: true

module Auth
  # The canonical "who is logging in" record. Owns credentials
  # (password digest, OAuth links, API tokens, sessions). Lives on
  # `auth_identities` — a dedicated table so credentials are cleanly
  # separated from any host-specific User concept (a "human" can exist
  # in many hosts as the same Identity if they share a database, but
  # have different per-host User profiles).
  #
  # Other engines address the human via Identity, not via a host User.
  class Identity < ApplicationRecord
    self.table_name = "auth_identities"

    # Rails 8's has_secure_password ships the password-reset token
    # machinery: `password_reset_token` (instance method, returns a
    # signed_id with a 15-minute default expiry) and
    # `find_by_password_reset_token(token, purpose: :password_reset)`.
    # Once `Identity` has its own table the historical naming clash
    # with a `password_reset_token` *column* is gone.
    has_secure_password
    has_many :sessions,        class_name: "Auth::Session",         foreign_key: :identity_id, dependent: :destroy
    has_many :api_tokens,      class_name: "Auth::ApiToken",        foreign_key: :identity_id, dependent: :destroy
    has_many :oauth_providers, class_name: "Auth::OAuth::Provider", foreign_key: :identity_id, dependent: :destroy

    # Email is PII (GDPR Article 4). Stored encrypted at rest via Rails 7+
    # ActiveRecord::Encryption. `deterministic: true` keeps `find_by(email:)`
    # and the uniqueness index working — same plaintext yields the same
    # ciphertext. `downcase: true` normalises before encryption so two
    # casings of the same address collide as expected.
    # Host setup: bin/rails db:encryption:init (one-off).
    # See https://guides.rubyonrails.org/active_record_encryption.html
    encrypts :email, deterministic: true, downcase: true

    validates :email, presence: true, uniqueness: { case_sensitive: false }
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password,
              length: { minimum: -> { Auth.configuration.password_min_length } },
              if:     -> { password.present? }

    normalizes :email, with: ->(value) { value.to_s.strip.downcase }

    # Throwaway bcrypt hash to soak up the cost-12 ~100ms when the
    # email lookup misses. Without this, `Identity.authenticate(email: ...)`
    # returns in ~5ms for an unknown email and ~100ms for a known one
    # — a measurable timing oracle that lets attackers enumerate
    # registered identities. We pre-compute one digest at class load
    # so every miss runs the same bcrypt work.
    DUMMY_PASSWORD_DIGEST = BCrypt::Password.create("never-matches-anything", cost: BCrypt::Engine.cost).freeze

    # Returns the Identity on success, nil on failure (no such identity OR
    # wrong password). bcrypt's `#authenticate` returns `false` on
    # failure; we coerce to `nil` so callers can use a uniform
    # `if identity = Identity.authenticate(...)` idiom.
    def self.authenticate(email:, password:)
      identity = find_by(email: email.to_s.strip.downcase)
      if identity
        identity.authenticate(password) ? identity : nil
      else
        # Constant-time defence against enumeration: do the same
        # bcrypt work even on a miss, then return nil.
        BCrypt::Password.new(DUMMY_PASSWORD_DIGEST).is_password?(password.to_s)
        nil
      end
    end

    # Platform-admin predicate. Read-only convenience over the staff
    # column; host admin tooling can call `identity.staff?` to bypass
    # account-scope checks for support flows.
    def staff?
      !!staff
    end
  end
end
