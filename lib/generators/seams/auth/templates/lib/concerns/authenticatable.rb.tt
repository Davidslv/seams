# frozen_string_literal: true

require "active_support/concern"

module Auth
  # Concern that the host application's user-facing model can include
  # to gain Auth-engine sign-in tracking, password helpers, and
  # session-aware queries. Listed in this engine's ExposedConcerns so
  # cross-engine boundary cops do not flag callers.
  module Authenticatable
    extend ActiveSupport::Concern

    included do
      has_one :auth_user, class_name: "Auth::User", foreign_key: :host_user_id, dependent: :destroy
    end

    def signed_in?
      auth_user&.sessions&.active&.exists?
    end

    def sign_out_everywhere!
      auth_user&.sessions&.destroy_all
    end
  end
end
