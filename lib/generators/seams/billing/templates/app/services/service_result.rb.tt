# frozen_string_literal: true

module Billing
  # Uniform return shape for every Billing service object. Services
  # return `Billing::ServiceResult.ok(value: ...)` or
  # `Billing::ServiceResult.failure(error: ..., code: ...)` so callers
  # can branch on `result.ok?` without each service inventing its own
  # contract.
  #
  #   result = Billing::Subscriptions::CancelService.call(subscription_ref: "sub_X")
  #   if result.ok?
  #     redirect_to billing_root_path, notice: "Cancelled"
  #   else
  #     flash[:alert] = result.error
  #     redirect_back(fallback_location: billing_root_path)
  #   end
  #
  # `code:` is an optional machine-readable tag (`:not_found`,
  # `:gateway_error`, `:already_cancelled`, etc.) that callers can
  # branch on without parsing the human message in `error:`.
  ServiceResult = Struct.new(:ok, :value, :error, :code, keyword_init: true) do
    def self.ok(value: nil)
      new(ok: true, value: value)
    end

    def self.failure(error:, code: nil)
      new(ok: false, error: error, code: code)
    end

    def ok?
      ok == true
    end

    def failure?
      !ok?
    end
  end
end
