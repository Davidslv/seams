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
end
