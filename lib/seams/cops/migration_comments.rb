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

        # Comments that look like directives, not documentation. We strip these
        # out before deciding whether the migration carries a real doc block.
        #
        # The Parser associator already drops the encoding/shebang/frozen_string_literal
        # family of magic comments (skip_directives), so this regex only has to
        # cover the directives Parser leaves attached: Sorbet sigils, RuboCop
        # disable/enable, shareable_constant_value, warn_indent.
        MAGIC_COMMENT = /
          \A\s*\#\s*
          (?:
            frozen_string_literal
            | encoding
            | warn_indent
            | shareable_constant_value
            | typed
            | rubocop:(?:disable|enable|todo)
          )
        /x

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

        # True if the migration class is preceded by at least one comment
        # that the parser associates with this specific class node and that
        # isn't a magic comment / directive.
        #
        # We rely on `ast_with_comments` (Parser::Source::Comment.associate_by_identity)
        # rather than line-based scanning so that comments which actually
        # belong to a sibling class or method above the migration are not
        # misread as documentation for the migration.
        def leading_comment?(node)
          documenting_comments_for(node).any?
        end

        def documenting_comments_for(node)
          comments = processed_source.ast_with_comments&.fetch(node, nil) || []
          comments.reject { |comment| MAGIC_COMMENT.match?(comment.text) }
        end
      end
    end
  end
end
