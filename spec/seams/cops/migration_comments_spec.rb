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

  # Regression: the cop previously did line-based comment scanning and
  # would treat ANY non-magic comment between line 1 and the migration
  # class as documentation. That made undocumented migrations ship green
  # whenever a sibling class above them happened to carry comments.
  it "flags a migration even when a sibling class above carries comments" do
    expect_offense(<<~RUBY)
      class Helper
        # This is a helper utility — long comment block that belongs to Helper.
        # ...nothing about the migration that follows.
      end

      class CreateSubscriptions < ActiveRecord::Migration[7.1]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Migration `CreateSubscriptions` must be preceded by a comment block explaining what changes and why (data implications, downtime risk, rollback notes).
        def change
          create_table :billing_subscriptions
        end
      end
    RUBY
  end

  it "flags a migration even when a sibling method's trailing comment precedes it" do
    expect_offense(<<~RUBY)
      def helper_method
        :ok
        # internal note about helper_method
      end

      class CreateSubscriptions < ActiveRecord::Migration[7.1]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Migration `CreateSubscriptions` must be preceded by a comment block explaining what changes and why (data implications, downtime risk, rollback notes).
        def change
          create_table :billing_subscriptions
        end
      end
    RUBY
  end

  it "does not flag a migration whose doc block sits above a sibling class" do
    expect_no_offenses(<<~RUBY)
      class Helper
        # Helper's own comment.
      end

      # What: adds the subscriptions table.
      # Why:  required by the Billing engine to record paid plans.
      class CreateSubscriptions < ActiveRecord::Migration[7.1]
        def change
          create_table :subscriptions
        end
      end
    RUBY
  end

  it "does not flag a migration when the file opens with a typed: sigil" do
    expect_no_offenses(<<~RUBY)
      # typed: true
      # frozen_string_literal: true

      # What: adds the subscriptions table.
      # Why:  required by Billing engine.
      class CreateSubscriptions < ActiveRecord::Migration[7.1]
        def change
          create_table :subscriptions
        end
      end
    RUBY
  end

  it "still fires when only a typed: sigil precedes the migration" do
    expect_offense(<<~RUBY)
      # typed: true
      # frozen_string_literal: true

      class CreateSubscriptions < ActiveRecord::Migration[7.1]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Migration `CreateSubscriptions` must be preceded by a comment block explaining what changes and why (data implications, downtime risk, rollback notes).
        def change
          create_table :subscriptions
        end
      end
    RUBY
  end
end
