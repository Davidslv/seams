# frozen_string_literal: true

module Teams
  class Engine < ::Rails::Engine
    isolate_namespace Teams

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "teams.register_events" do
      Seams::EventRegistry.register("team.created.teams",          emitted_by: "Teams")
      Seams::EventRegistry.register("team.member_joined.teams",    emitted_by: "Teams")
      Seams::EventRegistry.register("team.member_left.teams",      emitted_by: "Teams")
      Seams::EventRegistry.register("invitation.sent.teams",       emitted_by: "Teams")
      Seams::EventRegistry.register("invitation.accepted.teams",   emitted_by: "Teams")
    end

    initializer "teams.append_migrations" do |app|
      unless app.root == root
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    config.after_initialize do
      # Boot-time dependency assertion. Teams::Membership.identity_id
      # references auth_identities; without auth the team membership
      # rows are dangling. We enforce at boot so the operator gets a
      # clear "install seams:auth" error rather than a NULL identity_id
      # surprise on first query.
      unless defined?(::Auth::Identity)
        raise <<~MSG
          [seams teams] missing required cross-engine dependency:
              Auth::Identity (run: bin/rails generate seams:auth)

          The teams engine joins identity_id to auth_identities; it
          cannot run without auth. Generate the auth engine, or
          remove teams with `bin/rails generate seams:remove teams --force`.
        MSG
      end

      Teams::InvitationSubscriber.attach!
    end
  end
end
