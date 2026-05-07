# frozen_string_literal: true

module Core
  # Per-request global state. Hosts set Current.user (typically from
  # an Auth before-action) and Current.team (from a tenant-scope
  # before-action) so deeper layers — concerns, jobs invoked from
  # the request, etc. — can read them without threading args through.
  #
  # Backed by ActiveSupport::CurrentAttributes which clears between
  # requests automatically.
  class Current < ActiveSupport::CurrentAttributes
    attribute :user, :team, :request_id

    resets { Time.zone = nil }
  end
end
