# frozen_string_literal: true

require "fileutils"
require "generators/seams/admin/admin_generator"

# Behavioural check on a host with real routes.rb + initializers/: the
# admin engine's constants live under Seams::Admin, so the host must
# mount Seams::Admin::Engine only. A stray `mount Admin::Engine` raises
# NameError when the host boots.
RSpec.describe Seams::Generators::AdminGenerator do
  describe "host wiring" do
    let(:destination_root) { File.expand_path("../../../tmp/admin_host_wiring", __dir__) }
    let(:routes) { File.read(File.join(destination_root, "config/routes.rb")) }

    before do
      FileUtils.rm_rf(destination_root)
      FileUtils.mkdir_p(File.join(destination_root, "engines"))
      FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
      File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      File.write(File.join(destination_root, "Gemfile"), "source \"https://rubygems.org\"\n")
      described_class.start([], destination_root: destination_root)
    end

    after { FileUtils.rm_rf(destination_root) }

    it "mounts Seams::Admin::Engine exactly once" do
      expect(routes.scan('mount Seams::Admin::Engine, at: "/admin"').size).to eq(1)
    end

    it "does not mount the nonexistent top-level Admin::Engine" do
      expect(routes).not_to match(/mount\s+Admin::Engine/)
    end

    it "does not write the generic Admin.configure initializer stub" do
      expect(File.exist?(File.join(destination_root, "config/initializers/admin.rb"))).to be(false)
    end
  end
end
