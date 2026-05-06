# frozen_string_literal: true

require "stringio"
require "seams/cli/list"

RSpec.describe Seams::CLI::List do
  subject(:list) { described_class.new(engines_root: engines_root, output: io) }

  let(:io)            { StringIO.new }
  let(:engines_root)  { File.expand_path("../../tmp/list_cli_engines", __dir__) }

  before do
    FileUtils.rm_rf(engines_root)
    FileUtils.mkdir_p(File.join(engines_root, "billing", "lib"))
    FileUtils.mkdir_p(File.join(engines_root, "auth", "lib"))
    Seams::EventRegistry.reset!
    Seams::EventRegistry.register("subscription.created.billing", emitted_by: "Billing")
    Seams::EventRegistry.register("user.signed_up.auth", emitted_by: "Auth")
  end

  after { FileUtils.rm_rf(engines_root) }

  describe "#call" do
    it "prints each engine on its own line in alphabetical order" do
      list.call
      output = io.string
      auth_pos    = output.index("auth")
      billing_pos = output.index("billing")

      expect(auth_pos).to be < billing_pos
    end

    it "prints the events emitted by each engine under that engine" do
      list.call
      expect(io.string).to include("subscription.created.billing")
      expect(io.string).to include("user.signed_up.auth")
    end

    it "shows '(no events)' for an engine that hasn't registered any" do
      FileUtils.mkdir_p(File.join(engines_root, "core", "lib"))
      list.call
      expect(io.string).to include("core")
      expect(io.string).to include("(no events)")
    end

    it "prints a header line" do
      list.call
      expect(io.string).to match(/^seams: /)
    end
  end

  describe "with no engines installed" do
    before { FileUtils.rm_rf(engines_root) and FileUtils.mkdir_p(engines_root) }

    it "prints a friendly empty-state message" do
      list.call
      expect(io.string).to include("no engines")
    end
  end
end
