# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

# Documentation-coverage ratchet. The floor below should only ever go
# UP — raise it as more of the public API gets YARD comments, never
# lower it. Run `bundle exec yard stats --list-undoc` to see what's
# missing. The published reference lives at rubydoc.info/gems/seams.
YARD_COVERAGE_FLOOR = 65.0

namespace :yard do
  desc "Fail if YARD documentation coverage drops below the floor"
  task :coverage do
    stats = `bundle exec yard stats 2>/dev/null`
    pct = stats[/([\d.]+)% documented/, 1]&.to_f

    abort "Could not parse `yard stats` output." if pct.nil?

    puts "YARD documentation coverage: #{pct}% (floor: #{YARD_COVERAGE_FLOOR}%)"
    if pct < YARD_COVERAGE_FLOOR
      abort "Documentation coverage #{pct}% is below the floor of " \
            "#{YARD_COVERAGE_FLOOR}%. Document new public API (or, if you " \
            "really must, lower the floor with a clear reason)."
    end
  end
end

task default: %i[spec rubocop]
