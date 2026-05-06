# frozen_string_literal: true

require "seams/version"
require "seams/configuration"

# Seams — A CLI framework that generates modular Rails engines.
#
# See https://github.com/Davidslv/seams for documentation.
module Seams
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class GeneratorError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
