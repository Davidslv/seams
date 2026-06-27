# Tutorial: your first engine in 10 minutes

By the end of this you'll have a fresh Rails app with a Seams auth engine
and a styled, signed-in dashboard — booting locally. Follow every step in
order; each builds on the last.

> This is a **tutorial** (learning by doing). For the per-generator
> reference, see [GETTING_STARTED.md](GETTING_STARTED.md) and
> [ENGINE_CATALOGUE.md](ENGINE_CATALOGUE.md).

**Prerequisites:** Ruby 3.2+, Rails 7.1+ (8.x recommended), and a
database (the default SQLite is fine for this).

## 1. A new Rails app (≈2 min)

```bash
rails new blog && cd blog
```

## 2. Add Seams (≈1 min)

```bash
bundle add seams
bin/rails generate seams:install
```

`seams:install` wires the framework into your host: a `bin/seams`
wrapper, the engine load path, a CI workflow, and an opinionated quality
toolchain (strong_migrations + lefthook by default; see
[`--no-*` flags](GETTING_STARTED.md)).

## 3. Generate the shared core + auth (≈2 min)

```bash
bin/seams core
bin/seams auth
```

- `core` ships the primitives every engine builds on (Current attributes,
  the audit log, shared concerns).
- `auth` is a real Rails engine under `engines/auth/` — Identity, Session,
  sign-up/in/out flows, and the `Auth::Authentication` controller concern.
  The code is yours to read and edit.

## 4. Add a styled shell (≈1 min)

```bash
bin/seams design --shell
```

`design --shell` generates the design system **and** an application
layout plus a signed-in starter dashboard, so the app looks like a
product rather than Rails scaffolding.

## 5. Wire it together (≈2 min)

Mount the engines in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount Auth::Engine, at: "/auth"
end
```

Mix the authentication concern into your `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  include Auth::Authentication
end
```

Create the tables:

```bash
bin/rails db:migrate
```

## 6. Boot it (≈1 min)

```bash
bin/rails server
```

Visit `http://localhost:3000/auth/sign_up`, create an account, and you
land on the styled dashboard at `/dashboard`. That's auth + a product UI
in six commands — every file in your repo, nothing hidden behind the gem.

## 7. See what you have

```bash
bin/seams list
```

Lists each engine and the events it emits and subscribes to.

## Where to go next

- Add more product surface: `bin/seams accounts`, `bin/seams billing`,
  `bin/seams teams` — see the [Engine Catalogue](ENGINE_CATALOGUE.md).
- Make a file your own (stop the generator overwriting it):
  `bin/seams resolve --eject auth/<file>`.
- Understand the boundaries: [ARCHITECTURE.md](ARCHITECTURE.md).
