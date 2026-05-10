# frozen_string_literal: true

require "fileutils"

module Seams
  module Generators
    # Idempotent splice operations against files containing
    # `# seams:insertion-point <name>` markers. Wave 10 introduces
    # follow-up generators (e.g. `seams:auth:add_oauth_provider`) that
    # need to extend already-generated engines without re-templating
    # the whole file. The Splicer is the shared primitive: every
    # follow-up generator funnels through these methods.
    #
    # See doc/INSERTION_POINTS.md for the marker format spec and
    # doc/INSERTION_POINTS_CATALOGUE.md for the canonical list of
    # markers each engine ships.
    #
    # Example:
    #
    #   Seams::Generators::Splicer.splice_after_marker(
    #     file_path: "engines/auth/lib/auth/engine.rb",
    #     marker:    "auth.engine.events",
    #     content:   "  Seams::EventRegistry.register(\"identity.passkey_added.auth\", emitted_by: \"Auth\")\n"
    #   )
    #
    # The Splicer owns four design choices worth surfacing:
    #
    # 1. Markers are looked up by NAME, never by line number. A
    #    follow-up generator written today must keep working after
    #    the host adds twenty unrelated lines above the marker.
    # 2. Idempotency is checked by string-matching the splice content
    #    inside a 50-line window after the marker. Re-running the
    #    same splice is a no-op rather than an error.
    # 3. Indentation is auto-detected from the marker line itself.
    #    Follow-up generators don't have to know whether the marker
    #    sits at column 0, column 4, or column 6.
    # 4. The Splicer is pure file I/O — no Rails dep, no Thor — so
    #    it can be tested in isolation and reused outside the
    #    generator stack (e.g. by `bin/seams resolve --eject`).
    module Splicer
      module_function

      # Pattern matched by every Splicer method. The character class
      # for the marker name allows lowercase letters, digits, dot, and
      # underscore — see INSERTION_POINTS.md naming rules.
      MARKER_PREFIX = "# seams:insertion-point"
      MARKER_NAME_RE = /[a-z0-9_.]+/
      MARKER_LINE_RE = /^(\s*)#{Regexp.escape(MARKER_PREFIX)}\s+(#{MARKER_NAME_RE})\s*$/
      IDEMPOTENCY_WINDOW = 50

      # Result struct returned by every splice operation.
      # `ok?` is the only required predicate; `error` is populated
      # only when ok? is false; `lines_added` is 0 when ok? is true
      # but the splice was a no-op (idempotency hit).
      Result = Struct.new(:ok?, :lines_added, :error, keyword_init: true) do
        def to_s
          ok? ? "Splicer::Result(ok, +#{lines_added})" : "Splicer::Result(error: #{error})"
        end
      end

      # Splice `content` immediately after the line containing
      # `# seams:insertion-point <marker>`.
      #
      # @param file_path [String] absolute or working-dir-relative path
      # @param marker    [String] the marker name, e.g. "auth.engine.events"
      # @param content   [String] the snippet to insert. Must end in a newline.
      # @param indent    [String, nil] override auto-detected indentation. Pass
      #                   `""` to insert verbatim, or a string of spaces to
      #                   prepend to every line of `content`.
      # @return [Result]
      def splice_after_marker(file_path:, marker:, content:, indent: nil)
        splice(file_path: file_path, marker: marker, content: content, indent: indent, position: :after)
      end

      # Splice `content` immediately before the line containing the
      # marker. Same semantics as +splice_after_marker+ otherwise.
      #
      # @return [Result]
      def splice_before_marker(file_path:, marker:, content:, indent: nil)
        splice(file_path: file_path, marker: marker, content: content, indent: indent, position: :before)
      end

      # Locate a marker without modifying the file. Useful for follow-up
      # generators that want to verify multiple markers exist before
      # they start writing.
      #
      # @return [Hash, nil] { line_number: 1-indexed, indent: "  ", marker: "auth.engine.events" }
      #                     or nil if the marker isn't present.
      def find_marker(file_path:, marker:)
        return nil unless File.exist?(file_path)

        lines = File.read(file_path).lines
        lines.each_with_index do |line, index|
          match = line.match(MARKER_LINE_RE)
          next unless match
          next unless match[2] == marker

          return { line_number: index + 1, indent: match[1], marker: marker }
        end
        nil
      end

      # Enumerate every `seams:insertion-point` marker in a file in
      # source order. Used by the eject CLI's `--list-markers` flag
      # and by `bin/seams resolve` for human-readable diagnostics.
      #
      # @return [Array<Hash>] each entry shaped like +find_marker+ returns.
      def list_markers(file_path:)
        return [] unless File.exist?(file_path)

        result = []
        File.read(file_path).lines.each_with_index do |line, index|
          match = line.match(MARKER_LINE_RE)
          next unless match

          result << { line_number: index + 1, indent: match[1], marker: match[2] }
        end
        result
      end

      # Internal: shared body for splice_{after,before}_marker.
      def splice(file_path:, marker:, content:, indent:, position:)
        return file_not_found_result(file_path) unless File.exist?(file_path)

        lines = File.read(file_path).lines
        marker_index = locate_marker_index(lines, marker)
        return marker_not_found_result(marker, file_path) unless marker_index

        prepared = apply_indent(content, indent || detect_indent(lines[marker_index]))
        write_splice(file_path, lines, prepared, marker_index, position)
      end

      def write_splice(file_path, lines, prepared, marker_index, position)
        return Result.new(ok?: true, lines_added: 0, error: nil) if already_present?(lines, prepared, marker_index,
                                                                                     position)

        File.write(file_path, insert_at(lines, prepared, marker_index, position).join)
        Result.new(ok?: true, lines_added: prepared.lines.size, error: nil)
      end

      def file_not_found_result(file_path)
        Result.new(ok?: false, lines_added: 0, error: "file not found: #{file_path}")
      end

      def marker_not_found_result(marker, file_path)
        Result.new(ok?: false, lines_added: 0,
                   error: "marker '#{marker}' not found in #{file_path}")
      end

      # The marker line plus every line in the idempotency window
      # following (or preceding for :before) is inspected. The check
      # looks for the FULL prepared content as a contiguous block,
      # not for individual lines — a partial overlap is treated as
      # "not yet spliced" and re-splices, which is the safer default
      # for a tool that prefers re-runs to silent partials.
      #
      # The window grows to accommodate snippets larger than
      # IDEMPOTENCY_WINDOW lines: a 60-line follow-up splice would
      # never round-trip with a fixed 50-line window because the
      # haystack would be smaller than the needle. The effective
      # window is `max(IDEMPOTENCY_WINDOW, prepared.lines.size)`,
      # which guarantees idempotency regardless of snippet size while
      # keeping the small-splice fast path identical.
      def already_present?(lines, prepared, marker_index, position)
        haystack = haystack_for(lines, marker_index, position, prepared)
        haystack.include?(prepared)
      end

      def haystack_for(lines, marker_index, position, prepared)
        window = [IDEMPOTENCY_WINDOW, prepared.lines.size].max
        if position == :after
          slice_end = [marker_index + window, lines.size - 1].min
          lines[(marker_index + 1)..slice_end].to_a.join
        else
          slice_start = [marker_index - window, 0].max
          lines[slice_start...marker_index].to_a.join
        end
      end

      def insert_at(lines, prepared, marker_index, position)
        prepared_lines = prepared.lines
        if position == :after
          lines[0..marker_index] + prepared_lines + (lines[(marker_index + 1)..] || [])
        else
          lines[0...marker_index] + prepared_lines + lines[marker_index..]
        end
      end

      def locate_marker_index(lines, marker)
        lines.each_with_index do |line, index|
          match = line.match(MARKER_LINE_RE)
          return index if match && match[2] == marker
        end
        nil
      end

      def detect_indent(marker_line)
        marker_line[/^\s*/].to_s
      end

      # Apply `indent` to every non-blank line of `content`. Blank
      # lines stay blank — re-indenting them would leave trailing
      # whitespace that some linters (and our own RuboCop config) flag.
      def apply_indent(content, indent)
        return content if indent.empty?

        content.lines.map do |line|
          if line.strip.empty?
            line
          else
            "#{indent}#{line}"
          end
        end.join
      end
    end
  end
end
