# frozen_string_literal: true

Billing::Engine.routes.draw do
  resources :plans, only: %i[index]

  # Self-service subscription management — Phase 3 (4/4). Backed by
  # the Phase 3 (2/4) service objects; member actions map onto
  # CancelService / ReactivateService / ChangePlanService.
  resources :subscriptions, only: %i[index show] do
    member do
      delete :cancel
      post   :reactivate
      post   :change_plan
    end
  end

  # Read-only billing history. Stripe hosts the PDF; the show view
  # links to hosted_invoice_url if your host wires it up.
  resources :invoices, only: %i[index show]

  post "/checkout",          to: "checkout#create",   as: :checkout
  get  "/checkout/success",  to: "checkout#success",  as: :checkout_success
  # Lifetime Deal purchase — Stripe Checkout `mode: "payment"`.
  # Namespaced under /checkout/ alongside the recurring-checkout flow
  # so the surface stays grouped. See issue #2 section 3A.LTD.
  post "/checkout/lifetime", to: "checkout#lifetime", as: :lifetime_checkout

  post "/portal", to: "portal#create", as: :portal

  # Admin-side LTD management. Mount behind your admin gate; see
  # Billing::Admin::LifetimePassesController for the contract.
  namespace :admin do
    resources :lifetime_passes, only: %i[index new create destroy]
  end

  post "/webhooks/stripe", to: "webhooks#stripe", as: :stripe_webhook
end
