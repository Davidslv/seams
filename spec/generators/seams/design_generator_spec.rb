# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/design/design_generator"

RSpec.describe Seams::Generators::DesignGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/design_generator", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
    seed_host_files
  end

  # Seed the host files the generator's wire_into_host edits, so the
  # idempotent injections have something to write into. Mirrors a freshly
  # `rails new`d host.
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

  def host(relative)
    File.read(File.join(destination_root, relative))
  end

  before do
    prepare_destination
    run_generator
  end

  describe "engine entry point" do
    it "places the engine under the bare Design namespace, NON-isolated" do
      assert_file "engines/design/lib/design/engine.rb" do |content|
        expect(content).to include("module Design")
        expect(content).to include("class Engine < ::Rails::Engine")
        # The whole point (D4): no isolate_namespace.
        expect(content).not_to include("isolate_namespace")
      end
    end

    it "wires the helper into ActionController::Base via to_prepare" do
      assert_file "engines/design/lib/design/engine.rb" do |content|
        expect(content).to include("config.to_prepare")
        expect(content).to include("Design.reset_component_names!")
        expect(content).to include("Design::UiHelper.define_component_helpers!")
        expect(content).to include("ActionController::Base.helper(Design::UiHelper)")
      end
    end

    it "requires version + components + engine from lib/design.rb" do
      assert_file "engines/design/lib/design.rb" do |content|
        expect(content).to include("module Design")
        expect(content).to include('require "design/version"')
        expect(content).to include('require "design/components"')
        expect(content).to include('require "design/engine"')
      end
    end
  end

  describe "auto-wire registry" do
    it "derives component_names from the ui/previews partials" do
      assert_file "engines/design/lib/design/components.rb" do |content|
        expect(content).to include("def component_names")
        expect(content).to include("def reset_component_names!")
        expect(content).to include("def previews_root")
        expect(content).to include('"ui", "previews"')
      end
    end
  end

  describe "ui helper" do
    it "ships UiHelper with ui_icon + the ui_<name> auto-wire", :aggregate_failures do
      assert_file "engines/design/app/helpers/design/ui_helper.rb" do |content|
        expect(content).to include("module Design")
        expect(content).to include("module UiHelper")
        expect(content).to include("def ui_icon")
        expect(content).to include("def self.define_component_helpers!")
        expect(content).to include("method_name = \"ui_\#{name}\"")
        expect(content).to include("render \"ui/\#{name}\"")
      end
    end
  end

  describe "form builder" do
    it "ships Design::FormBuilder adding ui_* field methods only", :aggregate_failures do
      assert_file "engines/design/app/form_builders/design/form_builder.rb" do |content|
        expect(content).to include("module Design")
        expect(content).to include("class FormBuilder < ActionView::Helpers::FormBuilder")
        expect(content).to include("define_method(:\"ui_\#{kind}_field\")")
        expect(content).to include('@template.render("ui/field"')
        expect(content).to include("def ui_text_area")
        expect(content).to include("def ui_select")
        expect(content).to include("def ui_submit")
      end
    end
  end

  describe "icon partials" do
    it "ships the icon partial referencing the ui-icon-<name> sprite fragment" do
      assert_file "engines/design/app/views/ui/_icon.html.erb" do |content|
        expect(content).to include("#ui-icon-")
      end
    end

    it "ships the icon sprite with ui-icon-* symbols" do
      assert_file "engines/design/app/views/ui/_icon_sprite.html.erb" do |content|
        expect(content).to include('id="ui-icon-close"')
        expect(content).to include('id="ui-icon-check"')
      end
    end
  end

  describe "isolated-engine leftovers removed" do
    it "removes the base Design::ApplicationController" do
      full = File.join(destination_root, "engines/design/app/controllers/design/application_controller.rb")
      expect(File.exist?(full)).to be(false)
    end

    it "removes the base Design::ApplicationRecord" do
      full = File.join(destination_root, "engines/design/app/models/design/application_record.rb")
      expect(File.exist?(full)).to be(false)
    end

    it "KEEPS an empty config/routes.rb so the engine stays mountable" do
      assert_file "engines/design/config/routes.rb" do |content|
        expect(content).to include("Design::Engine.routes.draw do")
      end
    end
  end

  describe "runtime spec" do
    it "ships a boot spec covering the non-isolated wiring + auto-wire + form builder" do
      assert_file "engines/design/spec/runtime/design_boot_spec.rb" do |content|
        [
          "Design engine boot",
          "Design::Engine",
          "isolated?",
          "Design.component_names",
          "Design::UiHelper",
          "ActionController::Base.helpers",
          "Design::FormBuilder"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end

  describe "README" do
    it "documents the non-isolated wiring + Tailwind dependency + ui_* usage" do
      assert_file "engines/design/README.md" do |content|
        %w[ui_button Tailwind Non-isolated FormBuilder ui_text_field].each do |needle|
          expect(content).to include(needle)
        end
      end
    end
  end

  describe "host wiring — Gemfile" do
    it "injects tailwindcss-rails" do
      expect(host("Gemfile")).to include('gem "tailwindcss-rails", "~> 4.0"')
    end
  end

  describe "host wiring — Tailwind tokens" do
    it "writes the neutral @theme token block into the host application.css", :aggregate_failures do
      assert_file "app/assets/tailwind/application.css" do |content|
        expect(content).to include('@import "tailwindcss"')
        expect(content).to include("seams:design tokens")
        expect(content).to include("@theme")
        expect(content).to include("--color-paper")
        expect(content).to include("--color-accent")
        # NEUTRAL default — NOT quire's garnet/Spectral.
        expect(content).not_to include("garnet")
        expect(content).not_to include("Spectral")
      end
    end
  end

  describe "host wiring — default form builder" do
    it "sets Design::FormBuilder as the host default form builder" do
      expect(host("config/application.rb"))
        .to include('config.action_view.default_form_builder = "Design::FormBuilder"')
    end
  end

  describe "host wiring — icon sprite in the layout" do
    it "renders the sprite near the top of <body>" do
      expect(host("app/views/layouts/application.html.erb"))
        .to include('<%= render "ui/icon_sprite" %>')
    end
  end

  describe "idempotency" do
    it "does not duplicate host injections on a second run" do
      run_generator # second invocation

      expect(host("Gemfile").scan('gem "tailwindcss-rails"').size).to eq(1)
      expect(host("app/assets/tailwind/application.css").scan("seams:design tokens").size).to eq(1)
      expect(host("config/application.rb").scan("default_form_builder").size).to eq(1)
      expect(host("app/views/layouts/application.html.erb").scan('render "ui/icon_sprite"').size).to eq(1)
    end
  end

  describe "generator surface" do
    let(:gen_path) do
      File.expand_path("../../../lib/generators/seams/design/design_generator.rb", __dir__)
    end

    it "includes HostInjector + EjectAware" do
      content = File.read(gen_path)
      expect(content).to include("include Seams::Generators::HostInjector")
      expect(content).to include("include Seams::Generators::EjectAware")
    end

    it "injects tailwindcss-rails in wire_into_host" do
      content = File.read(gen_path)
      expect(content).to include('host_inject_gem("tailwindcss-rails", "~> 4.0")')
    end
  end
end
