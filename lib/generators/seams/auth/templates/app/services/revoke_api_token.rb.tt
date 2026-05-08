# frozen_string_literal: true

module Auth
  # Destroys an Auth::ApiToken row and publishes the canonical
  # api_token.revoked.auth event so subscribers (notifications,
  # audit log) can react. Returns a Result with the same shape as
  # GenerateApiToken so callers can branch uniformly.
  #
  #   result = Auth::RevokeApiToken.call(api_token: token)
  #   result.ok?      # => true
  #   result.api_token.destroyed?  # => true
  #
  # Idempotent: revoking an already-destroyed token returns an
  # ok? = false Result with code: :not_found rather than raising.
  module RevokeApiToken
    Result = Struct.new(:ok?, :api_token, :error, :code, keyword_init: true)

    module_function

    def call(api_token:)
      return Result.new(ok?: false, error: "API token not found", code: :not_found) if api_token.nil? || api_token.destroyed?

      identity      = api_token.identity
      api_token_id  = api_token.id
      token_prefix  = api_token.token_prefix
      api_token.destroy!

      Seams::Events::Publisher.publish(
        "api_token.revoked.auth",
        identity_id:  identity&.id,
        api_token_id: api_token_id,
        token_prefix: token_prefix
      )

      Result.new(ok?: true, api_token: api_token)
    end
  end
end
