# frozen_string_literal: true

# Group spec for Phase 2 "Actions & status" components (GROUPKEY = actions).
#
# These components are ported from quire-saas's Compositor and re-themed to the
# neutral design tokens. Phase 1 already shipped `button` and `tag`; this group
# adds `banner`, `toast`, and `note`. Components are AUTO-DERIVED from their
# previews, so each one ships as a strict-locals partial + a preview partial.
#
# This spec asserts the partials + previews exist as template (.tt) sources, that
# they carry their accessibility wiring, and that no quire/Compositor branding
# bled through the re-theme. It deliberately does NOT touch the shared
# design_generator_spec.rb.
RSpec.describe "seams:design Actions & status components" do # rubocop:disable RSpec/DescribeClass
  def templates_root
    File.expand_path(
      "../../../lib/generators/seams/design/templates/app/views/ui",
      __dir__
    )
  end

  def partial(name)
    File.read(File.join(templates_root, "_#{name}.html.erb.tt"))
  end

  def preview(name)
    File.read(File.join(templates_root, "previews", "_#{name}.html.erb.tt"))
  end

  def partial_exist?(name)
    File.exist?(File.join(templates_root, "_#{name}.html.erb.tt"))
  end

  def preview_exist?(name)
    File.exist?(File.join(templates_root, "previews", "_#{name}.html.erb.tt"))
  end

  # The components this group is responsible for porting. `button` and `tag`
  # shipped in Phase 1, so they are out of scope here.
  %w[banner toast note].each do |name|
    describe "ui/#{name}" do
      it "ships a strict-locals partial, neutrally re-themed" do
        expect(partial_exist?(name)).to be(true), "expected ui/_#{name}.html.erb.tt"
        expect(partial(name)).to include("locals:")
        expect(partial(name)).not_to include("compositor")
      end

      it "ships a preview calling the ui_#{name} helper" do
        expect(preview_exist?(name)).to be(true), "expected ui/previews/_#{name}.html.erb.tt"
        expect(preview(name)).to include("ui_#{name}")
        expect(preview(name)).not_to include("compositor_#{name}")
      end
    end
  end

  describe "banner accessibility + slots" do
    it "is a status region with a leading icon and an optional content slot" do
      expect(partial("banner")).to include('role: "status"')
      expect(partial("banner")).to include("ui_icon")
      expect(partial("banner")).to include("message:")
      expect(partial("banner")).to include("content: nil")
    end
  end

  describe "toast accessibility" do
    it "switches role between alert and status on the kind, and is dismissible" do
      # An alerting toast must announce assertively; everything else is polite.
      expect(partial("toast")).to include('kind == :alert ? "alert" : "status"')
      # The dismiss control must carry an accessible name.
      expect(partial("toast")).to include('"aria-label": "Dismiss"')
      expect(partial("toast")).to include("ui_icon(:close)")
    end
  end

  describe "note" do
    it "is a minimal content-block aside" do
      expect(partial("note")).to include("content: nil")
      expect(partial("note")).to include('class: "note"')
    end
  end
end
