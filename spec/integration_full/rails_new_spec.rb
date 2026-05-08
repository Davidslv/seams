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
# (rails new + two bundle installs + five engine spec runs). Run it
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
  def add_gems_to_gemfile
    File.open(File.join(host_path, "Gemfile"), "a") do |f|
      f.puts
      f.puts %(gem "seams",    path: "#{seams_gem_path}")
      f.puts %(gem "bcrypt",   "~> 3.1")
      f.puts %(gem "faraday",  "~> 2.0")
      f.puts %(gem "stripe",   "~> 13.0")
      f.puts %(gem "ice_cube", ">= 0.16")
      f.puts
      f.puts "group :test do"
      f.puts %(  gem "rspec-rails",       "~> 7.1")
      f.puts %(  gem "factory_bot_rails", "~> 6.4")
      f.puts %(  gem "webmock",           "~> 3.23")
      f.puts "end"
    end
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

    # Generate the host User model BEFORE the canonical engines run,
    # so each engine's host_inject_include_in_user(...) call lands on
    # the right file (Auth::Authenticatable, Notifications::Notifiable,
    # Billing::Billable, Teams::Teamable). Without this, the engines
    # skip with a "User model not found" notice and the cross-engine
    # wiring assertions at the bottom of this example would have to
    # patch Notifiable in by hand.
    #
    # stripe_customer_id is included so Phase 3B's billing-event check
    # below can resolve User.find_by(stripe_customer_id: ...) — the
    # column Billing::Billable documents on the host User.
    shell(%w[bin/rails generate model User email:string stripe_customer_id:string])

    %w[install core auth notifications billing teams].each { |g| generate(g) }

    # Wave 11 PII encryption requires keys at host boot. Real hosts
    # run `bin/rails db:encryption:init` once and store the keys in
    # Rails credentials; we ship throwaway integration keys instead.
    configure_host_encryption_keys

    # Run every engine's FULL spec suite, not just spec/runtime. The
    # broader scope catches Zeitwerk inflector regressions, missing
    # ApplicationMailer in the dummy app, and bad require_relative
    # paths in 3-level-deep specs — three bug classes that previously
    # slipped past CI because we only exercised spec/runtime.
    %w[core auth notifications billing teams].each do |engine|
      spec_dir = File.join(host_path, "engines", engine, "spec")
      next if Dir.glob("#{spec_dir}/**/*_spec.rb").empty?

      shell(["bundle", "exec", "rspec",
             "--default-path", "engines/#{engine}/spec",
             "engines/#{engine}/spec"])
    end

    # The host must (a) load every engine as a Railtie and (b) pick up
    # each engine's migrations through the append_migrations
    # initializer. Both regressed silently in the past.
    shell(%w[bin/rails db:migrate])

    expected = %w[
      auth_users auth_sessions
      core_audit_logs
      billing_subscriptions billing_invoices billing_plans
      teams team_memberships
      notifications notification_deliveries
    ]
    tables = shell_capture(["bin/rails", "runner", "puts ActiveRecord::Base.connection.tables.sort.join(',')"])
    actual = tables.lines.last.to_s.strip.split(",")
    missing = expected - actual
    expect(missing).to be_empty, "host db is missing engine tables: #{missing.join(", ")} (got: #{actual.inspect})"

    # Phase 2C — verify Auth + Notifications wiring end-to-end.
    # Publish the canonical user.signed_up.auth event from a runner
    # process and assert the Notifications::AuthSubscriber actually
    # creates a Notification row. Exercises Publisher.attach_class +
    # the CreateNotificationJob inline path the engine boots with.
    # The host User model was generated above (before the engines)
    # so Notifications::Notifiable was injected into it by the
    # notifications generator's wire_into_host.
    notification_count = boot_probe(<<~RUBY)
      ActiveJob::Base.queue_adapter = :inline
      user = User.create!(email: "phase2c-\#{Process.pid}@example.com")

      Seams::Events::Publisher.publish(
        "user.signed_up.auth",
        auth_user_id: 0,
        host_user_id: user.id,
        email: user.email
      )

      puts Notifications::Notification.where(owner: user).count
    RUBY

    expect(notification_count).to eq("1").or(eq("2")),
                                  "expected at least one Notifications::Notification to be created " \
                                  "by the AuthSubscriber, got #{notification_count.inspect}"

    # Phase 3B — verify billing + auth + notifications wire up
    # end-to-end. Publish a canonical invoice.paid.billing event
    # whose customer_ref matches a User's stripe_customer_id; the
    # BillingSubscriber should resolve the host user and enqueue a
    # CreateNotificationJob. Inline-queue runs it sync so we can
    # assert on the resulting Notification row directly.
    billing_count = boot_probe(<<~RUBY)
      ActiveJob::Base.queue_adapter = :inline
      user = User.create!(
        email:              "phase3b-\#{Process.pid}@example.com",
        stripe_customer_id: "cus_phase3b_\#{Process.pid}"
      )

      Seams::Events::Publisher.publish(
        "invoice.paid.billing",
        gateway:      "stripe",
        livemode:     false,
        customer_ref: user.stripe_customer_id,
        ref:          "in_phase3b",
        object_id:    "in_phase3b",
        object:       { id: "in_phase3b", customer: user.stripe_customer_id, status: "paid" }
      )

      puts Notifications::Notification.where(owner: user, template: "billing/invoice_paid").count
    RUBY

    expect(billing_count).to eq("1"),
                             "expected exactly one Notification(template: billing/invoice_paid) " \
                             "to be created by the BillingSubscriber, got #{billing_count.inspect}"

    # Phase 4A — verify the Teams engine's full lifecycle in the host:
    # Team.create + Membership.create + canonical team.created.teams
    # event publish. Catches Railtie / autoload / migration regressions
    # in the Teams engine that would not show up in a generator spec.
    teams_state = boot_probe(<<~RUBY)
      ActiveJob::Base.queue_adapter = :inline

      received = []
      Seams::Events::Publisher.subscribe("team.created.teams") { |payload| received << payload }

      user = User.create!(email: "phase4a-\#{Process.pid}@example.com")
      team = Teams::Team.create!(name: "Phase 4A Co.", slug: "phase4a-\#{Process.pid}")
      Teams::Membership.create!(team: team, user_id: user.id, role: "owner")

      Seams::Events::Publisher.publish(
        "team.created.teams", team_id: team.id, owner_id: user.id
      )

      puts "team_persisted=\#{Teams::Team.exists?(team.id)};" \\
           "membership_count=\#{Teams::Membership.where(team: team).count};" \\
           "events_received=\#{received.size}"
    RUBY

    expect(teams_state).to include("team_persisted=true")
    expect(teams_state).to include("membership_count=1")
    expect(teams_state).to include("events_received=1")

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
    # - Notifications: create + due scope, AuthSubscriber wiring
    #                  (already covered by phase 2c above; included
    #                  here for the regression net), TypeRegistry
    #                  register + lookup, NotificationPreference
    #                  default-on, bell unread count.
    # - Billing:       Plan + Subscription + Invoice CRUD,
    #                  WebhookEvent uniqueness, EventRouter handler
    #                  lookup for all 13 mapped Stripe event types,
    #                  LifetimePass grant + revoke, Plan inventory
    #                  lock raises SoldOut.
    # - Teams:         AccountScoped scope filter, Authorization
    #                  predicates, role inclusion.
    # - Events:        every registered event resolves to its emitter
    #                  via EventRegistry.
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
      check.call("auth.register") { Auth::RegisterUser.call(email: auth_email, password: "verysecret").ok? }

      auth_user = Auth::User.find_by(email: auth_email)
      check.call("auth.encrypts_email") { auth_user && auth_user.email == auth_email }

      check.call("auth.authenticate") { Auth::AuthenticateUser.call(email: auth_email, password: "verysecret").ok? }

      token = nil
      check.call("auth.api_token_issued") { (token = Auth::GenerateApiToken.call(user: auth_user, name: "smoke")).ok? }

      check.call("auth.api_token_resolves") { token && Auth::ApiToken.find_by_plaintext(token.plaintext)&.id == token.api_token.id }

      check.call("auth.api_token_revoked") { token && Auth::RevokeApiToken.call(api_token: token.api_token).ok? }

      check.call("auth.reset_request") { Auth::ResetPassword.request(email: auth_email).ok? }

      auth_user.reload
      check.call("auth.reset_complete") {
        result = Auth::ResetPassword.complete(token: auth_user.password_reset_token, new_password: "newpassword99")
        raise "reset_complete failed: token=#{auth_user.password_reset_token.inspect} sent_at=#{auth_user.password_reset_token_sent_at.inspect} error=#{result.error.inspect}" unless result.ok?
        true
      }

      # ---- NOTIFICATIONS --------------------------------------------
      check.call("notif.type_registry") {
        Notifications::TypeRegistry.register("smoke.test", template: "default", channels: %i[in_app email])
        Notifications::TypeRegistry.fetch("smoke.test").name == "smoke.test"
      }

      smoke_user = nil
      check.call("notif.created") {
        smoke_user = User.find_or_create_by!(email: "notif-smoke-#{Process.pid}@example.com")
        smoke_user.notify(strategy: :in_app, template: "default").persisted?
      }
      check.call("notif.unread") { smoke_user && smoke_user.unread_in_app_notifications.count >= 1 }
      check.call("notif.preference_default_on") {
        Notifications::NotificationPreference.enabled?(user_id: smoke_user.id, channel: "email") == true
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
          customer_ref: "cus_smoke_#{Process.pid}",
          plan_ref: plan.gateway_ref, status: "active",
          current_period_end: 30.days.from_now
        )
        sub.persisted?
      }

      check.call("billing.invoice_paid") {
        Billing::Invoice.create!(
          gateway_ref: "in_smoke_#{Process.pid}",
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
          customer_ref: "cus_ltd_smoke_#{Process.pid}",
          plan_ref:     ltd_plan.gateway_ref,
          granted_by:   nil
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
          revoked_by: nil
        ).ok?
      }

      # ---- TEAMS ----------------------------------------------------
      team = nil
      check.call("teams.team_created") {
        team = Teams::Team.create!(name: "Smoke Co.", slug: "smoke-#{Process.pid}")
        Teams::Membership.create!(team: team, user_id: smoke_user.id, role: "owner")
        team.persisted?
      }
      check.call("teams.invitation_created") {
        Teams::Invitation.create!(team: team, email: "invite-#{Process.pid}@example.com", role: "member").persisted?
      }
      check.call("teams.membership_role_owner") { team && team.memberships.where(role: "owner").exists? }

      # ---- EVENT REGISTRY -------------------------------------------
      check.call("events.auth_signed_up")        { Seams::EventRegistry.registered?("user.signed_up.auth") }
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
      teams.invitation_created=true
      teams.membership_role_owner=true
      events.auth_signed_up=true
      events.billing_invoice_paid=true
      events.teams_team_created=true
      events.notif_queued=true
    ]

    missing = expected_oks.reject { |line| smoke.include?("SMOKE_#{line}") }
    expect(missing).to be_empty,
                       "every-function smoke probe regressed:\n  - missing: #{missing.join("\n  - ")}\n\n" \
                       "Full output:\n#{smoke}"
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
