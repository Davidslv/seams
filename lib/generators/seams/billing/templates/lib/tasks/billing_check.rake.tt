# frozen_string_literal: true

# Smoke-check Billing configuration without hitting Stripe.
#
# Run from a host or CI before promoting a deploy:
#
#   bin/rails seams:billing:check_config
#
# Exit non-zero if anything required is missing — wire it into your
# pre-deploy gate so a missing STRIPE_SECRET_KEY fails the deploy
# instead of silently surviving boot and 500ing on the first webhook.
namespace :seams do
  namespace :billing do
    desc "Verify Billing configuration is complete (api_key + webhook_secret) — exits non-zero if not"
    task check_config: :environment do
      missing = []
      missing << "Billing.configuration.api_key (set STRIPE_SECRET_KEY or assign in initializer)" \
        if Billing.configuration.api_key.to_s.strip.empty?
      missing << "Billing.configuration.webhook_secret (set STRIPE_WEBHOOK_SECRET or assign in initializer)" \
        if Billing.configuration.webhook_secret.to_s.strip.empty?

      if missing.any?
        warn "Billing config incomplete:"
        missing.each { |m| warn "  - #{m}" }
        warn ""
        warn "Without these, Billing::Gateways::Stripe will raise at the first " \
             "outbound API call or webhook, not at boot. Set them before deploying."
        abort("Billing config check failed.")
      end

      puts "Billing config OK: api_key + webhook_secret are present."
    end
  end
end
