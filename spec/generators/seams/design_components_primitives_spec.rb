# frozen_string_literal: true

require "rails/generators"
require "generators/seams/design/design_generator"

# Group spec for the Phase 2 "Primitives & icons" components (GROUPKEY:
# primitives). icon + icon_sprite shipped in Phase 1 and are asserted by the
# shared design_generator_spec; this group ADDS panel, diff and empty, so this
# spec covers only those three, plus a guard that the Phase 1 icon primitives
# are still present alongside them.
#
# Self-contained: it runs the design generator into a throwaway destination
# (seeding the host files its host wiring edits) and asserts the new ui/
# partials + previews are emitted, re-themed to neutral tokens with the
# accessibility wiring baked in.
RSpec.describe Seams::Generators::DesignGenerator do
  let(:destination_root) do
    File.expand_path("../../../tmp/design_components_primitives", __dir__)
  end

  def write_host(relative, contents)
    full = File.join(destination_root, relative)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, contents)
  end

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

  def assert_file(path)
    full = File.join(destination_root, path)
    expect(File.exist?(full)).to be(true), "expected #{path} to be created"
    yield(File.read(full)) if block_given?
  end

  before do
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
    seed_host_files
    described_class.start([], destination_root: destination_root)
  end

  describe "panel" do
    it "ships a content-block panel partial on the neutral .panel surface", :aggregate_failures do
      assert_file "engines/design/app/views/ui/_panel.html.erb" do |content|
        expect(content).to include("locals:")
        expect(content).to include("content: nil")
        expect(content).to include('class: "panel"')
        expect(content).not_to include("compositor")
      end
    end

    it "ships a neutral preview calling ui_panel", :aggregate_failures do
      assert_file "engines/design/app/views/ui/previews/_panel.html.erb" do |content|
        expect(content).to include("ui_panel")
        expect(content).not_to include("compositor_panel")
        # no quire/manuscript branding bled through
        expect(content).not_to include("Manuscript")
        expect(content).not_to include("EPUB")
      end
    end
  end

  describe "diff" do
    it "ships a diff partial with per-line add/del/ctx semantics + aria labels", :aggregate_failures do
      assert_file "engines/design/app/views/ui/_diff.html.erb" do |content|
        expect(content).to include("locals:")
        expect(content).to include("file:")
        expect(content).to include("lines:")
        expect(content).to include('class: "diff"')
        # the added/removed signs are labelled for assistive tech, the glyph alone
        # is not enough.
        expect(content).to include('"aria-label": sign_label')
        expect(content).to include("added")
        expect(content).to include("removed")
        expect(content).not_to include("compositor")
      end
    end

    it "ships a neutral preview driving all three line kinds", :aggregate_failures do
      assert_file "engines/design/app/views/ui/previews/_diff.html.erb" do |content|
        expect(content).to include("ui_diff")
        expect(content).not_to include("compositor_diff")
        # exercises ctx / del / add together so the gallery shows every row state
        expect(content).to include(":ctx")
        expect(content).to include(":del")
        expect(content).to include(":add")
      end
    end
  end

  describe "empty" do
    it "ships an empty-state partial with a required title + content block", :aggregate_failures do
      assert_file "engines/design/app/views/ui/_empty.html.erb" do |content|
        expect(content).to include("locals:")
        expect(content).to include("title:")
        expect(content).to include("content: nil")
        expect(content).to include('class: "empty"')
        expect(content).not_to include("compositor")
      end
    end

    it "ships a neutral preview calling ui_empty with a call to action", :aggregate_failures do
      assert_file "engines/design/app/views/ui/previews/_empty.html.erb" do |content|
        expect(content).to include("ui_empty")
        expect(content).not_to include("compositor_empty")
        expect(content).to include("ui_button")
        expect(content).not_to include("manuscript")
      end
    end
  end

  describe "Phase 1 icon primitives still present alongside this group" do
    it "keeps the icon partial + the ui-icon-* sprite", :aggregate_failures do
      assert_file "engines/design/app/views/ui/_icon.html.erb" do |content|
        expect(content).to include("#ui-icon-")
      end
      assert_file "engines/design/app/views/ui/_icon_sprite.html.erb" do |content|
        expect(content).to include('id="ui-icon-')
      end
    end
  end

  describe "auto-wire visibility" do
    it "makes panel / diff / empty public via their preview partials", :aggregate_failures do
      %w[panel diff empty].each do |name|
        full = File.join(
          destination_root,
          "engines/design/app/views/ui/previews/_#{name}.html.erb"
        )
        expect(File.exist?(full)).to be(true),
                                     "expected ui/previews/_#{name} so ui_#{name} is public"
      end
    end
  end
end
