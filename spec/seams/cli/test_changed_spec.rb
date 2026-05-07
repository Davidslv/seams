# frozen_string_literal: true

require "stringio"
require "seams/cli/test_changed"

# RSpec/SubjectStub fires because we stub `changed_engines` + `system`
# on the subject. `changed_engines` is the git-diff boundary;
# `system` is the rspec shell-out boundary. Stubbing them on the SUT
# is the correct test strategy here — see quality_spec.rb's matching
# disable for the longer rationale.
# rubocop:disable RSpec/SubjectStub
RSpec.describe Seams::CLI::TestChanged do
  subject(:cli) { described_class.new(base: "main", engines_root: engines_root, output: io) }

  let(:io)           { StringIO.new }
  let(:engines_root) { File.expand_path("../../tmp/test_changed_cli_engines", __dir__) }

  before do
    FileUtils.rm_rf(engines_root)
    FileUtils.mkdir_p(engines_root)
  end

  after { FileUtils.rm_rf(engines_root) }

  describe "#call" do
    it "returns true and prints a friendly message when no engines changed" do
      allow(cli).to receive(:changed_engines).and_return([])

      expect(cli.call).to be(true)
      expect(io.string).to include("no engines changed")
    end

    it "returns true when every changed-engine spec run passes" do
      FileUtils.mkdir_p(File.join(engines_root, "billing", "spec"))
      File.write(File.join(engines_root, "billing", "spec", "noop_spec.rb"), "")

      allow(cli).to receive_messages(changed_engines: %w[billing], system: true)

      expect(cli.call).to be(true)
      expect(io.string).to include("running specs for 1 engine")
      expect(io.string).to include("All affected engine specs passed.")
    end

    it "returns false and lists failed engines when a spec run fails" do
      %w[billing teams].each do |name|
        FileUtils.mkdir_p(File.join(engines_root, name, "spec"))
        File.write(File.join(engines_root, name, "spec", "noop_spec.rb"), "")
      end

      allow(cli).to receive(:changed_engines).and_return(%w[billing teams])
      allow(cli).to receive(:system).with("bundle", "exec", "rspec", anything) { |*_, dir| dir.include?("billing") }

      expect(cli.call).to be(false)
      expect(io.string).to include("Failed engines: teams")
    end

    it "skips engines that exist but have no spec files (no-op)" do
      FileUtils.mkdir_p(File.join(engines_root, "billing", "spec"))
      # No *_spec.rb files inside.

      allow(cli).to receive_messages(changed_engines: %w[billing], system: true)

      expect(cli.call).to be(true)
      # `system` is the rspec shell-out — it MUST NOT be called when
      # the engine has no spec files. have_received-on-no-args:
      expect(cli).not_to have_received(:system)
    end
  end
end
# rubocop:enable RSpec/SubjectStub
