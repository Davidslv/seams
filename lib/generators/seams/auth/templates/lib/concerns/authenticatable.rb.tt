# frozen_string_literal: true

require "active_support/concern"

module Auth
  # Concern that the host application's user-facing model can include
  # to gain Auth-engine sign-in tracking, password helpers, and
  # session-aware queries. Listed in this engine's ExposedConcerns so
  # cross-engine boundary cops do not flag callers.
  #
  # OPTIONAL after Wave 9. Most hosts won't need it because
  # `Auth::Identity` is now the canonical "human" record — sessions
  # belong to Identity, not to a host User. Hosts that DO keep a
  # separate User model (e.g. for domain-specific profile fields) and
  # want the sugar can include this concern, but the host User must
  # have an `identity_id` column and the host wires the link itself.
  module Authenticatable
    extend ActiveSupport::Concern

    included do
      belongs_to :auth_identity, class_name: "Auth::Identity", foreign_key: :identity_id, optional: true
    end

    def signed_in?
      auth_identity&.sessions&.active&.exists?
    end

    def sign_out_everywhere!
      auth_identity&.sessions&.destroy_all
    end
  end
end
