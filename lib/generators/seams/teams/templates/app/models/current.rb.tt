# frozen_string_literal: true

module Teams
  # ActiveSupport::CurrentAttributes namespace for the Teams engine.
  # Set once per request by the host (typically a before_action that
  # resolves the team from the URL or session); readable from anywhere
  # downstream without explicit threading.
  #
  # `Teams::AccountScoped` reads `Teams::Current.team` to filter rows
  # to the current team. When unset, the default_scope short-circuits
  # to a no-op so background jobs that don't bind a team still see
  # their full set — wire `Teams::Current.team =` into your job's
  # #perform if you need scoping there.
  #
  # Peer to `Auth::Current` and `Accounts::Current`. No cross-engine
  # cascade — Teams::Current owns only the current team. The
  # signed-in identity lives in `Auth::Current.identity`; the active
  # tenant account lives in `Accounts::Current.account`.
  class Current < ActiveSupport::CurrentAttributes
    attribute :team

    def with_team(value, &)
      with(team: value, &)
    end

    def without_team(&)
      with(team: nil, &)
    end
  end
end
