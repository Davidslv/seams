# frozen_string_literal: true

require "rails/generators"
require "generators/seams/design/design_generator"

# Phase 2 — Data display group (GROUPKEY = data).
#
# These components are ported from quire-saas's Compositor and re-themed to the
# neutral design tokens. The seams:design generator AUTO-DERIVES the public
# component list from the ui/previews partials, so each component must ship as a
# pair of template files:
#
#   templates/app/views/ui/_<name>.html.erb.tt          (the strict-locals partial)
#   templates/app/views/ui/previews/_<name>.html.erb.tt (its preview, => ui_<name>)
#
# This spec asserts the .tt SOURCE templates exist and stay neutral (no quire /
# compositor branding bled through) and that the accessibility wiring the
# Compositor bakes in survived the port. It does NOT touch the shared
# design_generator_spec.rb.
RSpec.describe Seams::Generators::DesignGenerator do
  def templates_root
    File.expand_path(
      "../../../lib/generators/seams/design/templates/app/views/ui",
      __dir__
    )
  end

  def data_components
    %w[card data_table chapter_row build_row counter meter kbd]
  end

  def partial(name)
    File.join(templates_root, "_#{name}.html.erb.tt")
  end

  def preview(name)
    File.join(templates_root, "previews", "_#{name}.html.erb.tt")
  end

  def read_partial(name)
    File.read(partial(name))
  end

  def read_preview(name)
    File.read(preview(name))
  end

  describe "the partial + preview pair ships for every data component" do
    it "ships ui/_<name>.html.erb.tt and its preview (=> ui_<name>)", :aggregate_failures do
      data_components.each do |name|
        expect(File.exist?(partial(name))).to be(true), "expected partial template for #{name}"
        expect(File.exist?(preview(name))).to be(true), "expected preview template for #{name}"

        # The preview is what makes ui_<name> public in the auto-wire gallery.
        expect(read_preview(name)).to include("ui_#{name}")
      end
    end
  end

  describe "re-themed to neutral tokens (no quire / compositor branding)" do
    it "carries no compositor_* helpers or quire copy in any partial or preview", :aggregate_failures do
      data_components.each do |name|
        [read_partial(name), read_preview(name)].each do |content|
          expect(content).not_to include("compositor")
          expect(content).not_to include("Compositor")
          # quire-specific domain copy that must not bleed into the neutral default
          expect(content).not_to include("EPUB")
          expect(content).not_to include("Quire")
          expect(content).not_to include("£")
          expect(content).not_to include("garnet")
          expect(content).not_to include("Spectral")
        end
      end
    end
  end

  describe "strict-locals contracts" do
    it "card takes an optional content block", :aggregate_failures do
      content = read_partial("card")
      expect(content).to include("locals: (content: nil, **attrs)")
      expect(content).to include('class: "card"')
    end

    it "data_table requires columns: and rows:" do
      expect(read_partial("data_table")).to include("locals: (columns:, rows:, **attrs)")
    end

    it "chapter_row requires index: and title: and composes ui_tag", :aggregate_failures do
      content = read_partial("chapter_row")
      expect(content).to include("locals: (index:, title:")
      # composes the already-shipped tag component rather than reinventing it
      expect(content).to include("ui_tag(")
    end

    it "build_row requires format: and composes ui_tag", :aggregate_failures do
      content = read_partial("build_row")
      expect(content).to include("locals: (format:")
      expect(content).to include("ui_tag(")
    end

    it "counter requires current: and max:" do
      expect(read_partial("counter")).to include("locals: (current:, max:, **attrs)")
    end

    it "meter requires value: and max:" do
      expect(read_partial("meter")).to include("locals: (value:, max:")
    end

    it "kbd requires keys:" do
      expect(read_partial("kbd")).to include("locals: (keys:, **attrs)")
    end
  end

  describe "baked-in accessibility (matches Compositor's aria/roles)" do
    it "data_table uses scope=col headers and aria-sort, hiding the sort glyph", :aggregate_failures do
      content = read_partial("data_table")
      expect(content).to include('scope: "col"')
      expect(content).to include('"aria-sort": col[:sort]')
      # the decorative sort arrow is hidden from assistive tech
      expect(content).to include('"aria-hidden": "true"')
    end

    it "chapter_row hides the drag glyph and labels the move buttons", :aggregate_failures do
      content = read_partial("chapter_row")
      expect(content).to include('"aria-hidden": "true"')
      expect(content).to include('"aria-label": "Move up"')
      expect(content).to include('"aria-label": "Move down"')
    end

    it "meter exposes a progressbar role with value bounds", :aggregate_failures do
      content = read_partial("meter")
      expect(content).to include('role: "progressbar"')
      expect(content).to include('"aria-valuenow": value')
      expect(content).to include('"aria-valuemin": 0')
      expect(content).to include('"aria-valuemax": max')
    end

    it "build_row's inline progress track exposes a progressbar role", :aggregate_failures do
      content = read_partial("build_row")
      expect(content).to include('role: "progressbar"')
      expect(content).to include('"aria-valuenow": width')
    end
  end
end
