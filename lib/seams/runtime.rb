# frozen_string_literal: true

module Seams
  # Module-level methods for the public Seams API. Lives in its own
  # file so that lib/seams.rb stays a thin require-only wrapper.
  module Runtime
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

  extend Runtime
end
