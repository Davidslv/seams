# frozen_string_literal: true

module Auth
  module OAuth
    # Links an Auth::User to an external OAuth identity (Google account,
    # GitHub account, etc.). One row per (user, provider) pair — multiple
    # rows per user means the user signed in with multiple providers,
    # and the user can be looked up via either.
    #
    # Tokens are encrypted at the database level via Rails 7+
    # ActiveRecord::Encryption. Run `bin/rails db:encryption:init` once
    # in the host to set the keys, then store them as Rails credentials
    # — see https://guides.rubyonrails.org/active_record_encryption.html.
    class Provider < ApplicationRecord
      self.table_name = "auth_oauth_providers"

      PROVIDERS = %w[google github].freeze

      belongs_to :user, class_name: "Auth::User", foreign_key: :user_id

      validates :provider,     presence: true, inclusion: { in: PROVIDERS }
      validates :provider_uid, presence: true,
                               uniqueness: { scope: :provider,
                                             message: "is already linked to another account" }
      validates :user_id,      presence: true,
                               uniqueness: { scope: :provider,
                                             message: "already linked this provider" }

      # access_token / refresh_token are credentials — encrypted with
      # the default (non-deterministic) mode for maximum strength. We
      # never query by these.
      encrypts :access_token
      encrypts :refresh_token

      # provider_uid is the user's stable id at the OAuth provider
      # (Google `sub`, GitHub user id). It IS personal data under GDPR
      # Article 4 ("online identifier"). Deterministic so the
      # (provider, provider_uid) lookup that powers OAuth sign-in keeps
      # resolving and the unique index keeps enforcing.
      encrypts :provider_uid, deterministic: true

      def access_token_expired?
        expires_at && expires_at < Time.current
      end
    end
  end
end
