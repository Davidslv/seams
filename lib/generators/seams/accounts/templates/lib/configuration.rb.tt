# frozen_string_literal: true

module Accounts
  # Engine-scoped configuration. Override in
  # config/initializers/accounts.rb of the host application:
  #
  #   Accounts.configure do |c|
  #     c.incineration_grace_period = 30.days
  #     c.after_account_create_url  = "/dashboard"
  #   end
  class Configuration
    attr_accessor :incineration_grace_period,
                  :after_account_create_url

    def initialize
      # How long a cancelled account lingers before incineration (hard
      # delete). Hosts use this to power dunning + grace-period UX.
      @incineration_grace_period = 30 * 24 * 60 * 60   # 30 days
      @after_account_create_url  = "/"
    end
  end
end
