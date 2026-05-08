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
    it "registers the canonical auth events in the engine initializer" do
      assert_file "engines/auth/lib/auth/engine.rb" do |content|
        expect(content).to include('Seams::EventRegistry.register("identity.signed_up.auth"')
        expect(content).to include('Seams::EventRegistry.register("identity.signed_in.auth"')
        expect(content).to include('Seams::EventRegistry.register("identity.signed_out.auth"')
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
    it "creates the Auth::Identity model with has_secure_password and table mapping" do
      assert_file "engines/auth/app/models/auth/identity.rb" do |content|
        expect(content).to include("class Identity < ApplicationRecord")
        expect(content).to include("has_secure_password")
        expect(content).to include('self.table_name = "auth_identities"')
        # Rails 8 reset_token feature is on by default — no opt-out workaround.
        expect(content).not_to include("reset_token: false")
      end
    end

    it "creates the Auth::Session model with token + expiry assignment" do
      assert_file "engines/auth/app/models/auth/session.rb" do |content|
        expect(content).to include("class Session < ApplicationRecord")
        expect(content).to include("SecureRandom.hex(32)")
        expect(content).to include("Auth.configuration.session_ttl")
        expect(content).to include("belongs_to :identity")
      end
    end

    it "creates Auth::ApplicationRecord as an abstract class" do
      assert_file "engines/auth/app/models/auth/application_record.rb" do |content|
        expect(content).to include("self.abstract_class = true")
      end
    end

    it "creates Auth::Current with an :identity attribute" do
      assert_file "engines/auth/app/models/auth/current.rb" do |content|
        expect(content).to include("class Current < ActiveSupport::CurrentAttributes")
        expect(content).to include("attribute :identity")
      end
    end
  end

  describe "controllers" do
    it "creates SessionsController that delegates to Auth::AuthenticateIdentity" do
      assert_file "engines/auth/app/controllers/auth/sessions_controller.rb" do |content|
        expect(content).to include("Auth::AuthenticateIdentity.call")
      end
    end

    it "creates RegistrationsController that delegates to Auth::RegisterIdentity" do
      assert_file "engines/auth/app/controllers/auth/registrations_controller.rb" do |content|
        expect(content).to include("Auth::RegisterIdentity.call")
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
    it "creates Auth::RegisterIdentity that publishes identity.signed_up.auth" do
      assert_file "engines/auth/app/services/auth/register_identity.rb" do |content|
        expect(content).to include("class RegisterIdentity")
        expect(content).to include('"identity.signed_up.auth"')
      end
    end

    it "creates Auth::AuthenticateIdentity that publishes identity.signed_in.auth" do
      assert_file "engines/auth/app/services/auth/authenticate_identity.rb" do |content|
        expect(content).to include("class AuthenticateIdentity")
        expect(content).to include('"identity.signed_in.auth"')
      end
    end

    it "creates Auth::ResetPassword backed by Rails 8 has_secure_password reset_token", :aggregate_failures do
      assert_file "engines/auth/app/services/auth/reset_password.rb" do |content|
        expect(content).to include("def request")
        expect(content).to include("def complete")
        expect(content).to include("find_by_password_reset_token")
        # No more column-based token / TOKEN_TTL constant — Rails 8
        # signed_id has built-in expiry. The column-based assignments
        # are gone (only a doc-comment may mention the old column).
        expect(content).not_to include("TOKEN_TTL")
        expect(content).not_to match(/password_reset_token: SecureRandom/)
        expect(content).not_to match(/password_reset_token_sent_at:/)
      end
    end
  end

  describe "mailer" do
    it "creates Auth::PasswordsMailer + reset_email template" do
      assert_file "engines/auth/app/mailers/auth/passwords_mailer.rb" do |content|
        expect(content).to include("class PasswordsMailer < ::ApplicationMailer")
        expect(content).to include("def reset_email")
        expect(content).to include("identity.password_reset_token")
      end
      assert_file "engines/auth/app/views/auth/passwords_mailer/reset_email.html.erb"
    end
  end

  describe "exposed concerns" do
    it "creates Auth::Authenticatable that links via identity_id (post-Wave-9 OPTIONAL)" do
      assert_file "engines/auth/lib/auth/concerns/authenticatable.rb" do |content|
        expect(content).to include("module Authenticatable")
        expect(content).to include('require "active_support/concern"')
        expect(content).to include("auth_identity")
        expect(content).to include("identity_id")
      end
    end

    it "creates Auth::Authentication with current_identity / authenticate_identity! helpers" do
      assert_file "engines/auth/lib/auth/concerns/authentication.rb" do |content|
        expect(content).to include("def current_identity")
        expect(content).to include("def authenticate_identity!")
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
    it "creates the auth_identities migration with a leading comment block" do
      pattern = File.join(destination_root, "engines/auth/db/migrate", "*_create_auth_identities.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("# What:")
      expect(content).to include("# Why:")
      expect(content).to include("create_table :auth_identities")
      expect(content).to include(":staff")
    end

    it "creates the auth_sessions migration referencing auth_identities" do
      pattern = File.join(destination_root, "engines/auth/db/migrate", "*_create_auth_sessions.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :auth_sessions")
      expect(content).to include("to_table: :auth_identities")
      expect(content).to include(":identity")
    end

    it "does NOT create a password_reset migration (Rails 8 signed_id replaces the column)" do
      pattern = File.join(destination_root,
                          "engines/auth/db/migrate",
                          "*_add_password_reset_to_auth_*.rb")
      expect(Dir[pattern]).to be_empty
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
        expect(content).to include("identity.signed_up.auth")
        expect(content).to include("Auth::Authenticatable")
      end
    end

    it "creates identity_spec and session_spec files" do
      assert_file "engines/auth/spec/models/auth/identity_spec.rb"
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

    it "OAuth::Provider model uses encrypts for tokens + correct uniqueness scopes" do
      assert_file "engines/auth/app/models/auth/oauth/provider.rb" do |content|
        expect(content).to include("encrypts :access_token")
        expect(content).to include("encrypts :refresh_token")
        expect(content).to include("uniqueness: { scope: :provider")
        expect(content).to include("belongs_to :identity")
      end
    end

    it "create_auth_oauth_providers migration exists with unique indexes on identity_id" do
      pattern = File.join(destination_root,
                          "engines/auth/db/migrate",
                          "*_create_auth_oauth_providers.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :auth_oauth_providers")
      expect(content).to include("add_index :auth_oauth_providers, %i[provider provider_uid], unique: true")
      expect(content).to include("identity_id")
    end

    it "OAuth::Authenticator service publishes the canonical signed_up/signed_in events" do
      assert_file "engines/auth/app/services/auth/oauth/authenticator.rb" do |content|
        expect(content).to include("Auth.oauth(@provider)")
        expect(content).to include("identity.signed_up.auth")
        expect(content).to include("identity.signed_in.auth")
        expect(content).to include("identity_id")
      end
    end

    it "OAuth::CallbacksController verifies state on callback (CSRF guard)" do
      assert_file "engines/auth/app/controllers/auth/oauth/callbacks_controller.rb" do |content|
        expect(content).to include("def start")
        expect(content).to include("def callback")
        expect(content).to include("OAuth state mismatch")
        expect(content).to include("Auth::OAuth::Authenticator.call")
      end
    end

    it "routes register the per-provider start + callback URLs" do
      assert_file "engines/auth/config/routes.rb" do |content|
        expect(content).to include('scope "/oauth/:provider"')
        expect(content).to include("oauth/callbacks#start")
        expect(content).to include("oauth/callbacks#callback")
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
          "scope :active",
          "belongs_to :identity"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships the create_auth_api_tokens migration with unique digest index + identity_id reference" do
      pattern = File.join(destination_root,
                          "engines/auth/db/migrate",
                          "*_create_auth_api_tokens.rb")
      file    = Dir[pattern].first
      expect(file).not_to be_nil

      content = File.read(file)
      expect(content).to include("create_table :auth_api_tokens")
      expect(content).to include(":token_digest")
      expect(content).to include("add_index :auth_api_tokens, :token_digest, unique: true")
      expect(content).to include(":identity")
    end

    it "ships GenerateApiToken service that returns plaintext once + publishes api_token.issued.auth" do
      assert_file "engines/auth/app/services/auth/generate_api_token.rb" do |content|
        [
          "module GenerateApiToken",
          "Result = Struct.new",
          "ApiToken::PREFIX",
          "SecureRandom.urlsafe_base64",
          "api_token.issued.auth",
          "identity_id"
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

    it "Identity model has_many :api_tokens" do
      assert_file "engines/auth/app/models/auth/identity.rb" do |content|
        expect(content).to include("has_many :api_tokens")
      end
    end

    it "ships RevokeApiToken service that destroys the row + publishes api_token.revoked.auth" do
      assert_file "engines/auth/app/services/auth/revoke_api_token.rb" do |content|
        [
          "module RevokeApiToken",
          "api_token.destroy!",
          "Seams::Events::Publisher.publish(",
          '"api_token.revoked.auth"',
          "identity_id:",
          "api_token_id:",
          "token_prefix:"
        ].each { |needle| expect(content).to include(needle) }
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

  describe "Phase 2A — factories + spec coverage" do
    it "ships FactoryBot factories for identities, sessions, oauth_providers, api_tokens" do
      assert_file "engines/auth/spec/factories/auth.rb" do |content|
        [
          "FactoryBot.define",
          "factory :auth_identity",
          "factory :auth_session",
          "factory :auth_oauth_provider",
          "factory :auth_api_token",
          "Auth::ApiToken.digest"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships ApiToken model spec covering digest + find_by_plaintext + expired? + scopes" do
      assert_file "engines/auth/spec/models/auth/api_token_spec.rb" do |content|
        [
          "RSpec.describe Auth::ApiToken",
          ".digest",
          ".find_by_plaintext",
          "#expired?",
          "scope",
          ".active"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships OAuth::Provider model spec covering encryption round-trip + uniqueness" do
      assert_file "engines/auth/spec/models/auth/oauth/provider_spec.rb" do |content|
        [
          "RSpec.describe Auth::OAuth::Provider",
          "round-trips access_token",
          "round-trips provider_uid",
          "find_by(provider: \"google\""
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships an end-to-end login flow request spec" do
      assert_file "engines/auth/spec/runtime/auth_login_flow_spec.rb" do |content|
        [
          "type: :request",
          'post "/auth/registration"',
          'post "/auth/session"',
          'delete "/auth/session"'
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "ships PasswordsMailer spec covering recipient + token embed" do
      assert_file "engines/auth/spec/mailers/auth/passwords_mailer_spec.rb" do |content|
        [
          "RSpec.describe Auth::PasswordsMailer",
          "type: :mailer",
          "described_class.reset_email(identity)"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "wire_into_host adds factory_bot_rails to the test group" do
      gen_path = File.expand_path("../../../lib/generators/seams/auth/auth_generator.rb", __dir__)
      content  = File.read(gen_path)
      expect(content).to include('host_inject_gem("factory_bot_rails"')
      expect(content).to include("group: :test")
    end
  end

  describe "PII encryption (Wave 11 GDPR)" do
    it "Identity#email is encrypted deterministically with downcase normalisation" do
      assert_file "engines/auth/app/models/auth/identity.rb" do |content|
        expect(content).to include("encrypts :email, deterministic: true, downcase: true")
      end
    end

    it "OAuth::Provider#provider_uid is encrypted deterministically" do
      assert_file "engines/auth/app/models/auth/oauth/provider.rb" do |content|
        expect(content).to include("encrypts :provider_uid, deterministic: true")
      end
    end

    it "OAuth tokens remain non-deterministically encrypted (credentials, not query targets)" do
      assert_file "engines/auth/app/models/auth/oauth/provider.rb" do |content|
        expect(content).to include("encrypts :access_token")
        expect(content).to include("encrypts :refresh_token")
        expect(content).not_to include("encrypts :access_token, deterministic")
        expect(content).not_to include("encrypts :refresh_token, deterministic")
      end
    end

    it "ships the seams:auth:rotate_pii_encryption rake task for upgrading hosts" do
      assert_file "engines/auth/lib/tasks/auth_pii.rake" do |content|
        [
          "namespace :seams",
          "namespace :auth",
          "task rotate_pii_encryption",
          "Auth::Identity.find_each",
          "Auth::OAuth::Provider.find_each",
          "identity.update!(email: identity.email)",
          "provider.update!(provider_uid: provider.provider_uid)"
        ].each { |needle| expect(content).to include(needle) }
      end
    end

    it "README documents the GDPR section: data inventory + db:encryption:init + rotation + erasure" do
      assert_file "engines/auth/README.md" do |content|
        [
          "GDPR / data protection",
          "db:encryption:init",
          "seams:auth:rotate_pii_encryption",
          "Right to erasure",
          "support_unencrypted_data"
        ].each { |needle| expect(content).to include(needle) }
      end
    end
  end
end
