# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/design/design_generator"

# Phase 3 of the design engine (#26 --shell, #27 example theme, #28 docs).
# The generic engine surface is covered by design_generator_spec; this spec
# focuses on what Phase 3 adds: the opt-in shell (on AND off), the example
# theme overlay, and the regenerated README's Phase-3 sections.
RSpec.describe Seams::Generators::DesignGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/design_phase3", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
    seed_host_files
  end

  def seed_host_files
    write_host "Gemfile", "# frozen_string_literal: true\nsource \"https://rubygems.org\"\ngem \"rails\"\n"
    write_host "config/application.rb", host_application_rb
    write_host "config/routes.rb",
               "# frozen_string_literal: true\nRails.application.routes.draw do\nend\n"
    write_host "app/views/layouts/application.html.erb", host_layout
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

  def host(relative)
    File.read(File.join(destination_root, relative))
  end

  def exist?(relative)
    File.exist?(File.join(destination_root, relative))
  end

  def run_generator(args = [])
    described_class.start(args, destination_root: destination_root)
  end

  before { prepare_destination }

  # ---- #26: opt-in --shell -------------------------------------------------

  describe "without --shell (default)" do
    before { run_generator }

    it "does not generate the dashboard controller or view" do
      expect(exist?("engines/design/app/controllers/design/dashboard_controller.rb")).to be(false)
      expect(exist?("engines/design/app/views/design/dashboard/index.html.erb")).to be(false)
    end

    it "leaves the host layout untouched (no shell chrome)" do
      expect(host("app/views/layouts/application.html.erb")).not_to include("app-header")
    end

    it "does not draw a dashboard route" do
      expect(host("config/routes.rb")).not_to include("design/dashboard#index")
    end
  end

  describe "with --shell" do
    before { run_generator(["--shell"]) }

    it "generates the starter dashboard controller subclassing ApplicationController" do
      path = "engines/design/app/controllers/design/dashboard_controller.rb"
      expect(exist?(path)).to be(true)
      content = host(path)
      expect(content).to include("module Design")
      expect(content).to include("class DashboardController < ApplicationController")
      expect(content).to include("@suggested_engines")
    end

    it "generates the dashboard index view built from ui_* components" do
      path = "engines/design/app/views/design/dashboard/index.html.erb"
      expect(exist?(path)).to be(true)
      content = host(path)
      expect(content).to include("ui_card")
      expect(content).to include("ui_tag")
      expect(content).to include("@suggested_engines")
    end

    it "overwrites the host layout with shell chrome built from ui_* components", :aggregate_failures do
      layout = host("app/views/layouts/application.html.erb")
      expect(layout).to include("app-header")
      expect(layout).to include('render "ui/icon_sprite"')
      expect(layout).to include("ui_banner")          # flash banners
      expect(layout).to include('class="skip')        # skip link
      expect(layout).to include("app-foot")           # footer
      # the app name is derived from the host module (Dummy)
      expect(layout).to include("Dummy")
    end

    it "draws the dashboard route + root into the host", :aggregate_failures do
      routes = host("config/routes.rb")
      expect(routes).to include('get "dashboard" => "design/dashboard#index"')
      expect(routes).to include('root "design/dashboard#index"')
    end

    it "is idempotent — a second --shell run does not duplicate the route/root" do
      run_generator(["--shell"])
      routes = host("config/routes.rb")
      expect(routes.scan("design/dashboard#index").size).to eq(2) # get + root, once each
      expect(routes.scan("root ").size).to eq(1)
    end

    it "does not double-inject the icon sprite (shell layout already has it)" do
      expect(host("app/views/layouts/application.html.erb")
        .scan('render "ui/icon_sprite"').size).to eq(1)
    end
  end

  # ---- #27: example theme --------------------------------------------------

  describe "example theme (quire)" do
    before { run_generator }

    it "ships the quire theme as a token overlay in the host" do
      path = "app/assets/tailwind/themes/_quire.css"
      expect(exist?(path)).to be(true)
      content = host(path)
      expect(content).to include("@theme")
      # the quire palette + type pairing
      expect(content).to include("#7a1f1f") # garnet, overriding --color-accent
      expect(content).to include("Spectral")
      expect(content).to include("IBM Plex")
    end

    it "overrides ONLY tokens — it does not redefine component CSS" do
      content = host("app/assets/tailwind/themes/_quire.css")
      # a token overlay, not a component sheet
      expect(content).not_to include("@layer components")
      expect(content).not_to include(".btn{")
      expect(content).to include("--color-accent:#7a1f1f")
    end

    it "is NOT applied by default — the host application.css keeps the neutral theme" do
      css = host("app/assets/tailwind/application.css")
      expect(css).not_to include('@import "themes/quire"')
      expect(css).to include("seams:design tokens")
      expect(css).not_to include("Spectral")
    end
  end

  # The component CSS layer is the visual half of the single source: a token
  # override has to have something to reskin. Assert the shipped tokens carry the
  # @layer components block (the .btn / .card / … the ui_* partials render),
  # reading only the aliases so it stays theme-agnostic.
  describe "component CSS layer (the visual single source)" do
    before { run_generator }

    it "writes the @layer components block into the host CSS", :aggregate_failures do
      css = host("app/assets/tailwind/application.css")
      expect(css).to include("@layer components{")
      %w[.btn .card .tag .field .input .menu .dialog .table .meter .banner .empty].each do |klass|
        expect(css).to include(klass)
      end
    end

    it "the component layer is theme-agnostic — no literal colours, only aliases" do
      tokens = File.read(File.expand_path(
                           "../../../lib/generators/seams/design/templates/app/assets/tailwind/_tokens.css", __dir__
                         ))
      component_layer = tokens[/@layer components\{.*\}/m]
      # the only literal colours allowed in the component layer are pure
      # black/white (#000 / #fff) for fills on accent/ink — everything else
      # must read a var(--…). No hex like #1a1714 or #7a1f1f.
      stray = component_layer.scan(/#[0-9a-fA-F]{6}/)
      expect(stray).to be_empty, "component layer must not name 6-digit hex colours: #{stray.uniq}"
    end
  end

  # ---- #28: README ---------------------------------------------------------

  describe "regenerated README (Phase 3 sections)" do
    before { run_generator }

    it "documents --shell, eject/override, and the example-theme retheme", :aggregate_failures do
      readme = host("engines/design/README.md")
      expect(readme).to include("--shell")
      expect(readme).to include("design:component")           # extend
      expect(readme).to include("bin/seams resolve --eject")  # override
      expect(readme).to include('@import "themes/quire"')     # retheme
    end
  end
end
