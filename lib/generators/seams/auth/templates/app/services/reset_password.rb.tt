# frozen_string_literal: true

module Auth
  # Two-phase password reset.
  #
  #   Auth::ResetPassword.request(email: "x@y.com")
  #     → looks up the user, generates a token, sends the email
  #
  #   Auth::ResetPassword.complete(token: "...", new_password: "...")
  #     → validates the token (not nil + not expired), updates the
  #       password, clears the token
  #
  # Both phases return a Result struct so the controller has a uniform
  # success/failure shape regardless of which phase failed.
  module ResetPassword
    Result = Struct.new(:ok?, :user, :error, keyword_init: true)

    TOKEN_TTL = 30 * 60 # 30 minutes, in seconds

    module_function

    def request(email:)
      user = Auth::User.find_by(email: email.to_s.strip.downcase)
      return Result.new(ok?: true) unless user # don't leak which emails are registered

      user.update!(
        password_reset_token: SecureRandom.urlsafe_base64(32),
        password_reset_token_sent_at: Time.current
      )

      Auth::PasswordsMailer.reset_email(user).deliver_later
      Result.new(ok?: true, user: user)
    end

    def complete(token:, new_password:)
      user = Auth::User.find_by(password_reset_token: token)
      return Result.new(ok?: false, error: "Invalid or expired reset link") unless user
      return Result.new(ok?: false, error: "Reset link expired")           if expired?(user)

      user.update!(
        password: new_password,
        password_reset_token: nil,
        password_reset_token_sent_at: nil
      )
      Result.new(ok?: true, user: user)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok?: false, error: e.message)
    end

    def expired?(user)
      return true if user.password_reset_token_sent_at.nil?

      user.password_reset_token_sent_at < TOKEN_TTL.seconds.ago
    end
  end
end
