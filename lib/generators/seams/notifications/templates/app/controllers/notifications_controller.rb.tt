# frozen_string_literal: true

module Notifications
  class NotificationsController < ApplicationController
    before_action :set_notification, only: %i[show mark_as_read]

    def index
      @notifications = current_recipient
                       &.notifications
                       &.where(type: "Notifications::Strategies::InApp")
                       &.recent
                       &.limit(50) || []
    end

    def show
      @notification.mark_as_read!
    end

    def mark_as_read
      @notification.mark_as_read!
      respond_to do |format|
        format.html { redirect_to notifications_path }
        format.turbo_stream
      end
    end

    def mark_all_as_read
      current_recipient
        &.notifications
        &.where(type: "Notifications::Strategies::InApp")
        &.unread
        &.update_all(read_at: Time.current)
      redirect_to notifications_path, notice: "All caught up"
    end

    private

    def set_notification
      @notification = current_recipient&.notifications&.find(params[:id])
    end

    # Resolves the recipient whose notifications this controller
    # exposes. Post-Wave-9 the canonical recipient is
    # `Auth::Current.identity` (the signed-in human). Hosts that keep
    # a domain User on top of Auth::Identity can override
    # `current_recipient` (or expose `current_user` from their auth
    # concern) to point at that User instead — the legacy
    # `respond_to?(:current_user)` fallback below preserves Wave-8
    # behaviour for hosts that haven't migrated.
    def current_recipient
      if defined?(Auth::Current) && Auth::Current.respond_to?(:identity) && Auth::Current.identity
        return Auth::Current.identity
      end

      respond_to?(:current_user) ? current_user : nil
    end
  end
end
