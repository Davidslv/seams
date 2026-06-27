# frozen_string_literal: true

require "seams/version"

# Seams — A CLI framework that generates modular Rails engines.
#
# See https://github.com/Davidslv/seams for documentation.
module Seams
  # Base class for all Seams errors.
  class Error < StandardError; end

  # Raised when Seams is misconfigured (e.g. an adapter class can't be loaded).
  class ConfigurationError < Error; end

  # Raised when a generator hits an unrecoverable problem.
  class GeneratorError < Error; end
end

require "seams/configuration"
require "seams/runtime"
require "seams/events"
require "seams/events/adapter"
require "seams/events/adapters/active_support"
require "seams/event_registry"
require "seams/permissions"
require "seams/permission_registry"
require "seams/events/publisher"
require "seams/observability"
require "seams/observability/adapter"
require "seams/observability/adapters/rails_logger"
