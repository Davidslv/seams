# frozen_string_literal: true

# COVERAGE=false (set in the integration_full CI job) skips SimpleCov
# entirely. The integration suite shells out to a tmp host app, so
# very little of the gem's own code runs under coverage and the 90%
# minimum would fail spuriously.
unless ENV["COVERAGE"] == "false"
  require "simplecov"

  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/lib/generators/seams/" # generator templates have their own coverage strategy
    minimum_coverage 90 if ENV["CI"]
  end
end

require "seams"
require "rubocop"
require "rubocop/rspec/support"

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.warnings = false

  config.default_formatter = "doc" if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Reset Seams configuration between examples to keep them isolated.
  config.before do
    Seams.reset_configuration!
  end
end
