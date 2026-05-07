# frozen_string_literal: true

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
  # host_inject_gem calls are idempotent and just re-confirm.
  # sqlite3 is omitted because Rails 8's `rails new --database=sqlite3`
  # already adds it and Bundler refuses two version specifications.
  def add_gems_to_gemfile
    File.open(File.join(host_path, "Gemfile"), "a") do |f|
      f.puts
      f.puts %(gem "seams",    path: "#{seams_gem_path}")
      f.puts %(gem "bcrypt",   "~> 3.1")
      f.puts %(gem "stripe",   "~> 12.0")
      f.puts %(gem "ice_cube", ">= 0.16")
      f.puts
      f.puts "group :test do"
      f.puts %(  gem "rspec-rails", "~> 7.1")
      f.puts "end"
    end
  end

  def run_rails_new
    Bundler.with_unbundled_env do
      Dir.chdir(tmp_dir) do
        system("rails", "new", "host",
               "--skip-bundle", "--skip-git", "--skip-test",
               "--skip-system-test", "--database=sqlite3") || raise("rails new failed")
      end
    end
  end

  def bundle_install
    shell(%w[bundle install --quiet])
  end

  def generate(name)
    shell(["bin/rails", "generate", "seams:#{name}"])
  end

  it "scaffolds + boots all canonical engines from a fresh rails new" do
    run_rails_new
    add_gems_to_gemfile
    bundle_install

    %w[install core auth notifications billing teams].each { |g| generate(g) }

    %w[core auth notifications billing teams].each do |engine|
      runtime_dir = File.join(host_path, "engines", engine, "spec/runtime")
      next if Dir.glob("#{runtime_dir}/**/*_spec.rb").empty?

      shell(["bundle", "exec", "rspec", "engines/#{engine}/spec/runtime"])
    end
  end
end
