# frozen_string_literal: true

# Load every engine under engines/ as if it were a Gemfile entry. Must
# run before Rails.application.initialize! so each engine's Railtie
# registers its initializers + paths (db/migrate, app/*) with the host.
# Required from config/application.rb after Bundler.require.
Dir[File.expand_path("../engines/*", __dir__)].sort.each do |engine_path|
  next unless File.directory?(engine_path)

  $LOAD_PATH.unshift File.join(engine_path, "lib")

  engine_name = File.basename(engine_path)
  main = File.join(engine_path, "lib", "#{engine_name}.rb")
  require engine_name if File.exist?(main)
end
