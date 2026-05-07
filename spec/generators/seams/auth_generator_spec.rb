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
    it "creates SessionsController that delegates to Auth::AuthenticateUser" do
      assert_file "engines/auth/app/controllers/auth/sessions_controller.rb" do |content|
        expect(content).to include("Auth::AuthenticateUser.call")
      end
    end

    it "creates RegistrationsController that delegates to Auth::RegisterUser" do
      assert_file "engines/auth/app/controllers/auth/registrations_controller.rb" do |content|
        expect(content).to include("Auth::RegisterUser.call")
      end
    end

    it "creates PasswordResetsController with new/create/edit/update" do
      assert_file "engines/auth/app/controllers/auth/password_resets_controller.rb" do |content|
        expect(content).to include("Auth::ResetPassword.request")
        expect(content).to include("Auth::ResetPassword.complete")
      end
    end
  end

  describe "services" do
    it "creates Auth::RegisterUser that publishes user.signed_up.auth" do
      assert_file "engines/auth/app/services/auth/register_user.rb" do |content|
        expect(content).to include("class RegisterUser")
        expect(content).to include('"user.signed_up.auth"')
      end
    end

    it "creates Auth::AuthenticateUser that publishes user.signed_in.auth" do
      assert_file "engines/auth/app/services/auth/authenticate_user.rb" do |content|
        expect(content).to include("class AuthenticateUser")
        expect(content).to include('"user.signed_in.auth"')
      end
    end

    it "creates Auth::ResetPassword with two-phase request/complete API" do
      assert_file "engines/auth/app/services/auth/reset_password.rb" do |content|
        expect(content).to include("def request")
        expect(content).to include("def complete")
        expect(content).to include("TOKEN_TTL")
      end
    end
  end

  describe "mailer" do
    it "creates Auth::PasswordsMailer + reset_email template" do
      assert_file "engines/auth/app/mailers/auth/passwords_mailer.rb" do |content|
        expect(content).to include("class PasswordsMailer < ::ApplicationMailer")
        expect(content).to include("def reset_email")
      end
      assert_file "engines/auth/app/views/auth/passwords_mailer/reset_email.html.erb"
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
    it "creates ERB templates for sessions, registrations, and password resets" do
      %w[
        sessions/new
        registrations/new
        password_resets/new
        password_resets/edit
      ].each do |view|
        assert_file "engines/auth/app/views/auth/#{view}.html.erb"
      end
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

    it "creates the password-reset migration with token + sent_at columns" do
      pattern = File.join(destination_root,
                          "engines/auth/db/migrate",
                          "*_add_password_reset_to_auth_users.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("add_column :auth_users, :password_reset_token")
      expect(content).to include("password_reset_token_sent_at")
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

  describe "OAuth (Google + GitHub via Faraday)" do
    it "ships the abstract OAuth adapter contract" do
      assert_file "engines/auth/lib/auth/oauth/abstract.rb" do |content|
        [
          "class Abstract",
          "def authorize_url",
          "def exchange_code",
          "def fetch_user_info",
          "Profile = Struct.new",
          "Faraday.new"
        ].each { |needle| expect(content).to include(needle.tr("\\", "")) }
      end
    end

    it "ships the Google adapter with verified URLs + openid+email+profile scopes" do
      assert_file "engines/auth/lib/auth/oauth/google.rb" do |content|
        [
          "accounts.google.com/o/oauth2/v2/auth",
          "oauth2.googleapis.com/token",
          "openidconnect.googleapis.com/v1/userinfo",
          "openid email profile"
        ].each { |needle| expect(content).to include(needle.tr("\\", "")) }
      end
    end

    it "ships the GitHub adapter with verified URLs + read:user user:email scopes + JSON Accept" do
      assert_file "engines/auth/lib/auth/oauth/github.rb" do |content|
        [
          "github.com/login/oauth/authorize",
          "github.com/login/oauth/access_token",
          "api.github.com/user",
          "api.github.com/user/emails",
          "read:user user:email",
          "application/json"
        ].each { |needle| expect(content).to include(needle.tr("\\", "")) }
      end
    end

    it "Auth.oauth(:provider) builder + OAuthProviderUnknown error class are defined" do
      assert_file "engines/auth/lib/auth.rb" do |content|
        expect(content).to include("def oauth(provider_name)")
        expect(content).to include("OAuthProviderUnknown")
      end
    end

    it "Configuration exposes oauth_providers Hash with documentation" do
      assert_file "engines/auth/lib/auth/configuration.rb" do |content|
        expect(content).to include("oauth_providers")
        expect(content).to include("Auth::OAuth::Google")
        expect(content).to include("Auth::OAuth::Github")
      end
    end

    it "OAuthProvider model uses encrypts for tokens + correct uniqueness scopes" do
      assert_file "engines/auth/app/models/auth/oauth_provider.rb" do |content|
        expect(content).to include("encrypts :access_token")
        expect(content).to include("encrypts :refresh_token")
        expect(content).to include("uniqueness: { scope: :provider")
      end
    end

    it "create_auth_oauth_providers migration exists with unique indexes" do
      pattern = File.join(destination_root,
                          "engines/auth/db/migrate",
                          "*_create_auth_oauth_providers.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :auth_oauth_providers")
      expect(content).to include("add_index :auth_oauth_providers, %i[provider provider_uid], unique: true")
    end

    it "OAuthAuthenticator service publishes the canonical signed_up/signed_in events" do
      assert_file "engines/auth/app/services/auth/oauth_authenticator.rb" do |content|
        expect(content).to include("Auth.oauth(@provider)")
        expect(content).to include("user.signed_up.auth")
        expect(content).to include("user.signed_in.auth")
        expect(content).to include("auth_user_id")
        expect(content).to include("host_user_id")
      end
    end

    it "OAuthCallbacksController verifies state on callback (CSRF guard)" do
      assert_file "engines/auth/app/controllers/auth/oauth_callbacks_controller.rb" do |content|
        expect(content).to include("def start")
        expect(content).to include("def callback")
        expect(content).to include("OAuth state mismatch")
        expect(content).to include("Auth::OAuthAuthenticator.call")
      end
    end

    it "routes register the per-provider start + callback URLs" do
      assert_file "engines/auth/config/routes.rb" do |content|
        expect(content).to include('scope "/oauth/:provider"')
        expect(content).to include("oauth_callbacks#start")
        expect(content).to include("oauth_callbacks#callback")
      end
    end

    it "ships the _oauth_buttons partial that iterates configured providers" do
      assert_file "engines/auth/app/views/auth/sessions/_oauth_buttons.html.erb" do |content|
        expect(content).to include("Auth.configuration.oauth_providers.each_key")
        expect(content).to include("auth.oauth_start_path(provider: provider)")
      end
    end

    it "wire_into_host adds faraday (in addition to bcrypt) so OAuth adapters can be loaded" do
      gen_path = File.expand_path("../../../lib/generators/seams/auth/auth_generator.rb", __dir__)
      content  = File.read(gen_path)
      expect(content).to include('host_inject_gem("faraday"')
    end
  end

  describe "API tokens (Bearer auth)" do
    it "ships the ApiToken model with SHA-256 digest + find_by_plaintext + expired?" do
      assert_file "engines/auth/app/models/auth/api_token.rb" do |content|
        [
          'self.table_name = "auth_api_tokens"',
          'PREFIX           = "seam_"',
          "Digest::SHA256.hexdigest",
          "def self.find_by_plaintext",
          "def expired?",
          "def touch_last_used!",
          "scope :active"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships the create_auth_api_tokens migration with unique digest index" do
      pattern = File.join(destination_root,
                          "engines/auth/db/migrate",
                          "*_create_auth_api_tokens.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :auth_api_tokens")
      expect(content).to include(":token_digest")
      expect(content).to include("add_index :auth_api_tokens, :token_digest, unique: true")
    end

    it "ships GenerateApiToken service that returns plaintext once + publishes api_token.issued.auth" do
      assert_file "engines/auth/app/services/auth/generate_api_token.rb" do |content|
        [
          "module GenerateApiToken",
          "Result = Struct.new",
          "ApiToken::PREFIX",
          "SecureRandom.urlsafe_base64",
          "api_token.issued.auth",
          "auth_user_id",
          "host_user_id"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships ApiAuthenticatable concern with Bearer header parsing + 401 on invalid token" do
      assert_file "engines/auth/lib/auth/concerns/api_authenticatable.rb" do |content|
        [
          "module ApiAuthenticatable",
          "def authenticate_api_token!",
          "Bearer ",
          "Auth::ApiToken.find_by_plaintext",
          "token.touch_last_used!",
          "render_unauthorized!"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "User model has_many :api_tokens" do
      assert_file "engines/auth/app/models/auth/user.rb" do |content|
        expect(content).to include("has_many :api_tokens")
      end
    end

    it "registers api_token.issued.auth + api_token.revoked.auth in the engine event registry" do
      assert_file "engines/auth/lib/auth/engine.rb" do |content|
        expect(content).to include('"api_token.issued.auth"')
        expect(content).to include('"api_token.revoked.auth"')
      end
    end
  end

  describe "Rate limiting (Rails 8 built-in)" do
    it "SessionsController#create is rate-limited to 10/minute" do
      assert_file "engines/auth/app/controllers/auth/sessions_controller.rb" do |content|
        expect(content).to include("rate_limit")
        expect(content).to include("to: 10")
        expect(content).to include("within: 1.minute")
      end
    end

    it "RegistrationsController#create is rate-limited to 5/hour" do
      assert_file "engines/auth/app/controllers/auth/registrations_controller.rb" do |content|
        expect(content).to include("rate_limit")
        expect(content).to include("to: 5")
        expect(content).to include("within: 1.hour")
      end
    end

    it "PasswordResetsController is rate-limited to 5/hour for create + update" do
      assert_file "engines/auth/app/controllers/auth/password_resets_controller.rb" do |content|
        expect(content).to include("rate_limit")
        expect(content).to include("to: 5")
        expect(content).to include("within: 1.hour")
      end
    end
  end

  describe "Background jobs" do
    it "ships ApplicationJob base class scoped to Auth" do
      assert_file "engines/auth/app/jobs/auth/application_job.rb" do |content|
        expect(content).to include("class ApplicationJob")
      end
    end

    it "ships CleanupExpiredSessionsJob that publishes session.expired.auth per row" do
      assert_file "engines/auth/app/jobs/auth/cleanup_expired_sessions_job.rb" do |content|
        [
          "class CleanupExpiredSessionsJob",
          "Auth::Session.where(expires_at:",
          "session.expired.auth",
          "session.destroy"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end
end
