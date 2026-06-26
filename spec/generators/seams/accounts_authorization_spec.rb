# frozen_string_literal: true

require "active_support"
require "active_support/concern"
require "seams/permission_registry"

# Behavioural coverage for the Accounts::Authorization#authorize_permission!
# helper the accounts generator ships. The concern template is pure Ruby
# (no ERB tags), so we load it into the gem test process after stubbing
# the per-request namespaces it reads — Auth::Current (the staff bypass)
# and Accounts::Current (the current membership/role) — and exercise the
# real source the generator emits, rather than a copy.

module Auth
  # Minimal stand-in for the auth engine's per-request namespace.
  module Current
    class << self
      attr_accessor :identity
    end
  end
end

module Accounts
  # Minimal stand-in for the accounts engine's per-request namespace.
  module Current
    class << self
      attr_accessor :account, :membership
    end
  end

  def self.configuration
    @configuration ||= Struct.new(:after_account_create_url).new("/")
  end
end

AUTHORIZATION_CONCERN_TEMPLATE = File.expand_path(
  "../../../lib/generators/seams/accounts/templates/lib/concerns/authorization.rb.tt",
  __dir__
)

# rubocop:disable Security/Eval
eval(File.read(AUTHORIZATION_CONCERN_TEMPLATE), binding, AUTHORIZATION_CONCERN_TEMPLATE)
# rubocop:enable Security/Eval

RSpec.describe Accounts::Authorization do
  let(:controller_class) do
    Class.new do
      include Accounts::Authorization

      attr_reader :denied_with

      # Stand-in for ActionController#head so we can assert the denial.
      def head(status)
        @denied_with = status
      end
    end
  end

  let(:controller) { controller_class.new }

  before do
    Seams::PermissionRegistry.reset!
    Seams::PermissionRegistry.register("invoice.read.billing",   owned_by: "Billing")
    Seams::PermissionRegistry.register("invoice.manage.billing", owned_by: "Billing")
    Auth::Current.identity       = nil
    Accounts::Current.membership = nil
    Seams.configure { |c| c.permission_grants = { "member" => ["invoice.read.billing"] } }
  end

  after { Seams.reset_configuration! }

  it "allows (does not deny) when the membership role holds the ability" do
    Accounts::Current.membership = double(role: "member")

    controller.send(:authorize_permission!, "invoice.read.billing")

    expect(controller.denied_with).to be_nil
  end

  it "denies with :forbidden when the role lacks the ability" do
    Accounts::Current.membership = double(role: "member")

    controller.send(:authorize_permission!, "invoice.manage.billing")

    expect(controller.denied_with).to eq(:forbidden)
  end

  it "denies with :forbidden when there is no current membership" do
    Accounts::Current.membership = nil

    controller.send(:authorize_permission!, "invoice.read.billing")

    expect(controller.denied_with).to eq(:forbidden)
  end

  it "lets platform staff bypass even when the role lacks the ability" do
    Accounts::Current.membership = double(role: "member")
    Auth::Current.identity       = double(staff?: true)

    controller.send(:authorize_permission!, "invoice.manage.billing")

    expect(controller.denied_with).to be_nil
  end

  it "resolves the role from the current membership, applying the role hierarchy" do
    # admin inherits member's read grant through ROLE_HIERARCHY.
    Accounts::Current.membership = double(role: "admin")

    controller.send(:authorize_permission!, "invoice.read.billing")

    expect(controller.denied_with).to be_nil
  end
end
