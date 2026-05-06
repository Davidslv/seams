# frozen_string_literal: true

require "rails/generators"

module Seams
  module Generators
    # Adds the Seams framework to a host Rails application:
    #
    #   - config/initializers/seams.rb        (configure adapters)
    #   - config/initializers/seams_engines.rb (load engines/* into autoload)
    #   - engines/.keep                       (where future engines live)
    #   - lib/tasks/seams.rake                (rake namespace)
    #
    # Run with: bin/rails generate seams:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer
        template "seams.rb.tt", "config/initializers/seams.rb"
      end

      def create_engines_directory
        empty_directory "engines"
        create_file "engines/.keep"
      end

      def create_rake_tasks
        template "seams.rake.tt", "lib/tasks/seams.rake"
      end

      def append_engines_to_eager_load
        template "seams_engines.rb.tt", "config/initializers/seams_engines.rb"
      end

      def post_install_message
        say ""
        say "  Seams is installed. Generate your first engine with:", :green
        say "    bin/rails generate seams:engine core"
        say ""
      end
    end
  end
end
