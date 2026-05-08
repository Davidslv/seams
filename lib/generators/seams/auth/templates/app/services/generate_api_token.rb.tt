# frozen_string_literal: true

require "securerandom"

module Auth
  # Issues a new API token for an identity. Returns a Result with both
  # the persisted ApiToken row AND the plaintext (which is the only
  # time it's available — the DB only stores the digest).
  module GenerateApiToken
    Result = Struct.new(:ok?, :api_token, :plaintext, :error, keyword_init: true)

    module_function

    def call(identity:, name:, expires_at: nil)
      plaintext = "#{ApiToken::PREFIX}#{SecureRandom.urlsafe_base64(ApiToken::PLAINTEXT_LENGTH)}"
      record = identity.api_tokens.create!(
        name:         name,
        token_digest: ApiToken.digest(plaintext),
        token_prefix: plaintext[0, ApiToken::PREFIX_DISPLAY],
        expires_at:   expires_at
      )

      Seams::Events::Publisher.publish(
        "api_token.issued.auth",
        identity_id:  identity.id,
        api_token_id: record.id,
        token_prefix: record.token_prefix
      )

      Result.new(ok?: true, api_token: record, plaintext: plaintext)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok?: false, error: e.message)
    end
  end
end
