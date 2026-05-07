# frozen_string_literal: true

namespace :seams do
  ENGINE_NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/

  desc "List installed engines, the events they emit, and their dependencies"
  task list: :environment do
    require "seams/cli/list"
    Seams::CLI::List.new.call
  end

  desc "Run RSpec for a single engine: rake seams:test[billing]"
  task :test, [:engine] => :environment do |_t, args|
    name = args[:engine] or abort("Usage: rake seams:test[billing]")
    abort("Invalid engine name: #{name.inspect}") unless ENGINE_NAME_PATTERN.match?(name)
    # Array form: no shell interpolation, no injection.
    sh "bundle", "exec", "rspec", "engines/#{name}/spec"
  end

  desc "Run RuboCop for a single engine: rake seams:quality[billing]"
  task :quality, [:engine] => :environment do |_t, args|
    name = args[:engine] or abort("Usage: rake seams:quality[billing]")
    abort("Invalid engine name: #{name.inspect}") unless ENGINE_NAME_PATTERN.match?(name)
    sh "bundle", "exec", "rubocop", "engines/#{name}"
  end

  namespace :test do
    desc "Run specs only for engines changed vs $BASE (default: main)"
    task changed: :environment do
      require "seams/cli"
      base = ENV.fetch("BASE", "main")
      abort("seams:test:changed failed.") unless Seams::CLI.test_changed(base: base)
    end
  end

  namespace :quality do
    desc "Aggregate RuboCop + Brakeman + bundle-audit + SimpleCov collation across the host"
    task all: :environment do
      require "seams/cli"
      abort("seams:quality:all reported failures.") unless Seams::CLI.quality
    end
  end

  desc "Pre-push verification: rubocop, host + per-engine specs, brakeman, bundle-audit, orphan-event check"
  task audit: :environment do
    Rake::Task["environment"].invoke
    sh "bundle", "exec", "rubocop", "--parallel"
    sh "bundle", "exec", "rspec", "spec"
    Dir["engines/*"].select { |d| File.directory?(d) }.sort.each do |dir|
      next if Dir.glob("#{dir}/spec/**/*_spec.rb").empty?

      engine_name = File.basename(dir)
      sh "bundle", "exec", "rspec",
         "--default-path", "engines/#{engine_name}/spec",
         "engines/#{engine_name}/spec"
    end
    sh "bundle", "exec", "brakeman", "--no-pager", "--no-progress", "--quiet"
    sh "bundle", "exec", "bundle-audit", "check", "--update"

    orphans = Seams::Events::Publisher.orphan_subscriptions
    abort "orphan event subscriptions detected: #{orphans.inspect}" unless orphans.empty?

    puts "All audit checks passed."
  end
end
