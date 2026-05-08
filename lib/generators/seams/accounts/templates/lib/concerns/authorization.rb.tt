# frozen_string_literal: true

require "active_support/concern"

module Accounts
  # Controller concern that enforces tenant access on every action by
  # default. Mix into the host's ApplicationController (or a base
  # account-scoped controller) and use the class-method helpers to
  # opt out per-controller.
  #
  #   class ApplicationController < ActionController::Base
  #     include Accounts::Authorization
  #   end
  #
  #   class PublicPagesController < ApplicationController
  #     disallow_account_scope          # no membership check
  #   end
  #
  #   class OnboardingController < ApplicationController
  #     require_access_without_membership
  #   end
  #
  # Default-on `before_action :ensure_account_access` checks that the
  # current Account is active AND the current Membership is active.
  # Otherwise: 403 (or redirects on HTML).
  #
  # `ensure_admin` and `ensure_staff` are opt-in helpers controllers
  # call from their own `before_action` — they don't run by default.
  # `ensure_admin` checks the per-Account role (owner/admin);
  # `ensure_staff` checks the platform-admin flag on Identity (set
  # via `Auth::Identity#staff?`). Two different powers — keep them
  # distinct.
  module Authorization
    extend ActiveSupport::Concern

    included do
      before_action :ensure_account_access if respond_to?(:before_action)
    end

    class_methods do
      # Skip the default tenant access check for this controller. Use
      # for public pages (sign-in, marketing, OAuth callbacks).
      def disallow_account_scope(**options)
        skip_before_action :ensure_account_access, **options
      end

      # Sign-up + onboarding flows: the Identity is signed in but
      # doesn't have a Membership yet. Skip the access check, but
      # redirect away if a Membership IS present (otherwise the user
      # bounces between sign-up and the dashboard).
      def require_access_without_membership(**options)
        skip_before_action :ensure_account_access, **options
        before_action :redirect_existing_membership, **options
      end
    end

    private

    def ensure_account_access
      return if account_access_allowed?

      respond_to do |format|
        format.html { redirect_to(authorization_redirect_path) }
        format.json { head :forbidden }
        format.any  { head :forbidden }
      end
    end

    def account_access_allowed?
      return false unless Accounts::Current.account&.active?

      membership = Accounts::Current.membership
      membership.present? && membership.active && !membership.system?
    end

    # Per-account admin (owner OR admin). Use as a controller
    # `before_action :ensure_admin` for in-account admin tooling
    # (member management, billing settings, etc.).
    def ensure_admin
      head :forbidden unless Accounts::Current.membership&.admin?
    end

    # Platform admin (Identity#staff?). Use as a controller
    # `before_action :ensure_staff` for support tooling that has to
    # bypass the per-account scope (e.g. impersonation, cross-account
    # search). Distinct from `ensure_admin`.
    def ensure_staff
      identity = defined?(Auth::Current) ? Auth::Current.identity : nil
      head :forbidden unless identity&.staff?
    end

    def redirect_existing_membership
      return unless Accounts::Current.membership

      respond_to do |format|
        format.html { redirect_to(Accounts.configuration.after_account_create_url) }
        format.any  { head :found }
      end
    end

    def authorization_redirect_path
      Accounts.configuration.after_account_create_url
    end
  end
end
