# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

# Keeps doc/TUTORIAL.md honest: every `bin/seams <command>` it tells a
# newcomer to run must be a real command, and every relative link must
# resolve. A tutorial that drifts from the CLI is worse than no tutorial —
# the reader copy-pastes a command in their first ten minutes and it
# errors. The full rails-new -> install -> engine -> boot path the
# tutorial describes is exercised end-to-end by spec/integration_full/.

TUTORIAL_ROOT = File.expand_path("../..", __dir__)
TUTORIAL_PATH = File.join(TUTORIAL_ROOT, "doc/TUTORIAL.md")

# Generators discovered from the code, plus the non-generator diagnostic
# commands the bin/seams wrapper routes (see bin_seams.tt).
def known_seams_commands
  generators = Dir[File.join(TUTORIAL_ROOT, "lib/generators/seams/*")]
               .select { |dir| File.exist?(File.join(dir, "#{File.basename(dir)}_generator.rb")) }
               .map { |dir| File.basename(dir) }
  (generators + %w[list test quality resolve]).sort.uniq
end

def tutorial_commands
  File.read(TUTORIAL_PATH).scan(%r{bin/seams\s+([a-z_]+)}).flatten.uniq
end

def tutorial_relative_links
  File.read(TUTORIAL_PATH).scan(/\[[^\]]+\]\(([^)]+)\)/).flatten
      .reject { |t| t.start_with?("http://", "https://", "#", "mailto:") }
      .filter_map { |t| t.split("#").first }
      .reject(&:empty?)
      .uniq
end

RSpec.describe "Tutorial coverage" do
  it "exists" do
    expect(File.exist?(TUTORIAL_PATH)).to be(true)
  end

  it "only tells the reader to run real bin/seams commands" do
    unknown = tutorial_commands - known_seams_commands

    expect(unknown).to(
      be_empty,
      "doc/TUTORIAL.md references bin/seams commands that don't exist: " \
      "#{unknown.join(", ")}. Fix the tutorial or the command."
    )
  end

  it "points every relative link at a file that exists" do
    missing = tutorial_relative_links.reject do |target|
      File.exist?(File.expand_path(target, File.dirname(TUTORIAL_PATH)))
    end

    expect(missing).to(
      be_empty,
      "doc/TUTORIAL.md links to files that don't exist: #{missing.join(", ")}."
    )
  end
end
# rubocop:enable RSpec/DescribeClass
