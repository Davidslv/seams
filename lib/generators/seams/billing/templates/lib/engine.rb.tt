# frozen_string_literal: true

module Billing
  class Engine < ::Rails::Engine
    isolate_namespace Billing

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "billing.register_events" do
      # Subscription lifecycle.
      Seams::EventRegistry.register("subscription.created.billing",         emitted_by: "Billing")
      Seams::EventRegistry.register("subscription.updated.billing",         emitted_by: "Billing")
      Seams::EventRegistry.register("subscription.canceled.billing",        emitted_by: "Billing")
      Seams::EventRegistry.register("subscription.trial_will_end.billing",  emitted_by: "Billing")
      # Invoice lifecycle.
      Seams::EventRegistry.register("invoice.created.billing",              emitted_by: "Billing")
      Seams::EventRegistry.register("invoice.paid.billing",                 emitted_by: "Billing")
      Seams::EventRegistry.register("invoice.failed.billing",               emitted_by: "Billing")
      Seams::EventRegistry.register("invoice.finalized.billing",            emitted_by: "Billing")
      Seams::EventRegistry.register("invoice.voided.billing",               emitted_by: "Billing")
      # One-off payment + refund signals.
      Seams::EventRegistry.register("payment.succeeded.billing",            emitted_by: "Billing")
      Seams::EventRegistry.register("payment.failed.billing",               emitted_by: "Billing")
      Seams::EventRegistry.register("charge.refunded.billing",              emitted_by: "Billing")
      Seams::EventRegistry.register("checkout.session_completed.billing",   emitted_by: "Billing")
      # Lifetime Deal events — see issue #2 section 3A.LTD.
      Seams::EventRegistry.register("lifetime.granted.billing",             emitted_by: "Billing")
      Seams::EventRegistry.register("lifetime.purchased.billing",           emitted_by: "Billing")
      Seams::EventRegistry.register("lifetime.revoked.billing",             emitted_by: "Billing")
    end

    initializer "billing.append_migrations" do |app|
      unless app.root == root
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
