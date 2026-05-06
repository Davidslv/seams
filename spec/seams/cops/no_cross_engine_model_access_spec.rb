# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require "seams/cops/no_cross_engine_model_access"

RSpec.describe RuboCop::Cop::Seams::NoCrossEngineModelAccess, :config do
  let(:cop_config) do
    {
      "Enabled" => true,
      "OwnEngine" => "Auth",
      "OtherEngines" => %w[Billing Notifications],
      "ExposedConcerns" => %w[Billing::Billable]
    }
  end

  it "flags direct model access into another engine's namespace" do
    expect_offense(<<~RUBY)
      module Auth
        class SignIn
          def call
            Billing::Subscription.find(1)
            ^^^^^^^^^^^^^^^^^^^^^ Engine `Auth` must not access `Billing::Subscription` directly. Use an event or a Billing-exposed concern instead.
          end
        end
      end
    RUBY
  end

  it "flags references to a model class even without a method call" do
    expect_offense(<<~RUBY)
      module Auth
        class SignIn
          MODEL = Billing::Subscription
                  ^^^^^^^^^^^^^^^^^^^^^ Engine `Auth` must not access `Billing::Subscription` directly. Use an event or a Billing-exposed concern instead.
        end
      end
    RUBY
  end

  it "does not flag access within the engine's own namespace" do
    expect_no_offenses(<<~RUBY)
      module Auth
        class SignIn
          def call
            Auth::User.find(1)
          end
        end
      end
    RUBY
  end

  it "does not flag references to non-engine constants" do
    expect_no_offenses(<<~RUBY)
      module Auth
        class SignIn
          def call
            ActiveRecord::Base.transaction { :noop }
          end
        end
      end
    RUBY
  end

  it "does not flag references to a registered concern (e.g. Billing::Billable)" do
    expect_no_offenses(<<~RUBY)
      module Auth
        class User
          include Billing::Billable
        end
      end
    RUBY
  end
end
