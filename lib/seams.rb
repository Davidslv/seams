# frozen_string_literal: true

require "seams/version"

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
      Events::Publisher.reset!     if defined?(Events::Publisher)
      Observability.reset!         if defined?(Observability)
    end
  end
end

require "seams/configuration"
require "seams/events"
require "seams/events/adapter"
require "seams/events/adapters/active_support"
require "seams/event_registry"
require "seams/events/publisher"
require "seams/observability"
require "seams/observability/adapter"
require "seams/observability/adapters/rails_logger"
