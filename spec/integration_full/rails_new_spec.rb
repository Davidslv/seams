# frozen_string_literal: true

# These are full end-to-end integration tests, not class-under-test
# specs — they describe a workflow, not an object. The example length
# rule isn't useful here either; a single end-to-end run has many
# steps by design.
# rubocop:disable RSpec/DescribeClass, RSpec/ExampleLength, RSpec/MultipleExpectations

require "fileutils"
require "tmpdir"

# Heavyweight runtime integration test. Verifies that the canonical
# generators produce engines that actually boot and pass their specs
# inside a real Rails app.
#
# Excluded from the default rspec run because it takes ~5–10 minutes
# (rails new + two bundle installs + six engine spec runs). Run it
# explicitly with:
#
#   bundle exec rspec spec/integration_full/
#
# Or set RAILS_NEW_INTEGRATION=1 to make it part of `bundle exec rspec`.
#
# Skips gracefully when the `rails` CLI is not on PATH or when the
# host machine cannot bundle install (no network, no compiler, etc.).
RSpec.describe "rails new integration", type: :integration_full do
  let(:seams_gem_path) { File.expand_path("../..", __dir__) }
  let(:tmp_dir)        { Dir.mktmpdir("seams-integration-") }
  let(:host_path)      { File.join(tmp_dir, "host") }

  before do
    Bundler.with_unbundled_env do
      skip "rails CLI not on PATH" unless system("which rails > /dev/null 2>&1")
    end
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def shell(cmd, dir: host_path)
    Bundler.with_unbundled_env do
      Dir.chdir(dir) do
        ok = system(*Array(cmd))
        raise "Command failed: #{cmd.inspect}" unless ok
      end
    end
  end

  def shell_capture(cmd, dir: host_path)
    Bundler.with_unbundled_env do
      Dir.chdir(dir) do
        IO.popen(Array(cmd), err: %i[child out], &:read)
      end
    end
  end

  # Add seams + every gem the canonical generators inject. Pre-adding
  # them lets us bundle install ONCE up-front; the per-generator
  # host_inject_gem calls are idempotent and just re-confirm. pg is
  # added by `rails new --database=postgresql`.
  # Pre-add seams + every gem the canonical generators and seams:install
  # inject, so the single up-front bundle install picks them all up; the
  # generators' host_inject_gem calls are then idempotent no-ops. brakeman
  # ships with `rails new`, so it isn't repeated here.
  def add_gems_to_gemfile
    File.write(File.join(host_path, "Gemfile"), <<~RUBY, mode: "a")

      gem "seams",    path: "#{seams_gem_path}"
      gem "bcrypt",   "~> 3.1"
      gem "faraday",  "~> 2.0"
      gem "stripe",   "~> 13.0"
      gem "ice_cube", ">= 0.16"
      gem "tailwindcss-rails", "~> 4.0"

      group :development, :test do
        gem "strong_migrations"
        gem "rubocop"
        gem "bundler-audit"
        gem "herb"
        gem "lefthook"
      end

      group :test do
        gem "rspec-rails",       "~> 7.1"
        gem "factory_bot_rails", "~> 6.4"
        gem "webmock",           "~> 3.23"
      end
    RUBY
  end

  def run_rails_new
    # Pin the tmp dir to the same Ruby the seams gem itself targets,
    # so rbenv shims don't fall back to the system Ruby (which won't
    # have Rails installed under our required_ruby_version).
    File.write(File.join(tmp_dir, ".ruby-version"), File.read(File.expand_path("../../.ruby-version", __dir__)))

    Bundler.with_unbundled_env do
      Dir.chdir(tmp_dir) do
        system("rails", "new", "host",
               "--skip-bundle", "--skip-git", "--skip-test",
               "--skip-system-test", "--database=postgresql") || raise("rails new failed")
      end
    end
    # Replace the default development/production database.yml with a
    # Postgres config the local test environment can actually reach.
    File.write(File.join(host_path, "config/database.yml"), <<~YML)
      default: &default
        adapter: postgresql
        encoding: unicode
        host: <%= ENV.fetch("PGHOST", "localhost") %>
        port: <%= ENV.fetch("PGPORT", 5432) %>
        username: <%= ENV.fetch("PGUSER", ENV["USER"]) %>
        password: <%= ENV.fetch("PGPASSWORD", "") %>
        pool: 5

      development:
        <<: *default
        database: seams_integration_dev

      test:
        <<: *default
        database: seams_integration_test
    YML
  end

  def create_test_database
    # db:drop is tolerant of "doesn't exist"; pair it with db:create for
    # an idempotent clean slate. Suppressed output keeps the spec log
    # focused on real failures.
    Bundler.with_unbundled_env do
      Dir.chdir(host_path) do
        %w[development test].each do |env|
          system({ "RAILS_ENV" => env }, "bin/rails", "db:drop",   out: File::NULL, err: File::NULL)
          system({ "RAILS_ENV" => env }, "bin/rails", "db:create", out: File::NULL, err: File::NULL)
        end
      end
    end
  end

  # Auth's encrypts :email + encrypts :provider_uid (Wave 11) require
  # ActiveRecord::Encryption keys configured at host boot. Real
  # production hosts run `bin/rails db:encryption:init` once and store
  # the keys in Rails credentials; the integration host doesn't have
  # credentials, so we ship a tiny initializer with throwaway test
  # keys. The dummy DB is wiped per run anyway.
  #
  # Wave 9: encryption is on Auth::Identity (#email). Accounts::Account
  # has no encrypted columns of its own, so this initializer continues
  # to be required for the auth engine alone.
  def configure_host_encryption_keys
    initializer = File.join(host_path, "config/initializers/active_record_encryption.rb")
    File.write(initializer, <<~RB)
      # frozen_string_literal: true
      # Throwaway keys for integration testing. Real hosts use
      # `bin/rails db:encryption:init` + Rails credentials.
      Rails.application.configure do
        config.active_record.encryption.primary_key            = "integration_primary_key_throwaway"
        config.active_record.encryption.deterministic_key      = "integration_deterministic_key_throwaway"
        config.active_record.encryption.key_derivation_salt    = "integration_key_derivation_salt_throwaway"
        config.active_record.encryption.support_unencrypted_data = true
      end
    RB
  end

  # Wave 9: there is no host User. The notifications engine's
  # Notifiable concern is OPTIONAL — the canonical demo wires it onto
  # Auth::Identity in the host's notifications initializer so
  # `identity.notify(...)` becomes available. Reproduce that wiring
  # here so the smoke probe can exercise the helper.
  def wire_notifiable_into_identity
    initializer = File.join(host_path, "config/initializers/notifications_wiring.rb")
    File.write(initializer, <<~RB)
      # frozen_string_literal: true
      # Wave 9 canonical wiring: the human is Auth::Identity, and we
      # want `identity.notify(...)` available. Pattern A from the
      # notifications engine's initializer.
      Rails.application.config.to_prepare do
        Auth::Identity.include(Notifications::Notifiable)
      end
    RB
  end

  def bundle_install
    shell(%w[bundle install --quiet])
  end

  def generate(name)
    shell(["bin/rails", "generate", "seams:#{name}"])
  end

  # Single-line probes (the original use). Returns only the LAST
  # line of stdout — convenient when the script does one `puts X`.
  def boot_probe(ruby_expr)
    shell_capture(["bin/rails", "runner", ruby_expr]).lines.last.to_s.strip
  end

  # Multi-line probes. Returns the FULL stdout+stderr so the caller
  # can grep for any number of marker lines. Used by the every-
  # function smoke probe at the bottom of the scaffolds-and-boots
  # example.
  def boot_probe_full(ruby_expr)
    shell_capture(["bin/rails", "runner", ruby_expr])
  end

  it "scaffolds + boots all canonical engines from a fresh rails new" do
    run_rails_new
    add_gems_to_gemfile
    bundle_install
    create_test_database

    # Wave 9 dropped the canonical demo's host User. Auth::Identity is
    # the human; Accounts::Account is the tenant. No `bin/rails generate
    # model User ...` step here — the generators don't touch a host
    # User any more, and the Notifiable concern is wired onto
    # Auth::Identity below via an initializer (Pattern A from the
    # notifications engine README).
    %w[install core auth accounts notifications billing teams].each { |g| generate(g) }

    # Wave 11 PII encryption requires keys at host boot. Real hosts
    # run `bin/rails db:encryption:init` once and store the keys in
    # Rails credentials; we ship throwaway integration keys instead.
    configure_host_encryption_keys
    # Wave 9: opt-in Notifiable on Auth::Identity (canonical pattern).
    wire_notifiable_into_identity

    # Run every engine's FULL spec suite, not just spec/runtime. The
    # broader scope catches Zeitwerk inflector regressions, missing
    # ApplicationMailer in the dummy app, and bad require_relative
    # paths in 3-level-deep specs — three bug classes that previously
    # slipped past CI because we only exercised spec/runtime.
    %w[core auth accounts notifications billing teams].each do |engine|
      spec_dir = File.join(host_path, "engines", engine, "spec")
      next if Dir.glob("#{spec_dir}/**/*_spec.rb").empty?

      shell(["bundle", "exec", "rspec",
             "--default-path", "engines/#{engine}/spec",
             "engines/#{engine}/spec"])
    end

    # The host must (a) load every engine as a Railtie and (b) pick up
    # each engine's migrations through the append_migrations
    # initializer. Both regressed silently in the past. No host User
    # migration to run any more — the generators ship the engine
    # tables and nothing else.
    shell(%w[bin/rails db:migrate])

    expected = %w[
      auth_identities auth_sessions auth_api_tokens auth_oauth_providers
      accounts accounts_memberships
      core_audit_logs
      billing_subscriptions billing_invoices billing_plans billing_lifetime_passes billing_webhook_events
      teams team_memberships team_invitations
      notifications notification_deliveries notification_preferences
    ]
    tables = shell_capture(["bin/rails", "runner", "puts ActiveRecord::Base.connection.tables.sort.join(',')"])
    actual = tables.lines.last.to_s.strip.split(",")
    missing = expected - actual
    expect(missing).to be_empty, "host db is missing engine tables: #{missing.join(", ")} (got: #{actual.inspect})"

    # Phase 2C — verify Auth + Notifications wiring end-to-end.
    # Publish the canonical identity.signed_up.auth event from a
    # runner process and assert the Notifications::AuthSubscriber
    # actually creates a Notification row. Exercises Publisher.attach_class
    # + the CreateNotificationJob inline path the engine boots with.
    # The host User model is gone post-Wave-9 — the welcome notification
    # is owned by the Auth::Identity itself.
    notification_count = boot_probe(<<~RUBY)
      ActiveJob::Base.queue_adapter = :inline
      identity = Auth::Identity.create!(
        email: "phase2c-\#{Process.pid}@example.com",
        password: "verysecret"
      )

      Seams::Events::Publisher.publish(
        "identity.signed_up.auth",
        identity_id: identity.id,
        email:       identity.email
      )

      puts Notifications::Notification.where(owner: identity).count
    RUBY

    expect(notification_count).to eq("1").or(eq("2")),
                                  "expected at least one Notifications::Notification to be created " \
                                  "by the AuthSubscriber, got #{notification_count.inspect}"

    # Phase 3B — verify billing + accounts + notifications wire up
    # end-to-end. Publish a canonical invoice.paid.billing event with
    # `account_id:` keyed on a real Accounts::Account; the
    # BillingSubscriber should enqueue a CreateNotificationJob with
    # owner_class: "Accounts::Account" and owner_id: that account.
    # Inline-queue runs it sync so we can assert on the Notification row
    # directly.
    billing_count = boot_probe(<<~RUBY)
      ActiveJob::Base.queue_adapter = :inline

      identity = Auth::Identity.create!(
        email: "phase3b-\#{Process.pid}@example.com",
        password: "verysecret"
      )
      OwnerStruct = Struct.new(:identity, :name) unless defined?(OwnerStruct)
      account = Accounts::Account.create_with_owner(
        account: { name: "Phase3B Co \#{Process.pid}" },
        owner:   OwnerStruct.new(identity, "Phase3B Owner")
      )

      Seams::Events::Publisher.publish(
        "invoice.paid.billing",
        gateway:      "stripe",
        livemode:     false,
        account_id:   account.id,
        customer_ref: "cus_phase3b_\#{Process.pid}",
        ref:          "in_phase3b",
        object_id:    "in_phase3b",
        object:       { id: "in_phase3b", customer: "cus_phase3b_\#{Process.pid}", status: "paid" }
      )

      puts Notifications::Notification.where(owner: account, template: "billing/invoice_paid").count
    RUBY

    expect(billing_count).to eq("1"),
                             "expected exactly one Notification(template: billing/invoice_paid) " \
                             "to be created by the BillingSubscriber against the Account, got #{billing_count.inspect}"

    # Phase 4A — verify the Teams engine's full lifecycle in the host:
    # Team.create + Membership.create (keyed on identity_id) + canonical
    # team.created.teams event publish. Catches Railtie / autoload /
    # migration regressions in the Teams engine that would not show up
    # in a generator spec.
    teams_state = boot_probe(<<~RUBY)
      ActiveJob::Base.queue_adapter = :inline

      received = []
      Seams::Events::Publisher.subscribe("team.created.teams") { |payload| received << payload }

      identity = Auth::Identity.create!(
        email: "phase4a-\#{Process.pid}@example.com",
        password: "verysecret"
      )
      team = Teams::Team.create!(name: "Phase 4A Co.", slug: "phase4a-\#{Process.pid}")
      Teams::Membership.create!(team: team, identity_id: identity.id, role: "owner")

      Seams::Events::Publisher.publish(
        "team.created.teams", team_id: team.id, owner_id: identity.id
      )

      puts "team_persisted=\#{Teams::Team.exists?(team.id)};" \\
           "membership_count=\#{Teams::Membership.where(team: team).count};" \\
           "events_received=\#{received.size}"
    RUBY

    expect(teams_state).to include("team_persisted=true")
    expect(teams_state).to include("membership_count=1")
    expect(teams_state).to include("events_received=1")

    # Wave 9 — Accounts smoke probe. Exercises the new accounts engine
    # end-to-end: create_with_owner produces a system + owner Membership
    # in one transaction, and the engine publishes the canonical
    # account.created.accounts + membership.created.accounts events.
    accounts_state = boot_probe(<<~RUBY)
      ActiveJob::Base.queue_adapter = :inline

      received_account     = []
      received_membership  = []
      Seams::Events::Publisher.subscribe("account.created.accounts")    { |p| received_account    << p }
      Seams::Events::Publisher.subscribe("membership.created.accounts") { |p| received_membership << p }

      identity = Auth::Identity.create!(
        email: "wave9-acc-\#{Process.pid}@example.com",
        password: "verysecret"
      )
      OwnerStruct = Struct.new(:identity, :name) unless defined?(OwnerStruct)
      account = Accounts::Account.create_with_owner(
        account: { name: "Wave 9 Co \#{Process.pid}" },
        owner:   OwnerStruct.new(identity, "Wave 9 Owner")
      )

      system_count = account.memberships.where(role: "system").count
      owner_count  = account.memberships.where(role: "owner").count

      puts "account_persisted=\#{Accounts::Account.exists?(account.id)};" \\
           "system_memberships=\#{system_count};" \\
           "owner_memberships=\#{owner_count};" \\
           "account_events=\#{received_account.size};" \\
           "membership_events=\#{received_membership.size}"
    RUBY

    expect(accounts_state).to include("account_persisted=true")
    expect(accounts_state).to include("system_memberships=1")
    expect(accounts_state).to include("owner_memberships=1")
    expect(accounts_state).to include("account_events=1")
    # 2 memberships = system + owner created inside create_with_owner.
    expect(accounts_state).to include("membership_events=2")

    # Wave 6 — comprehensive every-function smoke probe. Exercises
    # every public seams API surface in one boot so a regression in
    # ANY single feature surfaces here on every CI push, not in
    # production. The probe's stdout is parsed line-by-line; each
    # OK= line is an independent assertion. A regression on any
    # single feature flips its OK to FAIL and the example fails with
    # a useful diff.
    #
    # Coverage:
    # - Auth:          register, authenticate, generate API token,
    #                  Bearer-resolve API token, revoke API token,
    #                  request password reset, complete password
    #                  reset, encrypts email round-trip.
    # - Accounts:      create_with_owner round-trip, system actor.
    # - Notifications: create + due scope, AuthSubscriber wiring
    #                  (already covered by phase 2c above; included
    #                  here for the regression net), TypeRegistry
    #                  register + lookup, NotificationPreference
    #                  default-on, bell unread count.
    # - Billing:       Plan + Subscription + Invoice CRUD (account_id
    #                  keyed), WebhookEvent uniqueness, EventRouter
    #                  handler lookup for all 13 mapped Stripe event
    #                  types, LifetimePass grant + revoke (account
    #                  scoped), Plan inventory lock raises SoldOut.
    # - Teams:         Team / Membership (identity_id) / Invitation,
    #                  membership role inclusion.
    # - Events:        every registered event resolves via the
    #                  EventRegistry.
    smoke = boot_probe_full(<<~'RUBY')
      ActiveJob::Base.queue_adapter = :test
      lines = []
      check  = ->(name, &block) {
        ok    = false
        error = nil
        begin
          ok = !!block.call
        rescue => e
          error = "#{e.class}: #{e.message.lines.first.to_s.strip}"
        end
        suffix = ok ? "true" : "false (#{error || 'returned falsy'})"
        lines << "#{name}=#{suffix}"
      }

      # ---- AUTH ------------------------------------------------------
      auth_email = "smoke-#{SecureRandom.hex(4)}@example.com"
      check.call("auth.register") { Auth::RegisterIdentity.call(email: auth_email, password: "verysecret").ok? }

      auth_identity = Auth::Identity.find_by(email: auth_email)
      check.call("auth.encrypts_email") { auth_identity && auth_identity.email == auth_email }

      check.call("auth.authenticate") { Auth::AuthenticateIdentity.call(email: auth_email, password: "verysecret").ok? }

      token = nil
      check.call("auth.api_token_issued") { (token = Auth::GenerateApiToken.call(identity: auth_identity, name: "smoke")).ok? }

      check.call("auth.api_token_resolves") { token && Auth::ApiToken.find_by_plaintext(token.plaintext)&.id == token.api_token.id }

      check.call("auth.api_token_revoked") { token && Auth::RevokeApiToken.call(api_token: token.api_token).ok? }

      check.call("auth.reset_request") { Auth::ResetPassword.request(email: auth_email).ok? }

      # Wave 9: Auth::Identity uses Rails 8's has_secure_password reset_token
      # (a signed_id, NOT a column). Generate a fresh token off the
      # identity instance and complete the reset with it.
      check.call("auth.reset_complete") {
        auth_identity.reload
        token = auth_identity.password_reset_token
        result = Auth::ResetPassword.complete(token: token, new_password: "newpassword99")
        raise "reset_complete failed: token=#{token.inspect} error=#{result.error.inspect}" unless result.ok?
        true
      }

      # ---- ACCOUNTS --------------------------------------------------
      OwnerStruct = Struct.new(:identity, :name) unless defined?(OwnerStruct)
      smoke_account = nil
      smoke_owner_identity = nil
      check.call("accounts.create_with_owner") {
        smoke_owner_identity = Auth::Identity.create!(
          email: "acc-owner-#{Process.pid}-#{SecureRandom.hex(2)}@example.com",
          password: "verysecret"
        )
        smoke_account = Accounts::Account.create_with_owner(
          account: { name: "Smoke Co. #{Process.pid}" },
          owner:   OwnerStruct.new(smoke_owner_identity, "Smoke Owner")
        )
        smoke_account.persisted?
      }

      check.call("accounts.system_actor_present") {
        smoke_account && smoke_account.memberships.where(role: "system").count == 1
      }
      check.call("accounts.owner_membership_present") {
        smoke_account && smoke_account.memberships.where(role: "owner", identity_id: smoke_owner_identity.id).count == 1
      }

      # ---- NOTIFICATIONS --------------------------------------------
      check.call("notif.type_registry") {
        Notifications::TypeRegistry.register("smoke.test", template: "default", channels: %i[in_app email])
        Notifications::TypeRegistry.fetch("smoke.test").name == "smoke.test"
      }

      smoke_notif_identity = nil
      check.call("notif.created") {
        smoke_notif_identity = Auth::Identity.create!(
          email: "notif-smoke-#{Process.pid}-#{SecureRandom.hex(2)}@example.com",
          password: "verysecret"
        )
        smoke_notif_identity.notify(strategy: :in_app, template: "default").persisted?
      }
      check.call("notif.unread") { smoke_notif_identity && smoke_notif_identity.unread_in_app_notifications.count >= 1 }
      check.call("notif.preference_default_on") {
        Notifications::NotificationPreference.enabled?(identity_id: smoke_notif_identity.id, channel: "email") == true
      }

      # ---- BILLING --------------------------------------------------
      plan = nil
      check.call("billing.plan_created") {
        plan = Billing::Plan.create!(
          gateway_ref: "price_smoke_#{Process.pid}", name: "Smoke",
          amount_cents: 1299, currency: "GBP", interval: "month"
        )
        plan.persisted?
      }

      sub = nil
      check.call("billing.subscription_created") {
        sub = Billing::Subscription.create!(
          gateway_ref: "sub_smoke_#{Process.pid}",
          account_id:  smoke_account.id,
          customer_ref: "cus_smoke_#{Process.pid}",
          plan_ref: plan.gateway_ref, status: "active",
          current_period_end: 30.days.from_now
        )
        sub.persisted?
      }

      check.call("billing.invoice_paid") {
        Billing::Invoice.create!(
          gateway_ref: "in_smoke_#{Process.pid}",
          account_id:  smoke_account.id,
          customer_ref: sub.customer_ref, subscription_ref: sub.gateway_ref,
          amount_cents: 1299, currency: "GBP", status: "paid", paid_at: Time.current
        ).paid?
      }

      check.call("billing.webhook_event_unique") {
        Billing::WebhookEvent.create!(gateway: "stripe", gateway_event_id: "evt_smoke_#{Process.pid}",
                                      event_type: "smoke.test.billing", livemode: false)
        begin
          Billing::WebhookEvent.create!(gateway: "stripe", gateway_event_id: "evt_smoke_#{Process.pid}",
                                        event_type: "smoke.test.billing", livemode: false)
          false
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
          true
        end
      }

      check.call("billing.router_resolves_all") {
        events = %w[
          customer.subscription.created customer.subscription.updated
          customer.subscription.deleted customer.subscription.trial_will_end
          invoice.created invoice.paid invoice.payment_failed
          invoice.finalized invoice.voided
          payment_intent.succeeded payment_intent.payment_failed
          charge.refunded checkout.session.completed
        ]
        events.map { |t| Billing::Webhooks::EventRouter.handler_for(t) }.compact.size == 13
      }

      ltd_plan = nil
      ltd_grant_result = nil
      check.call("billing.ltd_grant") {
        ltd_plan = Billing::Plan.create!(
          gateway_ref: "price_ltd_smoke_#{Process.pid}", name: "Smoke LTD",
          amount_cents: 9900, currency: "GBP", interval: "lifetime",
          max_lifetime_units: 1
        )
        ltd_grant_result = Billing::Lifetime::GrantPassService.call(
          account_id:   smoke_account.id,
          customer_ref: "cus_ltd_smoke_#{Process.pid}",
          plan_ref:     ltd_plan.gateway_ref,
          granted_by:   smoke_owner_identity
        )
        ltd_grant_result.ok?
      }

      check.call("billing.ltd_lock_raises") {
        begin
          ltd_plan.reload.enforce_lifetime_inventory_or_raise!
          false
        rescue Billing::Plan::SoldOut
          true
        end
      }

      check.call("billing.ltd_revoke") {
        Billing::Lifetime::RevokePassService.call(
          pass:       ltd_grant_result.pass,
          revoked_by: smoke_owner_identity
        ).ok?
      }

      # ---- TEAMS ----------------------------------------------------
      team = nil
      check.call("teams.team_created") {
        team = Teams::Team.create!(name: "Smoke Co.", slug: "smoke-#{Process.pid}")
        Teams::Membership.create!(team: team, identity_id: smoke_owner_identity.id, role: "owner")
        team.persisted?
      }
      check.call("teams.invitation_created") {
        Teams::Invitation.create!(team: team, email: "invite-#{Process.pid}@example.com", role: "member").persisted?
      }
      check.call("teams.membership_role_owner") { team && team.memberships.where(role: "owner").exists? }

      # ---- EVENT REGISTRY -------------------------------------------
      check.call("events.auth_signed_up")        { Seams::EventRegistry.registered?("identity.signed_up.auth") }
      check.call("events.accounts_created")      { Seams::EventRegistry.registered?("account.created.accounts") }
      check.call("events.accounts_membership_created") {
        Seams::EventRegistry.registered?("membership.created.accounts")
      }
      check.call("events.billing_invoice_paid")  { Seams::EventRegistry.registered?("invoice.paid.billing") }
      check.call("events.teams_team_created")    { Seams::EventRegistry.registered?("team.created.teams") }
      check.call("events.notif_queued")          { Seams::EventRegistry.registered?("notification.queued.notifications") }

      lines.each { |l| puts "SMOKE_#{l}" }
    RUBY

    # Every assertion is a single line. Fail fast on the first miss
    # and report which feature regressed.
    expected_oks = %w[
      auth.register=true
      auth.encrypts_email=true
      auth.authenticate=true
      auth.api_token_issued=true
      auth.api_token_resolves=true
      auth.api_token_revoked=true
      auth.reset_request=true
      auth.reset_complete=true
      accounts.create_with_owner=true
      accounts.system_actor_present=true
      accounts.owner_membership_present=true
      notif.type_registry=true
      notif.created=true
      notif.unread=true
      notif.preference_default_on=true
      billing.plan_created=true
      billing.subscription_created=true
      billing.invoice_paid=true
      billing.webhook_event_unique=true
      billing.router_resolves_all=true
      billing.ltd_grant=true
      billing.ltd_lock_raises=true
      billing.ltd_revoke=true
      teams.team_created=true
      teams.invitation_created=true
      teams.membership_role_owner=true
      events.auth_signed_up=true
      events.accounts_created=true
      events.accounts_membership_created=true
      events.billing_invoice_paid=true
      events.teams_team_created=true
      events.notif_queued=true
    ]

    missing = expected_oks.reject { |line| smoke.include?("SMOKE_#{line}") }
    expect(missing).to be_empty,
                       "every-function smoke probe regressed:\n  - missing: #{missing.join("\n  - ")}\n\n" \
                       "Full output:\n#{smoke}"

    # ------------------------------------------------------------------
    # HTTP smoke — prove the host SERVES correctly, not just that the
    # engines load. Every probe above is a Ruby-level `bin/rails runner`
    # call; nothing drove a real request through the middleware + filter
    # chain. That blind spot is how #40 (auth front-door lockout) and #41
    # (--shell unstyled) both reached a human. These guard that class.
    # ------------------------------------------------------------------

    # #40: every signed-out auth entry point must render (200), not
    # 302-loop back to the sign-in page. The engine base controller gates
    # every action with authenticate_identity!; the signed-out actions
    # opt out, so these pages are reachable while logged out.
    auth_http = boot_probe_full(<<~'RUBY')
      session = ActionDispatch::Integration::Session.new(Rails.application)
      # runner boots in development, where ActionDispatch::HostAuthorization
      # blocks the default integration host (www.example.com) with a 403.
      # localhost is permitted in development.
      session.host = "localhost"
      %w[/auth/session/new /auth/registration/new /auth/password_reset/new].each do |path|
        session.get(path)
        puts "AUTH_HTTP #{path} => #{session.response.status}"
      end
    RUBY

    %w[/auth/session/new /auth/registration/new /auth/password_reset/new].each do |path|
      expect(auth_http).to include("AUTH_HTTP #{path} => 200"),
                           "signed-out #{path} must return 200, not a redirect loop.\n#{auth_http}"
    end

    # #41: generate the opt-in app shell and assert the served root links
    # the COMPILED "tailwind" build (the @theme tokens + ui_* layer), not
    # the empty "application" manifest. Propshaft needs the asset to
    # exist, so stub the build output (we don't run the tailwind binary).
    shell(["bin/rails", "generate", "seams:design", "--shell"])
    FileUtils.mkdir_p(File.join(host_path, "app/assets/builds"))
    File.write(File.join(host_path, "app/assets/builds/tailwind.css"), "/* integration build stub */\n")

    shell_http = boot_probe_full(<<~'RUBY')
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host = "localhost"
      session.get("/")
      puts "SHELL_HTTP / => #{session.response.status}"
      puts "SHELL_LINKS_TAILWIND=#{session.response.body.include?('tailwind')}"
    RUBY

    expect(shell_http).to include("SHELL_HTTP / => 200"),
                          "the --shell dashboard root must return 200.\n#{shell_http}"
    expect(shell_http).to include("SHELL_LINKS_TAILWIND=true"),
                          "the --shell layout must link the compiled tailwind build.\n#{shell_http}"
  end

  # Phase 1.9 round-trip: the generic engine generator + the remove
  # generator must each leave the host bootable. Tests them together so
  # we don't need a second `rails new`.
  it "generates and then removes a generic engine, leaving the host bootable each time" do
    run_rails_new
    add_gems_to_gemfile
    bundle_install
    create_test_database
    generate("install")

    shell(%w[bin/rails generate seams:engine reporting])

    expect(boot_probe("puts defined?(Reporting::Engine)")).to eq("constant")
    expect(File.directory?(File.join(host_path, "engines/reporting"))).to be(true)

    # Host edits the generic generator now performs (1.6 in #2):
    expect(File.read(File.join(host_path, "config/routes.rb"))).to include("mount Reporting::Engine")
    expect(File.exist?(File.join(host_path, "config/initializers/reporting.rb"))).to be(true)

    shell(%w[bin/rails generate seams:remove reporting --force])

    expect(File.directory?(File.join(host_path, "engines/reporting"))).to be(false)
    # Host still boots — `bin/rails runner` returns 0 and `Reporting::Engine`
    # is no longer defined.
    expect(boot_probe("puts defined?(Reporting::Engine).inspect")).to eq("nil")
    expect(File.read(File.join(host_path, "config/routes.rb"))).not_to include("mount Reporting::Engine")
    expect(File.exist?(File.join(host_path, "config/initializers/reporting.rb"))).to be(false)
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/ExampleLength, RSpec/MultipleExpectations
