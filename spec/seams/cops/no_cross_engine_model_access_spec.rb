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
            Auth::Identity.find(1)
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

  context "with Rails framework constants under a sibling engine" do
    it "does not flag Billing::Engine" do
      expect_no_offenses(<<~RUBY)
        Rails.application.routes.draw { mount Billing::Engine, at: "/billing" }
      RUBY
    end

    it "does not flag Billing::VERSION" do
      expect_no_offenses(<<~RUBY)
        puts Billing::VERSION
      RUBY
    end

    it "does not flag Billing::ApplicationRecord" do
      expect_no_offenses(<<~RUBY)
        class Subscription < Billing::ApplicationRecord; end
      RUBY
    end
  end

  context "with per-request CurrentAttributes namespaces" do
    # Every engine ships its own `<Engine>::Current` namespace; they
    # are intentionally a shared per-request bus and exempt from the
    # boundary cop. See doc/CURRENT_ATTRIBUTES.md.
    it "does not flag Billing::Current" do
      expect_no_offenses(<<~RUBY)
        module Auth
          class SignIn
            def call
              Billing::Current.account
            end
          end
        end
      RUBY
    end

    it "does not flag Notifications::Current" do
      expect_no_offenses(<<~RUBY)
        Notifications::Current.recipient
      RUBY
    end

    it "does not flag a constant assignment that targets <Engine>::Current" do
      expect_no_offenses(<<~RUBY)
        module Auth
          class Bind
            def call
              Billing::Current.account = nil
            end
          end
        end
      RUBY
    end
  end

  context "with leaf names ending in framework suffixes" do
    it "does not flag Billing::WebhooksController" do
      expect_no_offenses(<<~RUBY)
        Rails.application.routes.draw do
          get "/x", to: Billing::WebhooksController
        end
      RUBY
    end

    it "does not flag Billing::ChargeJob" do
      expect_no_offenses(<<~RUBY)
        Billing::ChargeJob.perform_later
      RUBY
    end

    it "does not flag Billing::ReceiptMailer" do
      expect_no_offenses(<<~RUBY)
        Billing::ReceiptMailer.send_now
      RUBY
    end
  end

  context "when OwnEngine is missing from config" do
    let(:cop_config) do
      {
        "Enabled" => true,
        "OtherEngines" => %w[Billing]
      }
    end

    it "raises an error explaining the misconfiguration" do
      expect { cop.send(:assert_own_engine_configured!) }
        .to raise_error(RuboCop::Error, /OwnEngine/)
    end
  end
end
