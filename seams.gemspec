# frozen_string_literal: true

require_relative "lib/seams/version"

Gem::Specification.new do |spec|
  spec.name        = "seams"
  spec.version     = Seams::VERSION
  spec.authors     = ["David Silva"]
  spec.email       = ["davidslv@users.noreply.github.com"]

  spec.summary     = "CLI framework that generates modular Rails engines."
  spec.description = "Seams is a CLI framework for building Rails applications as a " \
                     "modular monolith. It generates isolated Rails engines with " \
                     "proper namespace isolation, contract tests, dummy apps, and " \
                     "boundary enforcement — without the operational cost of microservices."
  spec.homepage    = "https://github.com/Davidslv/seams"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Davidslv/seams"
  spec.metadata["changelog_uri"]   = "https://github.com/Davidslv/seams/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/Davidslv/seams/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{lib,exe}/**/*", "LICENSE", "README.md", "CHANGELOG.md"].reject { |f| File.directory?(f) }
  end

  spec.bindir       = "exe"
  spec.executables  = Dir.chdir(File.expand_path(__dir__)) do
    Dir["exe/*"].map { |f| File.basename(f) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1", "< 9.0"
  spec.add_dependency "thor", ">= 1.0"
end
