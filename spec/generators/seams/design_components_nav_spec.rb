# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "generators/seams/design/design_generator"

# Group spec for the Phase 2 "Navigation" components (GROUPKEY = nav).
# Asserts the breadcrumb / pagination / menu / segmented / stepper / toolbar /
# outline partials + previews are emitted by the design generator, re-themed to
# the neutral ui_* tokens (no compositor_* leakage) and carrying their baked-in
# accessibility roles/aria.
RSpec.describe Seams::Generators::DesignGenerator do
  let(:destination_root) { File.expand_path("../../tmp/design_generator_nav", __dir__) }

  def nav_components
    %w[breadcrumb pagination menu segmented stepper toolbar outline]
  end

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
    seed_host_files
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

  describe "Navigation components" do
    it "ships every Navigation partial + preview", :aggregate_failures do
      nav_components.each do |name|
        assert_file "engines/design/app/views/ui/_#{name}.html.erb"
        assert_file "engines/design/app/views/ui/previews/_#{name}.html.erb" do |content|
          expect(content).to include("ui_#{name}")
          expect(content).not_to include("compositor_")
        end
      end
    end

    it "re-themes the partials to ui_* tokens — no compositor leakage", :aggregate_failures do
      nav_components.each do |name|
        assert_file "engines/design/app/views/ui/_#{name}.html.erb" do |content|
          expect(content).not_to include("compositor_")
          expect(content).not_to include("compositor-icon-")
        end
      end
    end

    it "bakes breadcrumb + pagination + outline nav landmarks with aria-current", :aggregate_failures do
      assert_file "engines/design/app/views/ui/_breadcrumb.html.erb" do |content|
        expect(content).to include('"aria-label": "Breadcrumb"')
        expect(content).to include('"aria-current": "page"')
      end

      assert_file "engines/design/app/views/ui/_pagination.html.erb" do |content|
        expect(content).to include('"aria-label": "Pagination"')
        expect(content).to include('"aria-current": (page == current ? "page" : nil)')
      end

      assert_file "engines/design/app/views/ui/_outline.html.erb" do |content|
        expect(content).to include('"aria-label": "Outline"')
        expect(content).to include('"aria-current"')
      end
    end

    it "bakes menu + segmented + toolbar roles", :aggregate_failures do
      assert_file "engines/design/app/views/ui/_menu.html.erb" do |content|
        expect(content).to include('role: "menu"')
        expect(content).to include('role: "menuitem"')
      end

      assert_file "engines/design/app/views/ui/_segmented.html.erb" do |content|
        expect(content).to include('role: "group"')
        expect(content).to include('"aria-pressed"')
      end

      assert_file "engines/design/app/views/ui/_toolbar.html.erb" do |content|
        expect(content).to include('role: "toolbar"')
        expect(content).to include('"aria-label": item[:label]')
      end
    end

    it "bakes stepper aria-current=step + done ticks via ui_icon", :aggregate_failures do
      assert_file "engines/design/app/views/ui/_stepper.html.erb" do |content|
        expect(content).to include('"aria-current": (i == current ? "step" : nil)')
        expect(content).to include("ui_icon(:check")
      end
    end
  end
end
