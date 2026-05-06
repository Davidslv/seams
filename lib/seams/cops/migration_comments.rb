# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Seams
      # Requires every migration to start with a leading comment block
      # so that future readers know what the migration does, why it was
      # needed, and what its data/downtime implications are.
      class MigrationComments < Base
        MSG = "Migration `%<name>s` must be preceded by a comment block explaining " \
              "what changes and why (data implications, downtime risk, rollback notes)."

        # @!method migration_class?(node)
        def_node_matcher :migration_class?, <<~PATTERN
          (class (const nil? $_) (send (const (const _ :ActiveRecord) :Migration) :[] _) ...)
        PATTERN

        def on_class(node)
          name = migration_class?(node)
          return unless name
          return if leading_comment?(node)

          add_offense(node, message: format(MSG, name: name))
        end

        private

        def leading_comment?(node)
          start_line = node.loc.line
          processed_source.comments.any? { |c| c.loc.line == start_line - 1 }
        end
      end
    end
  end
end
