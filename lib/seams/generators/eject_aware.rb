# frozen_string_literal: true

module Seams
  module Generators
    # Mixin that lets a canonical engine generator (auth, accounts,
    # billing, core, notifications, teams) cooperate with the
    # `bin/seams resolve --eject` CLI introduced in Wave 10 Phase 2B.
    #
    # The contract is one-way: ejection happens in the host's working
    # tree (the CLI prepends a `# seams:ejected from <engine>.<path>`
    # header to a file the host wants to own). This module gives the
    # generator the matching skip behaviour — when the destination
    # file already starts with that header, the generator's
    # `template_unless_ejected` helper logs a yellow "skip" line and
    # leaves the file untouched.
    #
    # ## Eject-eligibility rule
    #
    # The CLI and this helper agree on a single eligibility rule:
    #
    # - Eligible: every templated file under `app/` and `lib/` and
    #   `config/` (controllers, models, services, jobs, mailers,
    #   views, concerns, lib classes, configuration.rb, routes.rb).
    #   These are pieces a host might reasonably want to own outright
    #   — to override behaviour, change copy, swap a layout, etc.
    # - Eligible: spec files (spec/) and factories. The host owns
    #   the regenerated specs the same way the host owns the engine
    #   code; ejecting a spec is rare but legal.
    # - INELIGIBLE: migrations under `db/migrate/`. Migrations run
    #   exactly once on a host's timetable; ejecting a migration is
    #   meaningless (it's already been run) and re-running the
    #   generator never overwrites an existing migration anyway —
    #   each run produces a new timestamp.
    # - INELIGIBLE: framework-managed engine boot files —
    #   `lib/<engine>/engine.rb`, `lib/<engine>/version.rb`, the
    #   engine's Gemfile and gemspec. These are the contract between
    #   the engine and the host's Rails boot; if the host wants
    #   different behaviour they extend via insertion points or a
    #   follow-up generator.
    #
    # The CLI enforces this rule at eject time. The
    # `template_unless_ejected` helper is intentionally permissive —
    # if a host has somehow stamped the eject header onto a
    # framework-managed file, we skip rather than overwrite. The
    # error path is loud at eject, not at generation.
    #
    # ## Usage
    #
    # In an engine generator:
    #
    #   class AuthGenerator < Rails::Generators::Base
    #     include Seams::Generators::EjectAware
    #
    #     def create_models
    #       template_unless_ejected "app/models/identity.rb.tt",
    #                               engine_path("app/models/auth/identity.rb")
    #     end
    #   end
    #
    # `template_unless_ejected` accepts the same positional + keyword
    # arguments as Thor's `template`, including `force: true`, so
    # generators can adopt it incrementally without changing call sites.
    module EjectAware
      EJECT_HEADER_PREFIX = "# seams:ejected from"

      # Drop-in replacement for Thor's `template`. If the destination
      # exists and starts with the eject header, log a `skip` line and
      # return without writing. Otherwise delegate to `template` —
      # Thor handles `force: true` and conflict resolution as usual.
      def template_unless_ejected(source, *args, **)
        destination = args.first
        if destination && File.exist?(destination) && ejected?(destination)
          say_status :skip, ejected_say_message(destination), :yellow
          return
        end

        template(source, *args, **)
      end

      # True when the file at `path` carries the eject header on its
      # first line. Reads only the first 200 bytes — the header sits
      # at the very top and we don't want to slurp megabytes for files
      # under app/views/.
      def ejected?(path)
        return false unless File.exist?(path)

        File.read(path, 200).to_s.start_with?(EJECT_HEADER_PREFIX)
      end

      private

      def ejected_say_message(destination)
        if respond_to?(:destination_root)
          relative = destination.sub(%r{\A#{Regexp.escape(destination_root.to_s)}/?},
                                     "")
        end
        relative ||= destination
        "#{relative} (ejected — kept host version)"
      end
    end
  end
end
