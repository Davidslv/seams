# frozen_string_literal: true

require "stringio"
require "seams/cli/quality"

# RSpec/SubjectStub fires because we stub `gem_installed?` + `system`
# on the subject. Both are infrastructure-boundary methods (one
# checks a gem in the bundle, the other shells out) — stubbing them
# on the SUT IS the correct test strategy here. The alternative
# (injecting runners + gem-checkers as constructor args) clutters
# the production API for a code-style preference.
# rubocop:disable RSpec/SubjectStub
RSpec.describe Seams::CLI::Quality do
  subject(:cli) { described_class.new(output: io) }

  let(:io) { StringIO.new }

  describe "#call" do
    before do
      # By default treat every gem as missing → every gate skipped.
      # Individual examples opt in to specific gems.
      allow(cli).to receive(:gem_installed?).and_return(false)
      allow(File).to receive(:exist?).with("script/collate_coverage.rb").and_return(false)
    end

    it "returns true when every gate is skipped" do
      expect(cli.call).to be(true)
      expect(io.string).to include("rubocop not installed — skipping.")
      expect(io.string).to include("brakeman not installed — skipping.")
      expect(io.string).to include("bundler-audit not installed — skipping.")
      expect(io.string).to include("script/collate_coverage.rb not present")
    end

    it "runs rubocop --parallel when the gem is installed" do
      allow(cli).to receive(:gem_installed?).with("rubocop").and_return(true)
      allow(cli).to receive(:system).with("bundle", "exec", "rubocop", "--parallel").and_return(true)

      expect(cli.call).to be(true)
      expect(io.string).to include("rubocop --parallel")
    end

    it "returns false when rubocop fails" do
      allow(cli).to receive(:gem_installed?).with("rubocop").and_return(true)
      allow(cli).to receive(:system).with("bundle", "exec", "rubocop", "--parallel").and_return(false)

      expect(cli.call).to be(false)
    end

    it "runs brakeman when installed and reports its result" do
      allow(cli).to receive(:gem_installed?).with("brakeman").and_return(true)
      allow(cli).to receive(:system).with("bundle", "exec", "brakeman", "--no-pager",
                                          "--no-progress", "--quiet").and_return(true)

      expect(cli.call).to be(true)
      expect(io.string).to include("brakeman")
    end

    it "runs bundle-audit when bundler-audit is installed" do
      allow(cli).to receive(:gem_installed?).with("bundler-audit").and_return(true)
      allow(cli).to receive(:system).with("bundle", "exec", "bundle-audit",
                                          "check", "--update").and_return(true)

      expect(cli.call).to be(true)
      expect(io.string).to include("bundle-audit check --update")
    end

    it "runs script/collate_coverage.rb when present" do
      allow(File).to receive(:exist?).with("script/collate_coverage.rb").and_return(true)
      allow(cli).to receive(:system).with("ruby", "script/collate_coverage.rb").and_return(true)

      expect(cli.call).to be(true)
      expect(io.string).to include("ruby script/collate_coverage.rb")
    end

    it "prints a summary line for every gate" do
      cli.call
      %w[rubocop brakeman bundler_audit coverage].each do |gate|
        expect(io.string).to include(gate)
      end
    end
  end
end
# rubocop:enable RSpec/SubjectStub
