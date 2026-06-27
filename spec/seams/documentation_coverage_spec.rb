# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

# Drift guard: the README is the front door, and it has historically
# fallen behind the code (it sat at "Waves 1-9" while the admin,
# design, and permissions engines had already shipped). These specs
# fail the build when a generator exists in the code but is not
# documented in the README, and when a relative link in the README
# points at a file that does not exist. Both failures are the kind a
# new engineer hits in their first ten minutes.

REPO_ROOT = File.expand_path("../..", __dir__)
README_PATH = File.join(REPO_ROOT, "README.md")

# Every top-level seams generator: a directory under
# lib/generators/seams/ that holds a matching <name>_generator.rb.
# Nested follow-up generators (e.g. auth/add_oauth_provider) are
# documented separately and excluded here.
def top_level_seams_generators
  Dir[File.join(REPO_ROOT, "lib/generators/seams/*")]
    .select { |dir| File.exist?(File.join(dir, "#{File.basename(dir)}_generator.rb")) }
    .map { |dir| File.basename(dir) }
    .sort
end

# Repo-relative links in the README: [text](target) where target is not
# http, not a bare #anchor, not mailto. Fragments are stripped before
# checking existence.
def readme_relative_links
  File.read(README_PATH).scan(/\[[^\]]+\]\(([^)]+)\)/).flatten
      .reject { |t| t.start_with?("http://", "https://", "#", "mailto:") }
      .filter_map { |t| t.split("#").first }
      .reject(&:empty?)
      .uniq
end

RSpec.describe "Documentation coverage" do
  let(:readme) { File.read(README_PATH) }

  describe "the README documents every generator" do
    top_level_seams_generators.each do |name|
      it "mentions the `#{name}` generator" do
        # Accept either the bin/seams form ("seams core") or the
        # rails-generator form ("seams:core"). A generator that ships
        # without one of these in the README is undiscoverable.
        documented = readme.include?("seams #{name}") || readme.include?("seams:#{name}")

        expect(documented).to(
          be(true),
          "Generator `#{name}` exists in lib/generators/seams/#{name}/ but is " \
          "not documented in README.md. Add it to the \"What you get\" section " \
          "(as `bin/seams #{name}`) so a new user can discover it."
        )
      end
    end
  end

  describe "the README's relative links resolve" do
    it "points every relative link at a file that exists" do
      missing = readme_relative_links.reject do |target|
        File.exist?(File.expand_path(target, REPO_ROOT))
      end

      expect(missing).to(
        be_empty,
        "README.md links to files that do not exist: #{missing.join(", ")}. " \
        "Either create them or fix the link."
      )
    end
  end
end
# rubocop:enable RSpec/DescribeClass
