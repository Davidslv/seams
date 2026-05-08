# frozen_string_literal: true

module Notifications
  class PreferencesController < ApplicationController
    def show
      @preferences = Notifications::NotificationPreference.where(identity_id: current_identity_id)
    end

    def update
      # Whitelist the keys we accept. The form posts
      # `preferences[<channel>:<type>] = "1" | "0"`. Allowed channels
      # are the canonical CHANNELS list; type is either "any" (→ nil)
      # or a NotificationPreference::TYPE-style identifier ([a-z0-9_]).
      preference_params.each do |key, enabled|
        channel, type = key.split(":", 2)
        next unless Notifications::NotificationPreference::CHANNELS.include?(channel)
        next unless type.nil? || type == "any" || type.match?(/\A[a-z0-9_]+\z/)

        type = nil if type == "any"
        pref = Notifications::NotificationPreference.find_or_initialize_by(
          identity_id:       current_identity_id,
          channel:           channel,
          notification_type: type
        )
        pref.update!(enabled: enabled.to_s == "1")
      end
      redirect_to preferences_path, notice: "Preferences saved"
    end

    private

    # `params[:preferences].to_h` raises ActionController::UnfilteredParameters
    # in Rails default config. Use permit! after filtering to the
    # `:preferences` key — the per-key channel/type validation above
    # is the real safety net.
    def preference_params
      raw = params.require(:preferences)
      raw.respond_to?(:permit!) ? raw.permit!.to_h : raw.to_h
    end

    # Resolves the signed-in identity's id from `Auth::Current.identity`
    # (the Auth engine's per-request namespace). Gated on
    # `defined?(Auth::Current)` so the controller is safe in hosts
    # that don't ship the auth engine. Override in your host if you
    # wire authentication differently.
    def current_identity_id
      if defined?(Auth::Current) && Auth::Current.respond_to?(:identity) && Auth::Current.identity
        return Auth::Current.identity.id
      end

      nil
    end
  end
end
