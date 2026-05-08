# frozen_string_literal: true

module Auth
  # Two-phase password reset, backed by Rails 8's built-in
  # `has_secure_password` reset_token feature. The token is a signed_id
  # with a built-in 15-minute expiry — no column, no sweep job, no
  # `password_reset_token_sent_at` needed.
  #
  #   Auth::ResetPassword.request(email: "x@y.com")
  #     → looks up the identity, generates a signed_id token, emails it
  #
  #   Auth::ResetPassword.complete(token: "...", new_password: "...")
  #     → finds the identity by signed_id (Rails verifies expiry +
  #       purpose), updates the password
  #
  # Both phases return a Result struct so the controller has a uniform
  # success/failure shape regardless of which phase failed.
  module ResetPassword
    Result = Struct.new(:ok?, :identity, :error, keyword_init: true)

    module_function

    def request(email:)
      identity = Auth::Identity.find_by(email: email.to_s.strip.downcase)
      return Result.new(ok?: true) unless identity # don't leak which emails are registered

      Auth::PasswordsMailer.reset_email(identity).deliver_later
      Result.new(ok?: true, identity: identity)
    end

    def complete(token:, new_password:)
      identity = Auth::Identity.find_by_password_reset_token(token)
      return Result.new(ok?: false, error: "Invalid or expired reset link") unless identity

      identity.update!(password: new_password)
      Result.new(ok?: true, identity: identity)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok?: false, error: e.message)
    end
  end
end
