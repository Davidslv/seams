# frozen_string_literal: true

# These are full end-to-end integration tests, not class-under-test
# specs — they describe a workflow, not an object. The example length
# rule isn't useful here either; a single end-to-end run has many
# steps by design.
# rubocop:disable RSpec/DescribeClass, RSpec/ExampleLength, RSpec/MultipleExpectations

require "fileutils"
require "tmpdir"

# Heavyweight runtime integration test. Verifies that the canonical
# generators produce engines that actually boot and pass their specs
# inside a real Rails app.
#
# Excluded from the default rspec run because it takes ~5–10 minutes
# (rails new + two bundle installs + five engine spec runs). Run it
# explicitly with:
#
#   bundle exec rspec spec/integration_full/
#
# Or set RAILS_NEW_INTEGRATION=1 to make it part of `bundle exec rspec`.
#
# Skips gracefully when the `rails` CLI is not on PATH or when the
# host machine cannot bundle install (no network, no compiler, etc.).
RSpec.describe "rails new integration", type: :integration_full do
  let(:seams_gem_path) { File.expand_path("../..", __dir__) }
  let(:tmp_dir)        { Dir.mktmpdir("seams-integration-") }
  let(:host_path)      { File.join(tmp_dir, "host") }

  before do
    Bundler.with_unbundled_env do
      skip "rails CLI not on PATH" unless system("which rails > /dev/null 2>&1")
    end
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def shell(cmd, dir: host_path)
    Bundler.with_unbundled_env do
      Dir.chdir(dir) do
        ok = system(*Array(cmd))
        raise "Command failed: #{cmd.inspect}" unless ok
      end
    end
  end

  def shell_capture(cmd, dir: host_path)
    Bundler.with_unbundled_env do
      Dir.chdir(dir) do
        IO.popen(Array(cmd), err: %i[child out], &:read)
      end
    end
  end

  # Add seams + every gem the canonical generators inject. Pre-adding
  # them lets us bundle install ONCE up-front; the per-generator
  # host_inject_gem calls are idempotent and just re-confirm. pg is
  # added by `rails new --database=postgresql`.
  def add_gems_to_gemfile
    File.open(File.join(host_path, "Gemfile"), "a") do |f|
      f.puts
      f.puts %(gem "seams",    path: "#{seams_gem_path}")
      f.puts %(gem "bcrypt",   "~> 3.1")
      f.puts %(gem "faraday",  "~> 2.0")
      f.puts %(gem "ice_cube", ">= 0.16")
      f.puts
      f.puts "group :test do"
      f.puts %(  gem "rspec-rails", "~> 7.1")
      f.puts "end"
    end
  end

  def run_rails_new
    # Pin the tmp dir to the same Ruby the seams gem itself targets,
    # so rbenv shims don't fall back to the system Ruby (which won't
    # have Rails installed under our required_ruby_version).
    File.write(File.join(tmp_dir, ".ruby-version"), File.read(File.expand_path("../../.ruby-version", __dir__)))

    Bundler.with_unbundled_env do
      Dir.chdir(tmp_dir) do
        system("rails", "new", "host",
               "--skip-bundle", "--skip-git", "--skip-test",
               "--skip-system-test", "--database=postgresql") || raise("rails new failed")
      end
    end
    # Replace the default development/production database.yml with a
    # Postgres config the local test environment can actually reach.
    File.write(File.join(host_path, "config/database.yml"), <<~YML)
      default: &default
        adapter: postgresql
        encoding: unicode
        host: <%= ENV.fetch("PGHOST", "localhost") %>
        port: <%= ENV.fetch("PGPORT", 5432) %>
        username: <%= ENV.fetch("PGUSER", ENV["USER"]) %>
        password: <%= ENV.fetch("PGPASSWORD", "") %>
        pool: 5

      development:
        <<: *default
        database: seams_integration_dev

      test:
        <<: *default
        database: seams_integration_test
    YML
  end

  def create_test_database
    # db:drop is tolerant of "doesn't exist"; pair it with db:create for
    # an idempotent clean slate. Suppressed output keeps the spec log
    # focused on real failures.
    Bundler.with_unbundled_env do
      Dir.chdir(host_path) do
        %w[development test].each do |env|
          system({ "RAILS_ENV" => env }, "bin/rails", "db:drop",   out: File::NULL, err: File::NULL)
          system({ "RAILS_ENV" => env }, "bin/rails", "db:create", out: File::NULL, err: File::NULL)
        end
      end
    end
  end

  def bundle_install
    shell(%w[bundle install --quiet])
  end

  def generate(name)
    shell(["bin/rails", "generate", "seams:#{name}"])
  end

  def boot_probe(ruby_expr)
    shell_capture(["bin/rails", "runner", ruby_expr]).lines.last.to_s.strip
  end

  it "scaffolds + boots all canonical engines from a fresh rails new" do
    run_rails_new
    add_gems_to_gemfile
    bundle_install
    create_test_database

    %w[install core auth notifications billing teams].each { |g| generate(g) }

    %w[core auth notifications billing teams].each do |engine|
      runtime_dir = File.join(host_path, "engines", engine, "spec/runtime")
      next if Dir.glob("#{runtime_dir}/**/*_spec.rb").empty?

      shell(["bundle", "exec", "rspec", "engines/#{engine}/spec/runtime"])
    end

    # The host must (a) load every engine as a Railtie and (b) pick up
    # each engine's migrations through the append_migrations
    # initializer. Both regressed silently in the past.
    shell(%w[bin/rails db:migrate])

    expected = %w[
      auth_users auth_sessions
      core_audit_logs
      billing_subscriptions billing_invoices billing_plans
      teams team_memberships
      notifications notification_deliveries
    ]
    tables = shell_capture(["bin/rails", "runner", "puts ActiveRecord::Base.connection.tables.sort.join(',')"])
    actual = tables.lines.last.to_s.strip.split(",")
    missing = expected - actual
    expect(missing).to be_empty, "host db is missing engine tables: #{missing.join(", ")} (got: #{actual.inspect})"
  end

  # Phase 1.9 round-trip: the generic engine generator + the remove
  # generator must each leave the host bootable. Tests them together so
  # we don't need a second `rails new`.
  it "generates and then removes a generic engine, leaving the host bootable each time" do
    run_rails_new
    add_gems_to_gemfile
    bundle_install
    create_test_database
    generate("install")

    shell(%w[bin/rails generate seams:engine reporting])

    expect(boot_probe("puts defined?(Reporting::Engine)")).to eq("constant")
    expect(File.directory?(File.join(host_path, "engines/reporting"))).to be(true)

    # Host edits the generic generator now performs (1.6 in #2):
    expect(File.read(File.join(host_path, "config/routes.rb"))).to include("mount Reporting::Engine")
    expect(File.exist?(File.join(host_path, "config/initializers/reporting.rb"))).to be(true)

    shell(%w[bin/rails generate seams:remove reporting --force])

    expect(File.directory?(File.join(host_path, "engines/reporting"))).to be(false)
    # Host still boots — `bin/rails runner` returns 0 and `Reporting::Engine`
    # is no longer defined.
    expect(boot_probe("puts defined?(Reporting::Engine).inspect")).to eq("nil")
    expect(File.read(File.join(host_path, "config/routes.rb"))).not_to include("mount Reporting::Engine")
    expect(File.exist?(File.join(host_path, "config/initializers/reporting.rb"))).to be(false)
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/ExampleLength, RSpec/MultipleExpectations
