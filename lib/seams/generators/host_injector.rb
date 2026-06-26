# frozen_string_literal: true

require "fileutils"

module Seams
  module Generators
    # Idempotent host-file edits used by every canonical generator.
    # Mix into a Rails::Generators::Base subclass; the methods below
    # delegate to Thor's inject_into_file / append_to_file primitives
    # but skip the edit if the host already contains the snippet.
    #
    # Every method is safe to call when the target file is missing —
    # it prints a yellow `skip` line so the user knows to do the edit
    # themselves later.
    module HostInjector
      def host_inject_gem(name, *args, group: nil)
        gemfile = host_path("Gemfile")
        return host_skip("Gemfile not found — add `gem #{name.inspect}` yourself") unless File.exist?(gemfile)

        return if File.read(gemfile).match?(/^\s*gem\s+["']#{Regexp.escape(name)}["']/)

        line = build_gem_line(name, args, group)
        say "  inject  Gemfile (gem \"#{name}\")", :green
        append_to_file(gemfile, "\n#{line}\n")
      end

      def host_inject_mount(engine_class:, at:)
        routes = host_path("config/routes.rb")
        unless File.exist?(routes)
          return host_skip("config/routes.rb not found — add `mount #{engine_class}, at: \"#{at}\"` yourself")
        end

        # Word-boundary match on the engine class name so a sibling
        # `mount Auth::EngineExtras` doesn't trick us into thinking
        # `Auth::Engine` is already mounted. The boundary is "anything
        # that isn't a constant-name character" (`[\w:]` excluded).
        return if File.read(routes).match?(/\bmount\s+#{Regexp.escape(engine_class)}(?![\w:])/)

        say "  inject  config/routes.rb (mount #{engine_class})", :green
        inject_into_file(routes, after: routes_draw_anchor) do
          "  mount #{engine_class}, at: \"#{at}\"\n"
        end
      end

      # Matches the common `Rails.application.routes.draw do` forms:
      # plain `do`, `do |routes|` block-arg, `do  # comment`, and the
      # rare `Rails::Application.routes.draw`.
      def routes_draw_anchor
        /Rails(?:\.application|::Application)\.routes\.draw\s+do(?:\s*\|[^|]+\|)?[^\n]*\n/
      end

      def host_inject_include_in_user(concern_name)
        host_inject_include("app/models/user.rb", "User", concern_name, label: "User model")
      end

      def host_inject_include_in_application_controller(concern_name)
        host_inject_include(
          "app/controllers/application_controller.rb", "ApplicationController",
          concern_name, label: "ApplicationController"
        )
      end

      # Reverse of host_inject_gem — used by the remove generator.
      # Removes the `gem "<name>"` line if present.
      def host_uninject_gem(name)
        gemfile = host_path("Gemfile")
        return unless File.exist?(gemfile)

        new_content = File.read(gemfile).gsub(/^\s*gem\s+["']#{Regexp.escape(name)}["'][^\n]*\n/, "")
        File.write(gemfile, new_content)
        say "  remove  Gemfile (gem \"#{name}\")", :red
      end

      def host_uninject_mount(engine_class:)
        routes = host_path("config/routes.rb")
        return unless File.exist?(routes)

        # Word-boundary match — see host_inject_mount. Without it, an
        # unrelated `mount Auth::EngineExtras` would match a remove of
        # `mount Auth::Engine` and silently delete the wrong line.
        pattern     = /^\s*mount\s+#{Regexp.escape(engine_class)}(?![\w:])[^\n]*\n/
        new_content = File.read(routes).gsub(pattern, "")
        File.write(routes, new_content)
        say "  remove  config/routes.rb (mount #{engine_class})", :red
      end

      def host_uninject_include(file_relative, concern_name)
        full = host_path(file_relative)
        return unless File.exist?(full)

        new_content = File.read(full).gsub(/^\s*include\s+#{Regexp.escape(concern_name)}\s*\n/, "")
        File.write(full, new_content)
        say "  remove  #{file_relative} (include #{concern_name})", :red
      end

      private

      def host_path(relative)
        File.join(destination_root, relative)
      end

      def host_skip(message)
        say "  skip    #{message}", :yellow
      end

      def host_inject_include(file_relative, class_name, concern_name, label:)
        full = host_path(file_relative)
        return host_skip("#{label} not found — add `include #{concern_name}` yourself") unless File.exist?(full)

        return if File.read(full).match?(/^\s*include\s+#{Regexp.escape(concern_name)}\s*$/)

        say "  inject  #{file_relative} (include #{concern_name})", :green
        inject_into_class(full, class_name, "  include #{concern_name}\n")
      end

      def build_gem_line(name, args, group)
        version_part = args.first.is_a?(String) ? %(, "#{args.first}") : ""
        gem_line     = %(gem "#{name}"#{version_part})
        # group may be a single symbol (:development) or several
        # (%i[development test] -> `group :development, :test do`).
        if group
          groups   = Array(group).map(&:inspect).join(", ")
          gem_line = "group #{groups} do\n  #{gem_line}\nend"
        end
        gem_line
      end
    end
  end
end
