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

        MAGIC_COMMENT = /\A\s*#\s*(frozen_string_literal|encoding|warn_indent|shareable_constant_value)/

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

        # Returns true if at least one non-magic comment line precedes
        # the class. Magic comments (frozen_string_literal, encoding,
        # etc.) and blank lines between them and the class are ignored
        # so the cop doesn't fire on properly-documented migrations
        # whose first line is `# frozen_string_literal: true`.
        def leading_comment?(node)
          documenting_comments_above(node.loc.line).any?
        end

        def documenting_comments_above(class_line)
          comment_lines = processed_source.comments.to_set { |c| c.loc.line }
          (1...class_line)
            .select  { |l| comment_lines.include?(l) }
            .reject  { |l| magic_comment_line?(l) }
        end

        def magic_comment_line?(line)
          processed_source.lines[line - 1].to_s.match?(MAGIC_COMMENT)
        end
      end
    end
  end
end
