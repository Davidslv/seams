# Getting Started

This walks through installing Seams in a fresh Rails app and
generating your first canonical engine.

## Prerequisites

- Ruby 3.2+
- Rails 7.1+ (8.x recommended)
- A new or existing Rails application

## 1. Install

```ruby
# Gemfile
gem "seams"
```

```bash
bundle install
bin/rails generate seams:install
```

The install generator scaffolds:

- `config/initializers/seams.rb`
- `config/initializers/seams_engines.rb` — adds `engines/*` to autoload
- `engines/.keep`
- `lib/tasks/seams.rake`
- `.github/workflows/ci.yml` — lint + brakeman + per-engine test matrix
- `bin/seams` — short CLI wrapper

## 2. Generate your first engine

```bash
bin/seams auth
```

Look at what it created:

```bash
$ tree engines/auth -L 2
engines/auth
├── LICENSE
├── README.md
├── auth.gemspec
├── app/
│   ├── controllers/
│   ├── models/
│   └── views/
├── config/
│   └── routes.rb
├── db/
│   └── migrate/
├── lib/
└── spec/
```

## 3. Wire it up

Add the engine's mount line to your host routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Auth::Engine, at: "/auth"
end
```

Add the authentication concern to your ApplicationController:

```ruby
class ApplicationController < ActionController::Base
  include Auth::Authentication
end
```

Run migrations:

```bash
bin/rails db:migrate
```

## 4. Generate more engines

```bash
bin/seams notifications     # outbound email/SMS, swappable adapters
bin/seams billing           # Stripe subscriptions + webhooks
bin/seams teams             # multi-tenant teams + invitations
```

Every time you generate a new engine the existing engines'
`.rubocop.yml` files are auto-updated so the boundary cops cover
the new engine without manual edits.

## 5. Inspect what you have

```bash
bin/seams list
```

Lists every engine and the events it emits.

## 6. Run the boundary cops

```bash
bundle exec rubocop
```

Per-engine `.rubocop.yml` already loads `seams/cops`. CI runs the
same lint job in `.github/workflows/ci.yml`.

## 7. Run the engine specs

```bash
bin/seams test auth
```

Each engine has its own `spec/` directory. The CI workflow runs all
of them in parallel (one job per engine).

## Next steps

- [ADDING_AN_ENGINE.md](ADDING_AN_ENGINE.md) — Build your own engine on top of the generic generator.
- [WRITING_AN_ADAPTER.md](WRITING_AN_ADAPTER.md) — Swap in Mailgun, Twilio, Paddle, etc.
- [ENGINE_CATALOGUE.md](ENGINE_CATALOGUE.md) — The four canonical engines in detail.
- [ARCHITECTURE.md](ARCHITECTURE.md) — Why Seams is built this way.
