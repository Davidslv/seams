# frozen_string_literal: true

module Auth
  class PasswordsMailer < ::ApplicationMailer
    def reset_email(identity)
      @identity = identity
      # Rails 8 has_secure_password defines `password_reset_token` —
      # a signed_id with a 15-minute default expiry. The mailer is
      # responsible for calling it (so the token is generated as
      # late as possible to maximise validity).
      @token    = identity.password_reset_token
      mail(to: identity.email, subject: "Reset your password")
    end
  end
end
