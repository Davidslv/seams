# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository. This
follows the `AGENTS.md` convention. Keep it short and current.

## What this project is

A CLI framework that generates modular Rails engines. See
[README.md](README.md) and [doc/explanation/ARCHITECTURE.md](doc/explanation/ARCHITECTURE.md). The
generated code is the product: most changes are changes to generator templates
(`lib/generators/seams/**/templates/*.tt`), not to the gem's runtime code.

## Golden rules

1. **Templates are security-relevant.** A flaw in a `.tt` template is copied
   into every host that runs the generator. Generated controllers authenticate
   by default; generated queries stay tenant-scoped; never weaken a generated
   security control without flagging it.
2. **Engines never reach into each other.** Cross-engine communication goes
   through `Seams::Events::Publisher` and subscribers; the custom cops in
   `lib/seams/cops/` enforce this in hosts. Don't generate code the cops would
   flag.
3. **Mind ERB escaping in templates.** `<%%=` emits a literal `<%=` into the
   generated file; `<%=` interpolates at generation time. Getting this wrong
   ships broken files to hosts.
4. **Test-first.** Generator behaviour is specified in `spec/generators/`;
   every template change needs a spec asserting the generated output.
5. **Update the docs with the change.** A new engine, flag, or option touches
   `doc/` (and often `doc/reference/ENGINE_CATALOGUE.md`) plus `CHANGELOG.md` in the
   same PR — CI has documentation guards that catch drift.

## Repository map

- `lib/seams/cli.rb` + `lib/seams/cli/` — the `bin/seams` command surface.
- `lib/generators/seams/` — one generator per engine/feature; templates live
  in each generator's `templates/` directory as `.tt` files.
- `lib/seams/generators/` — shared generator machinery (host injection,
  dummy-app writer, splicer, eject support).
- `lib/seams/cops/` — the boundary-enforcing RuboCop cops shipped to hosts.
- `lib/seams/{events,permissions,observability}*` — runtime support engines
  hosts call into.
- `spec/` — RSpec, mirroring `lib/`; `spec/integration_full/` boots real
  hosts against Postgres.
- `doc/` — the guides; `docs-site/` — the published documentation site.

## Commands

```bash
bin/audit --fast     # rubocop + rspec + bundle-audit + brakeman (~5s) — the pre-push gate
bin/audit            # all of the above + spec/integration_full (~30s)
bundle exec rspec    # tests only
bundle exec rubocop  # lint only (-A to autocorrect)
```

## Definition of done for a change

- `bin/audit --fast` is green (run the full `bin/audit` for template,
  subscriber, or contract changes).
- New/changed generator output has specs.
- `CHANGELOG.md` has an entry under `Unreleased`.
- The relevant `doc/` guide is updated in the same PR.
- Branch protection requires the `Lint`, `Security`, `RSpec`, and
  `Integration` checks — see [CONTRIBUTING.md](CONTRIBUTING.md).
