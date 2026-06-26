# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/design/design_generator"

# Group spec for the Phase 2 "Overlays" components (design-p2-overlays):
# dialog, drawer, popover, savestate. Ported from quire-saas's Compositor and
# re-themed to the neutral design tokens. Kept in its own file so it never
# collides with the shared design_generator_spec.rb.
RSpec.describe Seams::Generators::DesignGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/design_overlays_generator", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
    seed_host_files
  end

  # Minimal host seed — only the files wire_into_host edits, mirroring a fresh
  # `rails new`d host (same shape as design_generator_spec.rb).
  def seed_host_files
    write_host "Gemfile", host_gemfile
    write_host "config/application.rb", host_application_rb
    write_host "config/routes.rb", host_routes_rb
    write_host "app/views/layouts/application.html.erb", host_layout
  end

  def host_gemfile
    <<~RUBY
      # frozen_string_literal: true
      source "https://rubygems.org"
      gem "rails"
    RUBY
  end

  def host_application_rb
    <<~RUBY
      # frozen_string_literal: true
      require_relative "boot"
      require "rails/all"

      module Dummy
        class Application < Rails::Application
          config.load_defaults 8.0
        end
      end
    RUBY
  end

  def host_routes_rb
    <<~RUBY
      # frozen_string_literal: true
      Rails.application.routes.draw do
      end
    RUBY
  end

  def host_layout
    <<~ERB
      <!DOCTYPE html>
      <html>
        <head><title>Dummy</title></head>
        <body>
          <%= yield %>
        </body>
      </html>
    ERB
  end

  def write_host(relative, contents)
    full = File.join(destination_root, relative)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, contents)
  end

  def run_generator
    described_class.start([], destination_root: destination_root)
  end

  def assert_file(path)
    full = File.join(destination_root, path)
    expect(File.exist?(full)).to be(true), "expected #{path} to be created"
    yield(File.read(full)) if block_given?
  end

  before do
    prepare_destination
    run_generator
  end

  # Every overlay ships a strict-locals partial + a preview (the preview is what
  # makes ui_<name> public + lists it in the gallery), and none leak the source
  # project's branding.
  describe "ships each Overlays component as partial + preview", :aggregate_failures do
    %w[dialog drawer popover savestate].each do |name|
      it "ships ui/_#{name} + ui/previews/_#{name}, re-themed to neutral tokens" do
        assert_file "engines/design/app/views/ui/_#{name}.html.erb" do |content|
          expect(content).to include("locals:")
          expect(content).not_to include("compositor")
          expect(content).not_to match(/Modular Rails|manuscript|EPUB|garnet|Spectral/i)
        end
        assert_file "engines/design/app/views/ui/previews/_#{name}.html.erb" do |content|
          expect(content).to include("ui_#{name}")
          expect(content).not_to include("compositor_#{name}")
        end
      end
    end
  end

  describe "dialog — accessibility + wiring is baked in", :aggregate_failures do
    it "uses a native <dialog>, labels it, and wires the ui-dialog controller" do
      assert_file "engines/design/app/views/ui/_dialog.html.erb" do |content|
        expect(content).to include("tag.dialog")
        # the dialog is named by its own title for assistive tech
        expect(content).to include("aria-labelledby")
        expect(content).to include('aria-label": "Close"').or include('aria-label="Close"')
        # the controller fragment is re-namespaced off compositor-*
        expect(content).to include('controller: "ui-dialog"')
        expect(content).to include("ui-dialog#open")
        expect(content).to include("ui-dialog#close")
        expect(content).not_to include("compositor-dialog")
        # renders through the design-system primitives, not raw markup
        expect(content).to include("ui_button")
        expect(content).to include("ui_icon(:close)")
      end
    end
  end

  describe "drawer — labelled landmark", :aggregate_failures do
    it "renders an <aside> labelled by its title" do
      assert_file "engines/design/app/views/ui/_drawer.html.erb" do |content|
        expect(content).to include("tag.aside")
        expect(content).to include('aria-label": title').or include("aria-label")
        expect(content).to include("title:")
      end
    end
  end

  describe "popover — annotation role", :aggregate_failures do
    it "declares role=note so it reads as an annotation" do
      assert_file "engines/design/app/views/ui/_popover.html.erb" do |content|
        expect(content).to include('role: "note"')
      end
    end
  end

  describe "savestate — live status", :aggregate_failures do
    it "declares role=status so changes are announced, with three states" do
      assert_file "engines/design/app/views/ui/_savestate.html.erb" do |content|
        expect(content).to include('role: "status"')
        expect(content).to include("state: :saved")
        expect(content).to include("saving")
        expect(content).to include("unsaved")
      end
      assert_file "engines/design/app/views/ui/previews/_savestate.html.erb" do |content|
        %w[saved saving unsaved].each do |state|
          expect(content).to include("state: :#{state}")
        end
      end
    end
  end
end
