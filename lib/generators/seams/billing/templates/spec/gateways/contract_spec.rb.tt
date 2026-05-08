# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/shared_examples/a_billing_gateway"

# Stripe is the reference implementation — it MUST satisfy the
# contract. Hosts adding a new gateway add a sibling spec file and
# the same `it_behaves_like` line.
RSpec.describe Billing::Gateways::Stripe do
  it_behaves_like "a billing gateway"
end
