# Heavyweight runtime integration tests

The specs in this directory are excluded from the default
`bundle exec rspec` run because they take **5–10 minutes** per run
(real `rails new`, two `bundle install`s, five engine spec suites
booted in real Rails apps).

They are the only specs in the repository that prove the generated
engines actually **boot** in a real Rails application. Everything
else in `spec/` is template-correctness (file existence, string
presence, `ruby -c` syntax parse) — those catch missing methods,
wrong constants, missing requires, but they don't catch
runtime issues like ice_cube serialisation breaking, STI dispatch
failing under Zeitwerk, or migrations that don't apply cleanly.

## Running

```bash
bundle exec rspec spec/integration_full/
```

## What `rails_new_spec.rb` does

1. Shells out to `rails new tmp/host --skip-bundle --skip-git
   --skip-test --skip-system-test --database=postgresql`. Pins the
   tmp dir to seams' `.ruby-version` so rbenv shims pick the right
   Ruby. Overwrites the default `config/database.yml` with one that
   reads `PGHOST` / `PGUSER` / `PGPASSWORD`.
2. Appends `gem "seams", path: "<this gem>"` to the host's Gemfile.
3. `bundle install` (vanilla Rails + seams).
4. Creates the `seams_integration_dev` and `seams_integration_test`
   Postgres databases.
5. Runs every canonical generator in order:
   `seams:install`, `seams:core`, `seams:auth`, `seams:notifications`,
   `seams:billing`, `seams:teams`.
6. For each engine, runs `bundle exec rspec engines/<name>/spec/runtime`
   inside the host. The runtime specs are the boot specs the
   canonical generators ship — they assert the engine constant
   loads, `Seams::EventRegistry` contains the canonical events, the
   dummy schema's tables exist, and (for notifications) ice_cube
   round-trips work.

## Skip conditions

- The spec **skips** with a friendly message if `rails` is not on
  PATH (CI runner without a Rails install). Set up Ruby + Rails on
  the runner to enable it.
- The spec **fails** loudly if any of `rails new`, `bundle install`,
  the generator chain, or the engine spec runs returns non-zero.

## CI integration

The default `.github/workflows/ci.yml` (the one shipped to host
apps via the install generator) runs the **fast** suite — template
correctness + RuboCop + brakeman + bundle-audit. It does NOT run
this directory.

Add a separate, slower workflow to your CI if you want this to run
on every PR. For the seams gem itself, run it locally before
shipping a release.
