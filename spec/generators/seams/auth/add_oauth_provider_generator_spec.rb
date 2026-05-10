# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/auth/add_oauth_provider/add_oauth_provider_generator"

RSpec.describe Seams::Generators::Auth::AddOauthProviderGenerator do
  let(:destination_root) do
    File.expand_path("../../../tmp/add_oauth_provider_generator_spec", __dir__)
  end
  let(:engine_dir) { File.join(destination_root, "engines/auth") }

  before do
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(engine_dir)
  end

  after { FileUtils.rm_rf(destination_root) }

  # Builds the minimum subset of the auth engine the generator needs to
  # find: a configuration.rb with the auth.configuration.oauth_providers
  # marker, the abstract OAuth adapter, and the routes file. This is the
  # fixture-based decoupling from Phase 2A — the canonical engine
  # generator will produce the same shape, so the assertions here mirror
  # what the integration check will see end-to-end. The method is long
  # because it stitches together a multi-file fixture with embedded
  # heredoc bodies — splitting it up would obscure the "this is what
  # the post-Phase-2A auth engine looks like" intent.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def install_auth_engine_fixture
    FileUtils.mkdir_p(File.join(engine_dir, "lib/auth/oauth"))
    FileUtils.mkdir_p(File.join(engine_dir, "config"))
    FileUtils.mkdir_p(File.join(engine_dir, "spec/lib/auth/oauth"))

    File.write(File.join(engine_dir, "lib/auth/configuration.rb"), <<~RUBY)
      # frozen_string_literal: true

      module Auth
        class Configuration
          attr_accessor :oauth_providers
          # seams:insertion-point auth.configuration.attributes

          def initialize
            @oauth_providers = {
              # seams:insertion-point auth.configuration.oauth_providers
            }
            # seams:insertion-point auth.configuration.defaults
          end
        end
      end
    RUBY

    File.write(File.join(engine_dir, "lib/auth/oauth/abstract.rb"), <<~RUBY)
      # frozen_string_literal: true
      module Auth
        module OAuth
          class Abstract; end
        end
      end
    RUBY

    File.write(File.join(engine_dir, "config/routes.rb"), <<~RUBY)
      Auth::Engine.routes.draw do
        # seams:insertion-point auth.routes.before_session
        resource :session
        scope "/oauth/:provider" do
          get "start",    to: "oauth/callbacks#start"
          get "callback", to: "oauth/callbacks#callback"
        end
        # seams:insertion-point auth.routes.after_oauth
      end
    RUBY
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def configuration_contents
    File.read(File.join(engine_dir, "lib/auth/configuration.rb"))
  end

  def adapter_path(snake_name)
    File.join(engine_dir, "lib/auth/oauth/#{snake_name}.rb")
  end

  def adapter_spec_path(snake_name)
    File.join(engine_dir, "spec/lib/auth/oauth/#{snake_name}_spec.rb")
  end

  def run_generator(name)
    capture_output do
      described_class.start([name], destination_root: destination_root)
    end
  end

  def capture_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  describe "argument validation" do
    it "errors when no provider name is given" do
      install_auth_engine_fixture

      # Thor::Group writes the missing-argument message to stderr and
      # exits the command without running tasks. Verify both the
      # message and that no adapter was written.
      expect do
        capture_output { described_class.start([], destination_root: destination_root) }
      end.to output(/name/).to_stderr

      expect(File.exist?(adapter_path("___none___"))).to be(false)
      expect(File.exist?(File.join(engine_dir, "lib/auth/oauth"))).to satisfy do |dir_exists|
        !dir_exists || Dir.children(File.join(engine_dir, "lib/auth/oauth")).reject { |c| c == "abstract.rb" }.empty?
      end
    end

    it "errors when the name normalises to an empty string" do
      install_auth_engine_fixture

      expect { described_class.start(["___"], destination_root: destination_root) }
        .to raise_error(Seams::GeneratorError, /normalises to an empty string/)
    end
  end

  describe "name normalisation" do
    it "lower-cases mixed-case input and writes the file at the snake-case path" do
      install_auth_engine_fixture
      run_generator("LinkedIn")

      expect(File.exist?(adapter_path("linkedin"))).to be(true)
    end

    it "converts hyphens and dots to underscores" do
      install_auth_engine_fixture
      run_generator("sign-in.with-apple")

      expect(File.exist?(adapter_path("sign_in_with_apple"))).to be(true)
    end
  end

  describe "prerequisite check" do
    it "fails when the auth engine has not been generated" do
      # No fixture installed — engines/auth/ doesn't exist.
      expect { described_class.start(["linkedin"], destination_root: destination_root) }
        .to raise_error(Seams::GeneratorError, %r{bin/rails generate seams:auth})
    end

    it "fails with a clear message when the configuration marker is missing" do
      FileUtils.mkdir_p(File.join(engine_dir, "lib/auth"))
      File.write(File.join(engine_dir, "lib/auth/configuration.rb"), "module Auth; class Configuration; end; end\n")

      expect { described_class.start(["linkedin"], destination_root: destination_root) }
        .to raise_error(Seams::GeneratorError) do |error|
          expect(error.message).to include("auth.configuration.oauth_providers")
          expect(error.message).to include("bin/rails generate seams:auth")
        end
    end
  end

  describe "successful run" do
    before do
      install_auth_engine_fixture
      run_generator("linkedin")
    end

    it "creates the adapter file at engines/auth/lib/auth/oauth/<name>.rb" do
      expect(File.exist?(adapter_path("linkedin"))).to be(true)
    end

    it "subclasses Auth::OAuth::Abstract in the adapter" do
      contents = File.read(adapter_path("linkedin"))
      expect(contents).to include("class Linkedin < Abstract")
      expect(contents).to include('require "auth/oauth/abstract"')
    end

    it "documents TODOs that point at the provider's API docs" do
      contents = File.read(adapter_path("linkedin"))
      expect(contents.scan("TODO(linkedin)").size).to be >= 3
      expect(contents).to include("LINKEDIN_OAUTH_CLIENT_ID")
    end

    it "implements authorize_url, exchange_code, and fetch_user_info" do
      contents = File.read(adapter_path("linkedin"))
      expect(contents).to match(/def authorize_url\(state:, redirect_uri:\)/)
      expect(contents).to match(/def exchange_code\(code:, redirect_uri:\)/)
      expect(contents).to match(/def fetch_user_info\(access_token:\)/)
    end

    it "splices a configuration entry under the oauth_providers marker" do
      expect(configuration_contents).to include("linkedin: {")
      expect(configuration_contents).to include('adapter:       "Auth::OAuth::Linkedin"')
      expect(configuration_contents).to include('ENV.fetch("LINKEDIN_OAUTH_CLIENT_ID", nil)')
      expect(configuration_contents).to include('ENV.fetch("LINKEDIN_OAUTH_CLIENT_SECRET", nil)')
      expect(configuration_contents).to include("scopes:        %w[profile email]")
    end

    it "places the spliced entry inside the @oauth_providers hash" do
      contents = configuration_contents
      hash_open = contents.index("@oauth_providers = {")
      hash_close = contents.index(/\n {6}\}\n/, hash_open)
      expect(hash_open).not_to be_nil
      expect(hash_close).not_to be_nil
      slice = contents[hash_open..hash_close]
      expect(slice).to include("linkedin: {")
    end

    it "creates the adapter spec at engines/auth/spec/lib/auth/oauth/<name>_spec.rb" do
      expect(File.exist?(adapter_spec_path("linkedin"))).to be(true)
      contents = File.read(adapter_spec_path("linkedin"))
      expect(contents).to include("RSpec.describe Auth::OAuth::Linkedin")
      expect(contents).to include("it \"is a subclass of Auth::OAuth::Abstract\"")
    end

    it "does not splice into the routes file" do
      # The existing scope "/oauth/:provider" handles every configured
      # provider via the :provider param. The generator deliberately
      # skips auth.routes.after_oauth.
      routes = File.read(File.join(engine_dir, "config/routes.rb"))
      expect(routes).not_to include("linkedin")
    end
  end

  describe "idempotency" do
    it "running twice with the same name does not double-splice" do
      install_auth_engine_fixture

      run_generator("linkedin")
      first_pass = configuration_contents

      run_generator("linkedin")
      second_pass = configuration_contents

      expect(second_pass).to eq(first_pass)
      expect(second_pass.scan(/^\s*linkedin: \{$/).size).to eq(1)
      expect(second_pass.scan("Auth::OAuth::Linkedin").size).to eq(1)
    end
  end

  describe "engine_name declaration" do
    it "is auth — used by FollowUpGenerator to build engine_path" do
      expect(described_class.engine_name).to eq("auth")
    end
  end
end
