# frozen_string_literal: true

Teams::Engine.routes.draw do
  resources :teams, only: %i[index show new create edit update destroy] do
    resources :memberships, only: %i[index create destroy]
    resources :invitations, only: %i[index create destroy]
  end

  # Token-only accept route — the recipient clicks a link from the
  # invitation email and doesn't know the team_id. Lives at the top
  # level so the URL is short and shareable.
  get  "/invitations/accept/:token", to: "invitations#accept_form", as: :accept_invitation
  post "/invitations/accept/:token", to: "invitations#accept",      as: :confirm_invitation
end
