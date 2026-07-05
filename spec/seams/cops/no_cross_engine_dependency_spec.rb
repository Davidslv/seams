# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "seams/cops/no_cross_engine_dependency"

RSpec.describe RuboCop::Cop::Seams::NoCrossEngineDependency, :config do
  let(:cop_config) do
    {
      "Enabled" => true,
      "OwnEngine" => "auth",
      "OtherEngines" => %w[billing notifications]
    }
  end

  it "flags `require` of another engine's lib path" do
    expect_offense(<<~RUBY)
      require "billing/subscription_calculator"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Engine `auth` must not require `billing/subscription_calculator` from another engine. Communicate via events or via `Billing`'s exposed concerns.
    RUBY
  end

  it "flags `require_relative` paths that climb out of the engine into another engine's tree" do
    expect_offense(<<~RUBY)
      require_relative "../../billing/subscription_calculator"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Engine `auth` must not require `../../billing/subscription_calculator` from another engine. Communicate via events or via `Billing`'s exposed concerns.
    RUBY
  end

  it "does not flag requires within the engine's own namespace" do
    expect_no_offenses(<<~RUBY)
      require "auth/sessions"
    RUBY
  end

  it "does not flag third-party gem requires" do
    expect_no_offenses(<<~RUBY)
      require "stripe"
      require "active_support/core_ext"
    RUBY
  end

  it "does not flag require_relative paths that stay inside the engine's own tree" do
    expect_no_offenses(<<~RUBY)
      require_relative "billing_adapter/config"
      require_relative "./helpers/formatting"
    RUBY
  end

  context "when a sibling engine is named `core`" do
    # Regression: `other_engine_for` used to match ANY path segment, so
    # `require "rspec/core/rake_task"` — present in every generated
    # engine Rakefile — false-fired in every host with a `core` engine.
    # Only the FIRST segment of a plain `require` identifies the
    # library.
    let(:cop_config) do
      {
        "Enabled" => true,
        "OwnEngine" => "auth",
        "OtherEngines" => %w[billing core notifications]
      }
    end

    it "does not flag third-party requires with `core` in a deeper segment" do
      expect_no_offenses(<<~RUBY)
        require "rspec/core/rake_task"
        require "active_support/core_ext/string"
      RUBY
    end

    it "still flags a require whose first segment is the core engine" do
      expect_offense(<<~RUBY)
        require "core/something"
        ^^^^^^^^^^^^^^^^^^^^^^^^ Engine `auth` must not require `core/something` from another engine. Communicate via events or via `Core`'s exposed concerns.
      RUBY
    end

    it "still flags require_relative climbs into the core engine" do
      expect_offense(<<~RUBY)
        require_relative "../../core/lib/core/registry"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Engine `auth` must not require `../../core/lib/core/registry` from another engine. Communicate via events or via `Core`'s exposed concerns.
      RUBY
    end
  end
end
