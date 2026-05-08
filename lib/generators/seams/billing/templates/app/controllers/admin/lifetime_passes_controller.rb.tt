# frozen_string_literal: true

module Billing
  module Admin
    # Admin-side controller for issuing + revoking LifetimePasses
    # without a Stripe charge. Use for early adopters, influencer
    # giveaways, and ToS revocations.
    #
    # Authorization is the host's responsibility — Seams ships no
    # admin engine (per the explicit scope decision in issue #2 4B).
    # Mount this behind whatever admin gate the host uses (ActiveAdmin,
    # Avo, your own #require_admin! before_action).
    #
    # Suggested host-side wiring:
    #
    #   # config/routes.rb
    #   namespace :admin do
    #     resources :lifetime_passes, controller: "billing/admin/lifetime_passes",
    #                                  only: %i[index new create destroy]
    #   end
    #
    #   # app/controllers/billing/admin/lifetime_passes_controller_decorator.rb
    #   Billing::Admin::LifetimePassesController.class_eval do
    #     before_action :require_admin!
    #   end
    class LifetimePassesController < ApplicationController
      def index
        @passes = Billing::LifetimePass.order(granted_at: :desc).limit(100)
      end

      def new
        @plan_options = Billing::Plan.active.lifetime
      end

      def create
        result = Billing::Lifetime::GrantPassService.call(
          account_id:   params.require(:account_id),
          customer_ref: params.require(:customer_ref),
          plan_ref:     params.require(:plan_ref),
          granted_by:   current_admin_identity,
          notes:        params[:notes]
        )

        if result.ok?
          redirect_to billing.admin_lifetime_passes_path,
                      notice: "Lifetime pass issued."
        else
          redirect_to billing.new_admin_lifetime_pass_path,
                      alert: result.error
        end
      end

      def destroy
        pass   = Billing::LifetimePass.find(params[:id])
        result = Billing::Lifetime::RevokePassService.call(
          pass:       pass,
          revoked_by: current_admin_identity,
          notes:      params[:notes]
        )

        if result.ok?
          redirect_to billing.admin_lifetime_passes_path,
                      notice: "Lifetime pass revoked."
        else
          redirect_to billing.admin_lifetime_passes_path,
                      alert: result.error
        end
      end

      private

      # Override in the host. The default reads `current_user` if the
      # host's admin gate uses the same `current_user` helper — for a
      # post-Wave-9 host that means the Auth::Identity row currently
      # signed in. Pre-Wave-9 hosts (host User present) override this
      # to return the User; the GrantPassService coerces both shapes.
      def current_admin_identity
        return nil unless respond_to?(:current_user)

        current_user
      end
    end
  end
end
