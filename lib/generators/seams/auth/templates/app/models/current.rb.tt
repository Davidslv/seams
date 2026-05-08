# frozen_string_literal: true

module Auth
  # ActiveSupport::CurrentAttributes namespace for the Auth engine.
  # Set once per request by the Authentication concern; readable from
  # anywhere downstream (services, models, jobs that re-resolve via
  # the same controller stack) without explicit threading.
  #
  # Wave 9 Phase 1a only sets `identity`. Phase 1b will add
  # `Current.account`; Phase 2 will add `Current.user` (the account
  # membership, NOT a host User).
  class Current < ActiveSupport::CurrentAttributes
    attribute :identity
  end
end
