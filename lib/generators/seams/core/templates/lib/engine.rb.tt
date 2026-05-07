# frozen_string_literal: true

module Core
  class Engine < ::Rails::Engine
    isolate_namespace Core

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "core.register_events" do
      Seams::EventRegistry.register("record.audited.core", emitted_by: "Core")
    end

    initializer "core.append_migrations" do |app|
      unless app.root == root
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
