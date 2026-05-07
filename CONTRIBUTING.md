# Contributing to Seams

## Setup

```sh
bundle install
bin/install-hooks   # one-shot — installs the pre-push verification hook
```

The pre-push hook runs `bin/audit --fast` before any `git push` and
blocks the push if anything fails. Bypass with `git push --no-verify`
in emergencies (then fix it on the next push).

## Verification

| Command                   | What it runs                                                                                                                   |
| ---                       | ---                                                                                                                            |
| `bin/audit --fast`        | rubocop + rspec (default suite) + bundle-audit + brakeman + Publisher orphan-subscriptions check. ~5 seconds.                  |
| `bin/audit`               | Everything above PLUS the heavy `spec/integration_full/` suite (rails new + Postgres + 5 engine boots). ~30 seconds.           |

Both commands run with `set -e` and exit non-zero on the first failure.

## Branch protection

`main` is protected; pushes (and PR merges) require these checks to be
green:

- `Lint`
- `Security`
- `RSpec (Ruby 4.0.3)`
- `Integration (rails new + boot)`

Admins can override (`enforce_admins: false`), but this is the
unhappy path — prefer fixing the failing check.

## Pull-request workflow

For trivial changes (typo, README polish, single comment):
- `bin/audit --fast` is enough.

For substantive changes (new generator template, new subscriber, contract
change, security-relevant edit):
- Run `bin/audit` (the full version, including integration_full).
- Plus a critical-review pass — if you have access to an LLM agent, run
  the [4-agent audit pattern](#audit-agents) the round-7 reviewers
  established (templates, end-to-end, event-bus contract,
  CI/deploy/Ruby compat). Without it, regressions slip in.

### Audit agents

The four critical-review aspects, used in waves 1–6 of the audit cleanup:

1. **Generator templates** — read every `.tt` the change touches; check
   ERB escaping (`<%%=` for passthrough), cross-file references resolve,
   engine.rb wiring order, concerns are well-formed, migrations match
   models, no obvious security holes.
2. **End-to-end** — actually run the change against Postgres + Ruby 4.
   Clone seams-example, run `db:migrate`, boot the server, hit the
   relevant flow.
3. **Cross-engine / event-bus** — every `Publisher.publish` payload
   matches what subscribers read. Subscribers attach via `attach_once`.
   No synchronous DB writes in the publisher's thread. Lifecycle events
   outside transactions.
4. **CI / deploy / Ruby compat** — pull `gh run list` for both repos,
   verify latest is green. Read `.github/workflows/ci.yml`. Check
   Dockerfile + deploy.yml + Procfile templates still make sense.

These can be human-driven, agent-driven, or a mix.
