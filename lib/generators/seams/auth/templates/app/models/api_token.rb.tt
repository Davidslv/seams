# frozen_string_literal: true

require "digest"
require "securerandom"

module Auth
  # Bearer-style API token. Issued to a user, presented in the
  # Authorization header by API clients.
  #
  # Storage: only a SHA-256 hash of the token lives in the DB —
  # `token_digest`. The plaintext (`token`) is shown ONCE, at
  # creation time, via the GenerateApiToken service. If the user
  # loses it they must rotate; we cannot recover it.
  #
  # `token_prefix` is the first few characters of the plaintext, kept
  # in the DB for identification in dashboards / audit logs without
  # exposing the secret. Format: `seam_<8 random chars>` so it's
  # easy to grep for.
  #
  # Optional `expires_at`. Optional `last_used_at` for activity
  # tracking. `name` lets the user label the token ("CI deploy key",
  # "iPhone shortcut").
  class ApiToken < ApplicationRecord
    self.table_name = "auth_api_tokens"

    PREFIX           = "seam_"
    PLAINTEXT_LENGTH = 32  # bytes → 43 chars urlsafe-base64
    PREFIX_DISPLAY   = 12  # chars stored in token_prefix

    belongs_to :user, class_name: "Auth::User", foreign_key: :user_id

    validates :token_digest, presence: true, uniqueness: true
    validates :token_prefix, presence: true
    validates :name,         presence: true

    scope :active,  -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
    scope :expired, -> { where(expires_at: ..Time.current) }

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    def touch_last_used!
      update_column(:last_used_at, Time.current)  # rubocop:disable Rails/SkipsModelValidations
    end

    # Hash a plaintext token the same way #find_by_plaintext does, so
    # callers can verify a candidate token without exposing the digest.
    def self.digest(plaintext)
      Digest::SHA256.hexdigest(plaintext.to_s)
    end

    # Returns the ApiToken matching the plaintext, or nil. Does NOT
    # touch last_used_at — callers do that explicitly so a passive
    # presence check doesn't bump the timestamp.
    def self.find_by_plaintext(plaintext)
      return nil if plaintext.to_s.empty?

      find_by(token_digest: digest(plaintext))
    end
  end
end
