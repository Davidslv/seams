# frozen_string_literal: true

require "seams/permissions"

module Seams
  # Global Seams configuration. Set via Seams.configure { |c| ... } in
  # config/initializers/seams.rb of the host application.
  #
  # @example
  #   Seams.configure do |c|
  #     c.host_app_name = "Acme"
  #     c.event_bus_adapter = "MyApp::Events::SidekiqAdapter"
  #   end
  class Configuration
    # @!attribute [rw] event_bus_adapter
    #   @return [String] class name of the event-bus adapter (default
    #     "Seams::Events::Adapters::ActiveSupport").
    # @!attribute [rw] observability_adapter
    #   @return [String] class name of the observability adapter (default
    #     "Seams::Observability::Adapters::RailsLogger").
    # @!attribute [rw] event_namespace_separator
    #   @return [String] separator between event-name segments (default ".").
    # @!attribute [rw] host_app_name
    #   @return [String, nil] the host application's name, for reporting.
    # @!attribute [rw] permission_grants
    #   @return [Hash] the role -> ability grant map (default
    #     {Seams::Permissions::DEFAULT_GRANTS}).
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
      @permission_grants = Seams::Permissions::DEFAULT_GRANTS
    end
  end
end
