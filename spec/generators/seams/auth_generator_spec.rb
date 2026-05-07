# frozen_string_literal: true

require "rails/generators"
require "rails/generators/test_case"
require "yaml"
require "generators/seams/auth/auth_generator"

RSpec.describe Seams::Generators::AuthGenerator do
  let(:destination_root) { File.expand_path("../../../tmp/auth_generator", __dir__) }

  def prepare_destination
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)
    FileUtils.mkdir_p(File.join(destination_root, "engines"))
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

  describe "engine entry point" do
    it "registers the four canonical auth events in the engine initializer" do
      assert_file "engines/auth/lib/auth/engine.rb" do |content|
        expect(content).to include('Seams::EventRegistry.register("user.signed_up.auth"')
        expect(content).to include('Seams::EventRegistry.register("user.signed_in.auth"')
        expect(content).to include('Seams::EventRegistry.register("user.signed_out.auth"')
        expect(content).to include('Seams::EventRegistry.register("session.expired.auth"')
      end
    end

    it "uses isolate_namespace Auth" do
      assert_file "engines/auth/lib/auth/engine.rb" do |content|
        expect(content).to include("isolate_namespace Auth")
      end
    end
  end

  describe "models" do
    it "creates the Auth::User model with has_secure_password and table mapping" do
      assert_file "engines/auth/app/models/auth/user.rb" do |content|
        expect(content).to include("class User < ApplicationRecord")
        expect(content).to include("has_secure_password")
        expect(content).to include('self.table_name = "auth_users"')
      end
    end

    it "creates the Auth::Session model with token + expiry assignment" do
      assert_file "engines/auth/app/models/auth/session.rb" do |content|
        expect(content).to include("class Session < ApplicationRecord")
        expect(content).to include("SecureRandom.hex(32)")
        expect(content).to include("Auth.configuration.session_ttl")
      end
    end

    it "creates Auth::ApplicationRecord as an abstract class" do
      assert_file "engines/auth/app/models/auth/application_record.rb" do |content|
        expect(content).to include("self.abstract_class = true")
      end
    end
  end

  describe "controllers" do
    it "creates SessionsController with sign-in / sign-out actions and event publishes" do
      assert_file "engines/auth/app/controllers/auth/sessions_controller.rb" do |content|
        expect(content).to include('Seams::Events::Publisher.publish("user.signed_in.auth"')
        expect(content).to include('Seams::Events::Publisher.publish("user.signed_out.auth"')
      end
    end

    it "creates RegistrationsController with sign-up that publishes user.signed_up.auth" do
      assert_file "engines/auth/app/controllers/auth/registrations_controller.rb" do |content|
        expect(content).to include('Seams::Events::Publisher.publish("user.signed_up.auth"')
      end
    end
  end

  describe "exposed concerns" do
    it "creates Auth::Authenticatable" do
      assert_file "engines/auth/lib/auth/concerns/authenticatable.rb" do |content|
        expect(content).to include("module Authenticatable")
        expect(content).to include('require "active_support/concern"')
      end
    end

    it "creates Auth::Authentication with current_user / authenticate_user! helpers" do
      assert_file "engines/auth/lib/auth/concerns/authentication.rb" do |content|
        expect(content).to include("def current_user")
        expect(content).to include("def authenticate_user!")
        expect(content).to include('require "active_support/concern"')
      end
    end

    it "registers both concerns in the engine's ExposedConcerns rubocop list" do
      assert_file "engines/auth/.rubocop.yml" do |content|
        expect(content).to include("Auth::Authenticatable")
        expect(content).to include("Auth::Authentication")
      end
    end
  end

  describe "configuration" do
    it "creates Auth::Configuration with session_ttl + cookie_name knobs" do
      assert_file "engines/auth/lib/auth/configuration.rb" do |content|
        expect(content).to include("attr_accessor :session_ttl, :cookie_name")
      end
    end

    it "rewrites lib/auth.rb to expose Auth.configure" do
      assert_file "engines/auth/lib/auth.rb" do |content|
        expect(content).to include("def configure")
        expect(content).to include("def configuration")
      end
    end
  end

  describe "views" do
    it "creates ERB templates for sessions and registrations new" do
      assert_file "engines/auth/app/views/auth/sessions/new.html.erb"
      assert_file "engines/auth/app/views/auth/registrations/new.html.erb"
    end
  end

  describe "migrations" do
    it "creates the auth_users migration with a leading comment block" do
      pattern = File.join(destination_root, "engines/auth/db/migrate", "*_create_auth_users.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("# What:")
      expect(content).to include("# Why:")
      expect(content).to include("create_table :auth_users")
    end

    it "creates the auth_sessions migration referencing auth_users" do
      pattern = File.join(destination_root, "engines/auth/db/migrate", "*_create_auth_sessions.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :auth_sessions")
      expect(content).to include("to_table: :auth_users")
    end
  end

  describe "routes" do
    it "draws sessions and registrations routes" do
      assert_file "engines/auth/config/routes.rb" do |content|
        expect(content).to include("controller: :sessions")
        expect(content).to include("controller: :registrations")
      end
    end
  end

  describe "documentation + specs" do
    it "rewrites the README with the canonical events table" do
      assert_file "engines/auth/README.md" do |content|
        expect(content).to include("user.signed_up.auth")
        expect(content).to include("Auth::Authenticatable")
      end
    end

    it "creates user_spec and session_spec files" do
      assert_file "engines/auth/spec/models/auth/user_spec.rb"
      assert_file "engines/auth/spec/models/auth/session_spec.rb"
    end
  end
end
