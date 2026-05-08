# frozen_string_literal: true

require "accounts/version"
require "accounts/configuration"
require "accounts/engine"
require "accounts/concerns/account_scoped"
require "accounts/concerns/authorization"

module Accounts
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end
