# frozen_string_literal: true

Auth::Engine.routes.draw do
  resource :session,        only: %i[new create destroy], controller: :sessions
  resource :registration,   only: %i[new create],         controller: :registrations
  resource :password_reset, only: %i[new create edit update]

  # OAuth — one URL pair per configured provider. The :provider param
  # is matched against Auth.configuration.oauth_providers at request
  # time; unknown providers raise Auth::OAuthProviderUnknown which
  # the controller handles.
  scope "/oauth/:provider" do
    get "start",    to: "oauth/callbacks#start",    as: :oauth_start
    get "callback", to: "oauth/callbacks#callback", as: :oauth_callback
  end
end
