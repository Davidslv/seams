# frozen_string_literal: true

# Seams configuration. Both adapters can be replaced with custom
# implementations — see https://github.com/Davidslv/seams for details.
Seams.configure do |config|
  config.event_bus_adapter      = "Seams::Events::Adapters::ActiveSupport"
  config.observability_adapter  = "Seams::Observability::Adapters::RailsLogger"
  config.host_app_name          = (Rails.application.class.module_parent_name rescue nil)
end
