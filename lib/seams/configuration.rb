# frozen_string_literal: true

module Seams
  # Global Seams configuration. Set via Seams.configure { |c| ... } in
  # config/initializers/seams.rb of the host application.
  class Configuration
    attr_accessor :event_bus_adapter,
                  :observability_adapter,
                  :event_namespace_separator,
                  :host_app_name,
                  :permission_grants

    def initialize
      @event_bus_adapter = "Seams::Events::Adapters::ActiveSupport"
      @observability_adapter = "Seams::Observability::Adapters::RailsLogger"
      @event_namespace_separator = "."
      @host_app_name = nil
      @permission_grants = {}
    end
  end
end
