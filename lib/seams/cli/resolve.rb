# frozen_string_literal: true

require "seams"
require "seams/generators/splicer"

module Seams
  module CLI
    # Implementation behind `bin/seams resolve` — gap-report 1.2 from
    # the 2026-05 framework feature-gap survey: the documented escape
    # hatch from seams' generators.
    #
    # Three modes:
    #
    #   bin/seams resolve --eject <engine>/<file>
    #
    #     Marks a single host file as host-owned. The next regeneration
    #     of the engine skips this file. The file already lives in the
    #     host's working tree (seams generates "the code is in your
    #     repo") — eject just prepends an explicit ownership header
    #     and tells the engine generator to leave it alone.
    #
    #   bin/seams resolve --list-markers <engine>
    #
    #     Lists every `# seams:insertion-point ...` marker the engine
    #     ships across all of its templated files. Helps the host
    #     operator see which extension points are public contract
    #     before writing a follow-up generator.
    #
    #   bin/seams resolve --list-ejected
    #
    #     Surveys engines/ for files marked with the eject header and
    #     lists them. Useful for "what's diverged from the gem".
    #
    # Returns true on success / false on failure. The caller (the
    # `bin/seams` shim) translates that into a non-zero exit code.
    #
    # Several methods here legitimately return true/false to signal
    # success/failure but are command verbs (`run_eject`,
    # `engine_present?` is fine, `fail_with` etc). Rubocop's
    # PredicateMethod cop wants every bool-returning method renamed
    # with a trailing `?`, but that's wrong for the run_* dispatchers
    # (they're imperative, not predicates). AbcSize / CyclomaticComplexity
    # likewise trigger on the run_* methods because CLI command
    # branches are inherently branchy. The cops are disabled at file
    # scope and the methods are kept linear and well-commented.
    # rubocop:disable Naming/PredicateMethod, Metrics/AbcSize, Metrics/CyclomaticComplexity
    class Resolve
      # Default directory that holds the generated engines.
      DEFAULT_ENGINES_ROOT = "engines"

      # Header injected at the top of every ejected file. Position
      # matters: future regenerations check the FIRST line of an
      # existing destination file for this exact prefix.
      EJECT_HEADER_PREFIX = "# seams:ejected from"

      # Builds the full ejected-file header block for a given event/source.
      EJECT_HEADER_LINES  = lambda do |from|
        <<~HEADER
          #{EJECT_HEADER_PREFIX} #{from}
          # Re-running `bin/rails generate seams:#{from.split(".").first}` will NOT overwrite this file.
          # To return to the gem version: delete this file and re-run the generator.
        HEADER
      end

      # Files at this list of relative paths under engines/<engine>/
      # are NOT eject-eligible. See doc note in EjectAware module.
      INELIGIBLE_RELATIVE_PATTERNS = [
        %r{\Adb/migrate/},                # one-shot, host runs them
        %r{\Alib/[^/]+/engine\.rb\z},     # framework-managed boot file
        %r{\Alib/[^/]+/version\.rb\z},    # framework-managed version constant
        /\AGemfile\z/,                    # engine's own Gemfile
        %r{\A[^/]+\.gemspec\z},           # engine's gemspec
        /\ARakefile\z/                    # engine's Rakefile (loads engine tasks)
      ].freeze

      def initialize(mode:, argument: nil, engines_root: DEFAULT_ENGINES_ROOT, output: $stdout, error: $stderr)
        @mode         = mode
        @argument     = argument
        @engines_root = engines_root
        @output       = output
        @error        = error
      end

      # Execute the selected resolve mode (:eject / :list_markers / :list_ejected).
      # @return [Boolean] true on success, false on a handled failure.
      def call
        case @mode
        when :eject         then run_eject
        when :list_markers  then run_list_markers
        when :list_ejected  then run_list_ejected
        else
          fail_with("unknown mode: #{@mode.inspect}")
        end
      end

      private

      # ---- Mode 1: --eject <engine>/<file_relative> ----

      def run_eject
        return false unless argument_present?(usage: "bin/seams resolve --eject <engine>/<file>")

        engine, relative = split_eject_argument(@argument)
        return false unless engine && relative

        return false unless engine_present?(engine)
        return false unless eject_eligible?(engine, relative)

        full_path = File.join(@engines_root, engine, relative)
        return fail_with("file not found: #{full_path}") unless File.exist?(full_path)

        contents = File.read(full_path)
        if contents.start_with?(EJECT_HEADER_PREFIX)
          @output.puts("already ejected: #{full_path}")
          return true
        end

        from = "#{engine}.#{relative}"
        File.write(full_path, EJECT_HEADER_LINES.call(from) + contents)
        line_count = File.read(full_path).each_line.count
        @output.puts("ejected: #{full_path} (lines: #{line_count}; from: #{from})")
        true
      end

      def split_eject_argument(argument)
        # Argument shape: "<engine>/<file/path>". The first segment is
        # the engine; everything after the first slash is the relative
        # path within the engine root. We deliberately match on the
        # FIRST slash so paths like "auth/app/mailers/auth/foo.rb"
        # round-trip correctly.
        if argument.include?("/")
          engine, relative = argument.split("/", 2)
          return [engine, relative] if engine && !engine.empty? && relative && !relative.empty?
        end

        fail_with("expected '<engine>/<file>', got #{argument.inspect}")
        [nil, nil]
      end

      def eject_eligible?(engine, relative)
        return true unless INELIGIBLE_RELATIVE_PATTERNS.any? { |pattern| pattern.match?(relative) }

        fail_with(
          "refusing to eject #{engine}/#{relative}: this file is framework-managed " \
          "(migrations, engine.rb, version.rb, Gemfile, .gemspec) and is not eject-eligible. " \
          "See doc/INSERTION_POINTS.md and Seams::Generators::EjectAware for the rule."
        )
        false
      end

      # ---- Mode 2: --list-markers <engine> ----

      def run_list_markers
        return false unless argument_present?(usage: "bin/seams resolve --list-markers <engine>")
        return false unless engine_present?(@argument)

        engine_root = File.join(@engines_root, @argument)
        markers = collect_markers(engine_root)

        if markers.empty?
          @output.puts("#{@argument}: no insertion-point markers found in #{engine_root}/")
          @output.puts("  This engine may not have been retrofitted to Wave 10. " \
                       "Re-run `bin/rails generate seams:#{@argument}` to pick up the marker set.")
          return true
        end

        print_marker_table(markers)
        true
      end

      def collect_markers(engine_root)
        rb_files = Dir.glob(File.join(engine_root, "**", "*.rb"))
        rb_files.flat_map do |path|
          Seams::Generators::Splicer.list_markers(file_path: path).map do |info|
            relative = path.sub(%r{\A#{Regexp.escape(engine_root)}/}, "")
            description = description_for(path, info[:line_number])
            info.merge(file: relative, description: description)
          end
        end
      end

      # Best-effort one-line description: read the comment immediately
      # PRECEDING the marker (one or two lines back) — the catalogue
      # convention is to document the marker's purpose in a sibling
      # comment line. Falls back to an empty string if no such comment
      # exists; the table prints "(no description)" in that case.
      def description_for(file_path, marker_line_number)
        return "" unless File.exist?(file_path)

        lines = File.readlines(file_path)
        # marker_line_number is 1-indexed; the description line, if any,
        # sits immediately above. Guard against marker_line_number == 1
        # explicitly — Ruby's negative array index would otherwise wrap
        # to the LAST line of the file, which is nonsensical here.
        return "" if marker_line_number <= 1

        candidate = lines[marker_line_number - 2]
        return "" unless candidate

        stripped = candidate.strip
        return "" unless stripped.start_with?("#")
        return "" if stripped.start_with?("# seams:insertion-point")

        stripped.sub(/\A#\s?/, "").strip
      end

      def print_marker_table(markers)
        marker_width = markers.map { |m| m[:marker].length }.max
        location_width = markers.map { |m| "#{m[:file]}:#{m[:line_number]}".length }.max

        markers.each do |info|
          location = "#{info[:file]}:#{info[:line_number]}"
          description = info[:description].empty? ? "(no description)" : %("#{info[:description]}")
          @output.puts("#{info[:marker].ljust(marker_width)}  #{location.ljust(location_width)}  #{description}")
        end
      end

      # ---- Mode 3: --list-ejected ----

      def run_list_ejected
        unless Dir.exist?(@engines_root)
          @output.puts("no engines directory at #{@engines_root}/")
          return true
        end

        ejected = collect_ejected_files
        if ejected.empty?
          @output.puts("no ejected files in #{@engines_root}/")
          return true
        end

        @output.puts("seams: #{ejected.size} ejected file(s)")
        ejected.each { |path, source| @output.puts("  #{path}  (from: #{source})") }
        true
      end

      def collect_ejected_files
        # Cheap two-pass scan: read first 200 bytes of every text file
        # under engines/, look for the prefix. We deliberately skip
        # binaries (anything that isn't .rb / .erb / .yml / .yaml / .rake / .css / .js)
        # because the eject header is always a `#`-comment and only
        # text-ish files carry it.
        text_extensions = %w[.rb .erb .yml .yaml .rake .css .js .txt .md].freeze
        Dir.glob(File.join(@engines_root, "**", "*"))
           .select { |path| File.file?(path) && text_extensions.include?(File.extname(path)) }
           .sort
           .filter_map do |path|
             head = File.read(path, 200)
             next nil unless head.start_with?(EJECT_HEADER_PREFIX)

             source = head.lines.first.to_s.sub(EJECT_HEADER_PREFIX, "").strip
             [path, source]
           end
      end

      # ---- Shared helpers ----

      def argument_present?(usage:)
        return true if @argument && !@argument.empty?

        fail_with("missing argument. Usage: #{usage}")
        false
      end

      def engine_present?(engine)
        engine_root = File.join(@engines_root, engine)
        return true if File.directory?(engine_root)

        fail_with("engine #{engine.inspect} not found at #{engine_root}/. " \
                  "Run `bin/rails generate seams:#{engine}` first.")
        false
      end

      def fail_with(message)
        @error.puts("seams resolve: #{message}")
        false
      end
    end
    # rubocop:enable Naming/PredicateMethod, Metrics/AbcSize, Metrics/CyclomaticComplexity
  end
end
