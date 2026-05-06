# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "seams/cops/known_queue_names"

RSpec.describe RuboCop::Cop::Seams::KnownQueueNames, :config do
  let(:cop_config) do
    {
      "Enabled" => true,
      "KnownQueues" => %w[default billing notifications]
    }
  end

  it "flags `queue_as` with an unknown queue name" do
    expect_offense(<<~RUBY)
      class ChargeJob < ApplicationJob
        queue_as :payments
        ^^^^^^^^^^^^^^^^^^ Queue `payments` is not registered. Add it to .rubocop.yml under Seams/KnownQueueNames#KnownQueues, or pick one of: default, billing, notifications.
      end
    RUBY
  end

  it "flags `queue_as` with an unknown string queue name" do
    expect_offense(<<~RUBY)
      class ChargeJob < ApplicationJob
        queue_as "payments"
        ^^^^^^^^^^^^^^^^^^^ Queue `payments` is not registered. Add it to .rubocop.yml under Seams/KnownQueueNames#KnownQueues, or pick one of: default, billing, notifications.
      end
    RUBY
  end

  it "does not flag a registered queue name" do
    expect_no_offenses(<<~RUBY)
      class ChargeJob < ApplicationJob
        queue_as :billing
      end
    RUBY
  end

  it "does not flag `queue_as` with a block (dynamic queue)" do
    expect_no_offenses(<<~RUBY)
      class ChargeJob < ApplicationJob
        queue_as { :billing }
      end
    RUBY
  end
end
