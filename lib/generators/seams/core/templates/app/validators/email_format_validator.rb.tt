# frozen_string_literal: true

module Core
  # ActiveModel validator. Use as `validates :email, "core/email_format": true`
  # or via the convenience: `validates :email, email_format: true` (Rails
  # auto-discovers `EmailFormatValidator`).
  #
  # Stricter than URI::MailTo::EMAIL_REGEXP — also rejects consecutive
  # dots, leading/trailing dots in the local part, and trailing dots
  # in the domain.
  class EmailFormatValidator < ActiveModel::EachValidator
    PATTERN = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/

    def validate_each(record, attribute, value)
      return if value.blank?

      record.errors.add(attribute, :invalid) unless PATTERN.match?(value.to_s)
      record.errors.add(attribute, :invalid) if value.to_s.include?("..")
    end
  end
end
