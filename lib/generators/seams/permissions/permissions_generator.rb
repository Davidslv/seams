# frozen_string_literal: true

require "rails/generators"
require "seams"
require "seams/permissions"
require "seams/generators/host_injector"
require "seams/generators/eject_aware"

module Seams
  module Generators
    # Writes ONE host-editable initializer that spells out the default
    # role -> ability grant map and assigns it through
    # `Seams.configure { |c| c.permission_grants = {...} }`.
    #
    # This is the deferred-friendly seam of the permissions layer (Wave
    # 11B / issue #37): there is no database table and no YAML DSL — a
    # host changes who-can-do-what by editing this one Ruby file. The
    # generated map is a readable copy of Seams::Permissions::DEFAULT_GRANTS
    # rendered at generate time, so the host starts from the same defaults
    # the gem ships and edits from there.
    #
    # The catalog of ability CODES is engine-owned: each engine registers
    # the `resource.action.engine` codes it understands from its engine.rb
    # (mirroring the event bus). This file only decides which ROLES hold
    # which already-registered codes. Referencing a code no engine has
    # registered makes `Seams::Permissions.can?` raise — deny-by-default,
    # loudly.
    #
    # Run with: bin/seams permissions   (or bin/rails generate seams:permissions)
    class PermissionsGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector
      include Seams::Generators::EjectAware

      source_root File.expand_path("templates", __dir__)

      INITIALIZER_RELATIVE = "config/initializers/seams_permissions.rb"

      # The single deliverable: the host-editable grant map. Eject-aware
      # so a host that has stamped the eject header (to fully own the file
      # and never be prompted again) keeps their version on a re-run.
      def create_initializer
        template_unless_ejected "config/initializers/seams_permissions.rb.tt",
                                host_path(INITIALIZER_RELATIVE)
      end

      def report_summary
        say report_summary_text, :green
      end

      def report_summary_text
        <<~TXT

          Permissions grant map generated at #{INITIALIZER_RELATIVE}

          Next steps:
            1. Edit the role -> ability map in
                 #{INITIALIZER_RELATIVE}
               Each role lists the registered ability codes it holds. Roles
               inherit downward (owner inherits admin inherits member), so a
               code only needs to appear at the lowest role that should hold it.

            2. List the ability codes every installed engine registers:
                 bin/rails runner 'pp Seams::PermissionRegistry.all'
               You can only grant codes that appear there — `can?` raises on
               an unregistered code (deny-by-default, loudly).

            3. Guard a controller action with a code:
                 before_action -> { authorize_permission!("invoice.read.billing") }

          To fully own this file (skip it on future generator runs):
            bin/seams resolve --eject (or add the `# seams:ejected from` header).

          See doc/PERMISSIONS.md for the model, the role hierarchy, the bypass
          tiers, and what is deliberately deferred (YAML DSL, DB custom roles,
          per-ability grants).

        TXT
      end

      private

      # A readable Ruby literal for the default grant map, rendered from
      # Seams::Permissions::DEFAULT_GRANTS so the generated file always
      # matches the gem's shipped defaults. Each role becomes a
      # `"role" => %w[...]` block (4-space indent), one ability code per
      # line (6-space indent), so it sits cleanly inside the
      # `config.permission_grants = {` hash in the template. Entries are
      # joined with a trailing comma + newline.
      def grant_map_body
        Seams::Permissions::DEFAULT_GRANTS.map do |role, abilities|
          codes = abilities.map { |code| "      #{code}" }.join("\n")
          %(    "#{role}" => %w[\n#{codes}\n    ])
        end.join(",\n")
      end
    end
  end
end
