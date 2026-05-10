# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "stringio"
require "seams/cli/resolve"

# CLI examples test end-to-end behaviours: each example exercises one
# CLI invocation and asserts on (a) the boolean return, (b) the file
# the CLI wrote, and (c) the human-readable output. Splitting those
# into single-expectation examples buys nothing — the file write and
# the stdout line are facets of the same observable behaviour. The
# resolve_spec.rb file exempts these two cops at file scope rather
# than per-example.
# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
RSpec.describe Seams::CLI::Resolve do
  let(:tmpdir)        { Dir.mktmpdir("seams-resolve-spec-") }
  let(:engines_root)  { File.join(tmpdir, "engines") }
  let(:output)        { StringIO.new }
  let(:error)         { StringIO.new }

  after { FileUtils.rm_rf(tmpdir) }

  def write_engine_file(engine, relative, contents)
    full = File.join(engines_root, engine, relative)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, contents)
    full
  end

  def run(mode:, argument: nil)
    described_class.new(
      mode: mode,
      argument: argument,
      engines_root: engines_root,
      output: output,
      error: error
    ).call
  end

  describe ":eject mode" do
    it "prepends the eject header to a host-owned file" do
      target = write_engine_file("auth", "app/mailers/auth/passwords_mailer.rb", <<~RB)
        # frozen_string_literal: true
        module Auth
          class PasswordsMailer; end
        end
      RB

      result = run(mode: :eject, argument: "auth/app/mailers/auth/passwords_mailer.rb")

      expect(result).to be(true)
      contents = File.read(target)
      expect(contents).to start_with("# seams:ejected from auth.app/mailers/auth/passwords_mailer.rb\n")
      expect(contents).to include("Re-running `bin/rails generate seams:auth` will NOT overwrite")
      expect(contents).to include("To return to the gem version: delete this file")
      # Original body is preserved beneath the header.
      expect(contents).to include("class PasswordsMailer")
      expect(output.string).to match(/^ejected: .*passwords_mailer\.rb \(lines: \d+; from: auth\./)
    end

    it "is idempotent on a re-run (does not double-prepend)" do
      target = write_engine_file("auth", "app/mailers/auth/passwords_mailer.rb", "# frozen_string_literal: true\n")

      run(mode: :eject, argument: "auth/app/mailers/auth/passwords_mailer.rb")
      first_contents = File.read(target)

      output2 = StringIO.new
      described_class.new(
        mode: :eject,
        argument: "auth/app/mailers/auth/passwords_mailer.rb",
        engines_root: engines_root,
        output: output2,
        error: error
      ).call

      expect(File.read(target)).to eq(first_contents)
      expect(output2.string).to match(/^already ejected:/)
    end

    it "errors when the argument has no slash" do
      result = run(mode: :eject, argument: "no-slash-here")

      expect(result).to be(false)
      expect(error.string).to include("expected '<engine>/<file>'")
    end

    it "errors when the engine directory is missing" do
      result = run(mode: :eject, argument: "missingengine/app/foo.rb")

      expect(result).to be(false)
      expect(error.string).to include('engine "missingengine" not found')
      expect(error.string).to include("bin/rails generate seams:missingengine")
    end

    it "errors when the file is missing inside an existing engine" do
      FileUtils.mkdir_p(File.join(engines_root, "auth"))

      result = run(mode: :eject, argument: "auth/app/mailers/missing.rb")

      expect(result).to be(false)
      expect(error.string).to include("file not found")
    end

    it "refuses to eject framework-managed files" do
      write_engine_file("auth", "lib/auth/engine.rb", "# engine boot")
      write_engine_file("auth", "lib/auth/version.rb", 'VERSION = "0.1"')
      write_engine_file("auth", "db/migrate/20260101_x.rb", "class X; end")
      write_engine_file("auth", "Gemfile", "source 'rubygems'")
      write_engine_file("auth", "auth.gemspec", "# spec")
      write_engine_file("auth", "Rakefile", "# rake")

      [
        "auth/lib/auth/engine.rb",
        "auth/lib/auth/version.rb",
        "auth/db/migrate/20260101_x.rb",
        "auth/Gemfile",
        "auth/auth.gemspec",
        "auth/Rakefile"
      ].each do |arg|
        result = run(mode: :eject, argument: arg)
        expect(result).to be(false), "expected eject of #{arg} to be refused"
      end

      expect(error.string).to include("framework-managed")
    end

    it "errors with no argument" do
      result = run(mode: :eject, argument: nil)

      expect(result).to be(false)
      expect(error.string).to include("missing argument")
      expect(error.string).to include("--eject <engine>/<file>")
    end
  end

  describe ":list_markers mode" do
    it "prints every insertion-point marker in the engine, with file + line + description" do
      write_engine_file("auth", "lib/auth/engine.rb", <<~RB)
        # frozen_string_literal: true
        module Auth
          class Engine < ::Rails::Engine
            initializer "auth.register_events" do
              Seams::EventRegistry.register("identity.signed_up.auth", emitted_by: "Auth")
              # Follow-up generators that emit new auth events register them here.
              # seams:insertion-point auth.engine.events
            end
          end
        end
      RB
      write_engine_file("auth", "config/routes.rb", <<~RB)
        # frozen_string_literal: true
        Auth::Engine.routes.draw do
          # Routes added by follow-up generators land here.
          # seams:insertion-point auth.routes.before_session
          resource :session
        end
      RB

      result = run(mode: :list_markers, argument: "auth")

      expect(result).to be(true)
      out = output.string
      expect(out).to include("auth.engine.events")
      expect(out).to include("auth.routes.before_session")
      expect(out).to include("lib/auth/engine.rb")
      expect(out).to include("config/routes.rb")
      expect(out).to match(%r{auth\.engine\.events\s+.*lib/auth/engine\.rb:\d+})
      # The line ABOVE the marker becomes the description.
      expect(out).to include("Follow-up generators that emit new auth events register them here.")
    end

    it "handles a marker on the very first line without wrapping to the last line for the description" do
      # Regression: a 1-indexed marker_line_number of 1 turned into a
      # zero index, then `lines[-1]` accidentally pulled the LAST line
      # of the file as the description. Now the helper guards against
      # marker_line_number <= 1 explicitly.
      write_engine_file("auth", "lib/auth/engine.rb", <<~RB)
        # seams:insertion-point auth.engine.events
        # bogus trailing comment that must NOT become the description
      RB

      result = run(mode: :list_markers, argument: "auth")

      expect(result).to be(true)
      expect(output.string).to include("(no description)")
      expect(output.string).not_to include("bogus trailing comment")
    end

    it "explains when an engine has no markers (might be pre-Wave-10)" do
      write_engine_file("legacy", "lib/legacy/engine.rb", "module Legacy; end\n")

      result = run(mode: :list_markers, argument: "legacy")

      expect(result).to be(true)
      expect(output.string).to include("no insertion-point markers found")
      expect(output.string).to include("Re-run `bin/rails generate seams:legacy`")
    end

    it "errors when the engine doesn't exist" do
      result = run(mode: :list_markers, argument: "doesnotexist")

      expect(result).to be(false)
      expect(error.string).to include('engine "doesnotexist" not found')
    end

    it "errors with no argument" do
      result = run(mode: :list_markers, argument: nil)

      expect(result).to be(false)
      expect(error.string).to include("--list-markers <engine>")
    end
  end

  describe ":list_ejected mode" do
    it "lists every ejected file across every engine" do
      write_engine_file("auth", "app/mailers/auth/passwords_mailer.rb", <<~RB)
        # seams:ejected from auth.app/mailers/auth/passwords_mailer.rb
        # Re-running `bin/rails generate seams:auth` will NOT overwrite this file.
        # frozen_string_literal: true
        module Auth
          class PasswordsMailer; end
        end
      RB
      write_engine_file("billing", "app/services/billing/customers/find_or_create_service.rb", <<~RB)
        # seams:ejected from billing.app/services/billing/customers/find_or_create_service.rb
        # frozen_string_literal: true
        module Billing
          module Customers
            class FindOrCreateService; end
          end
        end
      RB
      # Non-ejected file — should NOT appear in the listing.
      write_engine_file("auth", "app/models/auth/identity.rb", <<~RB)
        # frozen_string_literal: true
        module Auth
          class Identity; end
        end
      RB

      result = run(mode: :list_ejected)

      expect(result).to be(true)
      out = output.string
      expect(out).to include("seams: 2 ejected file(s)")
      expect(out).to include("auth/app/mailers/auth/passwords_mailer.rb")
      expect(out).to include("from: auth.app/mailers/auth/passwords_mailer.rb")
      expect(out).to include("billing/app/services/billing/customers/find_or_create_service.rb")
      expect(out).not_to include("identity.rb")
    end

    it "reports zero ejected files cleanly" do
      FileUtils.mkdir_p(File.join(engines_root, "auth"))
      write_engine_file("auth", "app/models/auth/identity.rb", "module Auth; class Identity; end; end\n")

      result = run(mode: :list_ejected)

      expect(result).to be(true)
      expect(output.string).to include("no ejected files in")
    end

    it "reports cleanly when engines/ doesn't exist" do
      # No engines/ dir at all.
      result = run(mode: :list_ejected)

      expect(result).to be(true)
      expect(output.string).to include("no engines directory")
    end
  end

  describe "unknown mode" do
    it "fails fast with a clear error" do
      result = run(mode: :nope)

      expect(result).to be(false)
      expect(error.string).to include("unknown mode: :nope")
    end
  end
end
# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
