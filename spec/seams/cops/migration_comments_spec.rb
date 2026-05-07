# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "seams/cops/migration_comments"

RSpec.describe RuboCop::Cop::Seams::MigrationComments, :config do
  let(:cop_config) { { "Enabled" => true } }

  it "flags a migration class with no leading comment block" do
    expect_offense(<<~RUBY)
      class CreateSubscriptions < ActiveRecord::Migration[7.1]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Migration `CreateSubscriptions` must be preceded by a comment block explaining what changes and why (data implications, downtime risk, rollback notes).
        def change
          create_table :subscriptions
        end
      end
    RUBY
  end

  it "does not flag a migration with a leading comment block" do
    expect_no_offenses(<<~RUBY)
      # What: adds the subscriptions table.
      # Why:  required by the Billing engine to record paid plans.
      # Risk: zero downtime — no existing rows.
      class CreateSubscriptions < ActiveRecord::Migration[7.1]
        def change
          create_table :subscriptions
        end
      end
    RUBY
  end

  it "does not flag a non-migration class" do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
      end
    RUBY
  end

  it "fires when only a magic comment is present (no real doc block)" do
    expect_offense(<<~RUBY)
      # frozen_string_literal: true

      class CreateSubscriptions < ActiveRecord::Migration[7.1]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Migration `CreateSubscriptions` must be preceded by a comment block explaining what changes and why (data implications, downtime risk, rollback notes).
        def change
          create_table :subscriptions
        end
      end
    RUBY
  end

  it "treats a frozen_string_literal magic comment + blank line as still leading" do
    expect_no_offenses(<<~RUBY)
      # frozen_string_literal: true

      # What: adds the subscriptions table.
      # Why:  required by the Billing engine to record paid plans.
      class CreateSubscriptions < ActiveRecord::Migration[7.1]
        def change
          create_table :subscriptions
        end
      end
    RUBY
  end
end
