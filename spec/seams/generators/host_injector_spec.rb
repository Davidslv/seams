# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams/generators/host_injector"

RSpec.describe Seams::Generators::HostInjector do
  let(:destination_root) { File.expand_path("../../tmp/host_injector_spec", __dir__) }

  let(:generator_class) do
    Class.new(Rails::Generators::Base) do
      include Seams::Generators::HostInjector
    end
  end

  let(:generator) { generator_class.new([], [], destination_root: destination_root) }

  before do
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    FileUtils.mkdir_p(File.join(destination_root, "app/models"))
    FileUtils.mkdir_p(File.join(destination_root, "app/controllers"))
    File.write(File.join(destination_root, "Gemfile"), "source \"https://rubygems.org\"\n")
    File.write(File.join(destination_root, "config/routes.rb"),
               "Rails.application.routes.draw do\nend\n")
    File.write(File.join(destination_root, "app/models/user.rb"),
               "class User < ApplicationRecord\nend\n")
    File.write(File.join(destination_root, "app/controllers/application_controller.rb"),
               "class ApplicationController < ActionController::Base\nend\n")
  end

  after { FileUtils.rm_rf(destination_root) }

  describe "#host_inject_gem" do
    it "appends a gem line to the Gemfile" do
      generator.host_inject_gem("stripe")
      expect(File.read(File.join(destination_root, "Gemfile"))).to include('gem "stripe"')
    end

    it "is idempotent" do
      generator.host_inject_gem("stripe")
      generator.host_inject_gem("stripe")
      gemfile = File.read(File.join(destination_root, "Gemfile"))
      expect(gemfile.scan('gem "stripe"').size).to eq(1)
    end

    it "supports a version constraint" do
      generator.host_inject_gem("stripe", "~> 12.0")
      expect(File.read(File.join(destination_root, "Gemfile"))).to include('gem "stripe", "~> 12.0"')
    end

    it "supports a group" do
      generator.host_inject_gem("rspec-rails", group: :test)
      content = File.read(File.join(destination_root, "Gemfile"))
      expect(content).to include("group :test do")
      expect(content).to include('gem "rspec-rails"')
    end
  end

  describe "#host_inject_mount" do
    it "adds a mount line inside the routes block" do
      generator.host_inject_mount(engine_class: "Auth::Engine", at: "/auth")
      routes = File.read(File.join(destination_root, "config/routes.rb"))
      expect(routes).to include('mount Auth::Engine, at: "/auth"')
    end

    it "is idempotent" do
      generator.host_inject_mount(engine_class: "Auth::Engine", at: "/auth")
      generator.host_inject_mount(engine_class: "Auth::Engine", at: "/auth")
      routes = File.read(File.join(destination_root, "config/routes.rb"))
      expect(routes.scan("mount Auth::Engine").size).to eq(1)
    end
  end

  describe "#host_inject_include_in_user" do
    it "adds an include to the User class" do
      generator.host_inject_include_in_user("Auth::Authenticatable")
      content = File.read(File.join(destination_root, "app/models/user.rb"))
      expect(content).to include("include Auth::Authenticatable")
    end

    it "is idempotent" do
      generator.host_inject_include_in_user("Auth::Authenticatable")
      generator.host_inject_include_in_user("Auth::Authenticatable")
      content = File.read(File.join(destination_root, "app/models/user.rb"))
      expect(content.scan("include Auth::Authenticatable").size).to eq(1)
    end

    it "warns instead of erroring when User does not exist" do
      FileUtils.rm(File.join(destination_root, "app/models/user.rb"))
      expect { generator.host_inject_include_in_user("Auth::Authenticatable") }.not_to raise_error
    end
  end

  describe "#host_inject_include_in_application_controller" do
    it "adds an include to the ApplicationController class" do
      generator.host_inject_include_in_application_controller("Auth::Authentication")
      content = File.read(File.join(destination_root, "app/controllers/application_controller.rb"))
      expect(content).to include("include Auth::Authentication")
    end
  end

  describe "uninject methods" do
    it "removes a gem line from the Gemfile" do
      generator.host_inject_gem("stripe")
      generator.host_uninject_gem("stripe")
      expect(File.read(File.join(destination_root, "Gemfile"))).not_to include('gem "stripe"')
    end

    it "removes a mount line from routes" do
      generator.host_inject_mount(engine_class: "Auth::Engine", at: "/auth")
      generator.host_uninject_mount(engine_class: "Auth::Engine")
      expect(File.read(File.join(destination_root, "config/routes.rb"))).not_to include("mount Auth::Engine")
    end

    it "removes an include line from a host file" do
      generator.host_inject_include_in_user("Auth::Authenticatable")
      generator.host_uninject_include("app/models/user.rb", "Auth::Authenticatable")
      content = File.read(File.join(destination_root, "app/models/user.rb"))
      expect(content).not_to include("include Auth::Authenticatable")
    end
  end

  describe "prefix-collision regressions (Wave 5 review fixes)" do
    it "host_inject_mount injects Auth::Engine even when Auth::EngineExtras is already mounted" do
      File.write(File.join(destination_root, "config/routes.rb"), <<~RB)
        Rails.application.routes.draw do
          mount Auth::EngineExtras, at: "/x"
        end
      RB

      generator.host_inject_mount(engine_class: "Auth::Engine", at: "/auth")
      content = File.read(File.join(destination_root, "config/routes.rb"))
      expect(content).to include("mount Auth::Engine,")
      expect(content).to include("mount Auth::EngineExtras,")
    end

    it "host_uninject_mount deletes only the exact class, not prefix matches" do
      File.write(File.join(destination_root, "config/routes.rb"), <<~RB)
        Rails.application.routes.draw do
          mount Auth::Engine, at: "/auth"
          mount Auth::EngineExtras, at: "/x"
        end
      RB

      generator.host_uninject_mount(engine_class: "Auth::Engine")
      content = File.read(File.join(destination_root, "config/routes.rb"))
      expect(content).not_to match(/mount Auth::Engine,/)
      expect(content).to     include("mount Auth::EngineExtras,")
    end

    it "host_inject_mount works with `do |routes|` block-arg form" do
      File.write(File.join(destination_root, "config/routes.rb"), <<~RB)
        Rails.application.routes.draw do |routes|
        end
      RB

      generator.host_inject_mount(engine_class: "Foo::Engine", at: "/foo")
      content = File.read(File.join(destination_root, "config/routes.rb"))
      expect(content).to include("mount Foo::Engine, at: \"/foo\"")
    end
  end
end
