# frozen_string_literal: true

# Aggregates SimpleCov result files from every engine spec run into
# one combined report at coverage/.
#
# Each engine writes its own coverage/.resultset.json when its specs
# run. CI runs the engines in parallel (each on its own dummy app), so
# we end up with N partial reports. SimpleCov.collate merges them.
#
# Usage:
#
#   bin/rails seams:test         # writes per-engine coverage/.resultset.json
#   ruby script/collate_coverage.rb
#   open coverage/index.html
#
# Idempotent — re-running overwrites the merged report.
require "simplecov"

# Glob every engine's resultset, plus the host's, into one collation.
result_files = Dir.glob("engines/*/coverage/.resultset.json")
result_files << "coverage/.resultset.json" if File.exist?("coverage/.resultset.json")

if result_files.empty?
  warn "No coverage/.resultset.json files found. Run specs first."
  exit 1
end

puts "Collating #{result_files.size} resultset(s)..."
SimpleCov.collate(result_files) do
  formatter SimpleCov::Formatter::HTMLFormatter
end

puts "Merged report: coverage/index.html"
