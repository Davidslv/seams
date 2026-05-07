# frozen_string_literal: true

module Auth
  class PasswordsMailer < ::ApplicationMailer
    def reset_email(user)
      @user  = user
      @token = user.password_reset_token
      mail(to: user.email, subject: "Reset your password")
    end
  end
end
