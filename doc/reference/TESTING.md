# Testing

Seams expects RSpec. Each engine has its own `spec/` directory; the
host has its own `spec/` for end-to-end and host-only tests.

## Run one engine's specs

```bash
bin/seams test billing
# or
bundle exec rspec engines/billing/spec
```

## Run everything in parallel via CI

The install generator's `.github/workflows/ci.yml` discovers every
engine and runs them as a job matrix:

```yaml
discover:
  runs-on: ubuntu-latest
  outputs:
    engines: ${{ steps.set.outputs.engines }}
  steps:
    - id: set
      run: |
        engines=$(ls -1 engines | jq -R -s -c 'split("\n")[:-1]')
        echo "engines=$engines" >> "$GITHUB_OUTPUT"

test_engine:
  needs: discover
  strategy:
    matrix:
      engine: ${{ fromJson(needs.discover.outputs.engines) }}
  steps:
    - run: bundle exec rspec engines/${{ matrix.engine }}/spec
```

Engines run in parallel. Failure in one doesn't cancel the others
(`fail-fast: false`).

## Run quality checks

```bash
bin/seams quality billing       # rubocop on a single engine
bundle exec rubocop             # all engines + host
bundle exec brakeman            # security
bundle exec bundle-audit        # vulnerable deps
```

The `seams/cops` plugin (loaded in each engine's `.rubocop.yml`)
adds the four boundary cops.

## What to test in each engine

| Layer | Test type | What to assert |
| --- | --- | --- |
| Models | Unit | Validations, scopes, public methods. Hit a real DB. |
| Jobs | Unit | The job calls the right collaborator with the right params; publishes the right events. Mock external services. |
| Controllers | Request | Happy path + auth-failure path. Don't unit-test controller methods. |
| Subscribers | Integration | Publish the upstream event and assert your subscriber enqueued the right job. |
| Adapters | Unit | Mock the provider SDK at the boundary; assert call shape matches the docs URL cited in the adapter. |
| Webhook controllers | Integration | POST a fixture payload (real signature) and assert the right event was published. Test the dedupe path. |

## Cross-engine integration tests

Live in the host's `spec/integration/`. These boot the full Rails
app and assert that publishing event X causes engine Y's subscriber
to enqueue job Z. Example:

```ruby
RSpec.describe "identity signup -> welcome email", type: :integration do
  it "enqueues a welcome email when an identity signs up" do
    expect {
      Seams::Events::Publisher.publish("identity.signed_up.auth",
                                       identity_id: 42, email: "x@y.com")
    }.to have_enqueued_job(Notifications::DeliverEmailJob)
      .with(to: "x@y.com", subject: "Welcome", body: anything)
  end
end
```

## Catching orphan subscriptions

In a test or after_initialize hook:

```ruby
orphans = Seams::Events::Publisher.orphan_subscriptions
raise "Subscribed to unknown events: #{orphans.inspect}" if orphans.any?
```

This catches typos like subscribing to `identity.signed_up.atuh`.

## Coverage

The seams gem's own suite uses SimpleCov with `minimum_coverage 90`
in CI. Hosts can adopt the same pattern in their `spec/spec_helper.rb`:

```ruby
SimpleCov.start "rails" do
  add_filter "/spec/"
  minimum_coverage 90 if ENV["CI"]
end
```

## Generator tests

Generator tests don't need a database. Use the pattern in the seams
gem itself (spec/generators/seams/*) — instantiate the generator
with a tmp `destination_root` and assert the right files were
written. Strengthen with `ruby -c` syntax checks for non-trivial
templates (the integration specs do this).
