# frozen_string_literal: true

require "rails/generators"
require "seams/generators/splicer"

module Seams
  module Generators
    # Base class for follow-up generators — net-new generators that
    # extend an already-installed engine without re-templating the
    # whole engine. Subclasses look like:
    #
    #   module Seams
    #     module Generators
    #       class AddPasskeysGenerator < FollowUpGenerator
    #         engine_name "auth"
    #
    #         def add_event
    #           splice(
    #             file: "lib/auth/engine.rb",
    #             marker: "auth.engine.events",
    #             content: <<~RUBY
    #               Seams::EventRegistry.register("identity.passkey_added.auth", emitted_by: "Auth")
    #             RUBY
    #           )
    #         end
    #       end
    #     end
    #   end
    #
    # The base class supplies four primitives that every follow-up
    # generator needs:
    #
    # - +engine_path(relative)+ — resolve a path inside the host's
    #   `engines/<this_engine>/` directory.
    # - +splice(file:, marker:, content:, ...)+ — wrap
    #   +Splicer.splice_after_marker+ with a concise log line.
    # - +assert_marker_exists!(file:, marker:)+ — fail fast with a
    #   clear "this engine wasn't generated" message when a follow-up
    #   generator runs against a host that hasn't installed the
    #   target engine.
    # - +report_summary+ — template method subclasses override to
    #   print a "what just changed" message at the end.
    class FollowUpGenerator < Rails::Generators::Base
      class << self
        # Sets the engine this follow-up generator targets. Used by
        # +engine_path+ to resolve relative paths and by
        # +assert_marker_exists!+ to build the recovery hint.
        def engine_name(name = nil)
          @engine_name = name if name
          @engine_name || raise(ArgumentError,
                                "#{self.name} must declare `engine_name \"<engine>\"` " \
                                "(e.g. \"auth\") — the base class needs it to resolve " \
                                "engines/<engine>/ paths.")
        end
      end

      # The helpers below are wrapped in `no_tasks { ... }` so Thor
      # treats them as plain instance methods, not generator
      # commands. Without this wrapper, every public method becomes
      # a task and `start` blows up trying to invoke `engine_path`
      # with no arguments — and parent-class tasks invoke BEFORE
      # subclass tasks (Thor's `all_commands` orders parents first),
      # which would run `report_summary` before any of the
      # subclass's actual work.
      # The no_tasks block is naturally long — it groups every helper
      # the FollowUpGenerator surface offers (engine_path, splice,
      # assert_marker_exists!). Splitting them into separate blocks
      # would obscure the "these are the public follow-up generator
      # primitives" grouping. Disable BlockLength for this one block.
      # rubocop:disable Metrics/BlockLength
      no_tasks do
        # Resolve a path inside the host's engines/<this_engine>/.
        # Mirrors the canonical generators' +engine_path+ method but
        # reads the engine name off the class accessor instead of
        # hardcoding it per-generator.
        def engine_path(relative)
          File.join(destination_root, "engines", self.class.engine_name, relative)
        end

        # Splice `content` after `marker` in `file` (a path relative
        # to the engine root). Logs:
        #
        #   splice  engines/auth/lib/auth/engine.rb @ auth.engine.events
        #
        # When `before:` is true, splices BEFORE the marker line instead.
        # Returns the underlying +Splicer::Result+ so subclasses can
        # branch on `result.ok?` if they want.
        def splice(file:, marker:, content:, before: false, indent: nil)
          full_path = engine_path(file)
          result =
            if before
              Splicer.splice_before_marker(file_path: full_path, marker: marker, content: content, indent: indent)
            else
              Splicer.splice_after_marker(file_path: full_path, marker: marker, content: content, indent: indent)
            end

          if result.ok?
            status = result.lines_added.zero? ? "exists" : "splice"
            say "  #{status}  engines/#{self.class.engine_name}/#{file} @ #{marker}", :green
          else
            say "  error   #{result.error}", :red
          end
          result
        end

        # Raise a clear, actionable error if the marker isn't present.
        # The most common cause is the host hasn't generated the target
        # engine yet (or generated it from a pre-Wave-10 version of seams
        # that didn't ship insertion points). Both cases get a single
        # recovery hint: re-run the canonical generator.
        def assert_marker_exists!(file:, marker:)
          full_path = engine_path(file)
          return if Splicer.find_marker(file_path: full_path, marker: marker)

          engine = self.class.engine_name
          raise Seams::GeneratorError, <<~MSG.chomp
            [seams] cannot run #{self.class.name}: insertion-point marker
              "#{marker}"
            was not found in
              engines/#{engine}/#{file}

            Either this engine wasn't generated, or it was generated by
            a pre-Wave-10 version of seams that didn't ship insertion
            points. Run:

              bin/rails generate seams:#{engine}

            to (re)generate the engine with the current marker set, then
            re-run this follow-up generator.
          MSG
        end
      end
      # rubocop:enable Metrics/BlockLength

      # Subclass override-point. Subclasses define their own public
      # method named `report_summary` (or any other end-of-run name);
      # Thor invokes it as the last task because public methods on the
      # subclass come after the parent's `no_tasks`-wrapped helpers
      # in declaration order. The base-class default is a no-op,
      # wrapped in `no_tasks` so it doesn't pre-empt subclass output.
      no_tasks do
        def report_summary
          # Override in subclasses.
        end
      end
    end
  end
end
