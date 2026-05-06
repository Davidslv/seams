# Seams

> A CLI framework that generates modular Rails engines.

Seams gives you the architectural benefits of microservices — clear boundaries, independent testing, team autonomy — without the operational cost. You ship a single Rails app. You think in independent modules.

## What Seams Is

Seams is a Ruby gem that adds first-class engine lifecycle commands to any Rails application:

```bash
bin/rails seams:install                          # Adds the framework + core engine
bin/rails seams:engine billing --gateway=stripe  # Generates a fully-wired billing engine
bin/rails seams:engine notifications             # Generates a notifications engine
bin/rails seams:list                             # Shows engines, dependencies, events
bin/rails seams:test billing                     # Runs billing engine tests
bin/rails seams:remove billing                   # Removes the engine cleanly
```

Each generated engine is a real, mountable Rails Engine with `isolate_namespace`, its own dummy app, contract tests, and event-driven communication with other engines.

## Installation

```ruby
# Gemfile
gem "seams"
```

```bash
bundle install
bin/rails seams:install
```

## Documentation

- [Getting Started](doc/GETTING_STARTED.md)
- [Adding an Engine](doc/ADDING_AN_ENGINE.md)
- [Removing an Engine](doc/REMOVING_AN_ENGINE.md)
- [Writing an Adapter](doc/WRITING_AN_ADAPTER.md)
- [Architecture](doc/ARCHITECTURE.md)
- [Testing](doc/TESTING.md)
- [Engine Catalogue](doc/ENGINE_CATALOGUE.md)

## Status

Pre-release. Phase 1 (foundation) in active development.

## License

MIT — see [LICENSE](LICENSE).
