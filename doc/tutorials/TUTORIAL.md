# Tutorial: your first engine in 10 minutes

By the end of this you'll have a new Rails app with a Seams auth engine
and a styled dashboard you can sign up into, running locally. Follow
every step in order. Each one builds on the last.

> This is a **tutorial** (learning by doing). For what each generator
> writes, see [GETTING_STARTED.md](GETTING_STARTED.md) and the
> [Engine Catalogue](../reference/ENGINE_CATALOGUE.md).

**Prerequisites:** Ruby 3.3+, Rails 7.1+ (8.x recommended), and
**PostgreSQL** running locally. Seams engines use `jsonb` columns, so
the default SQLite database will not work.

## 1. A new Rails app (≈2 min)

```bash
rails new blog --database=postgresql && cd blog
bin/rails db:create
```

## 2. Add Seams (≈1 min)

```bash
bundle add seams
bin/rails generate seams:install
bundle install
```

`seams:install` wires the framework into your app: a `bin/seams`
command, the engine load path, a CI workflow, and a quality toolchain
(strong_migrations and lefthook by default). It also adds gems to your
Gemfile, which is why `bundle install` follows it.

## 3. Generate the shared core and auth (≈2 min)

```bash
bin/seams core
bin/seams auth
```

- `core` has the pieces every engine builds on: `Current` attributes,
  the audit log, shared concerns.
- `auth` is a real Rails engine under `engines/auth/`: `Identity`,
  `Session`, sign-up, sign-in and sign-out, and the
  `Auth::Authentication` controller concern. The code is yours to read
  and edit.

The generators wire each engine into your app for you. They add the
`mount` lines to `config/routes.rb` and include `Auth::Authentication`
in your `ApplicationController`.

## 4. Add a styled shell (≈1 min)

```bash
bin/seams design --shell
bundle install
bin/rails tailwindcss:build
```

`design --shell` generates the design system, an application layout,
and a starter dashboard at `/` and `/dashboard`. The layout loads the
compiled Tailwind CSS, so build it once now. When you change styles
later, rebuild, or run `bin/rails tailwindcss:watch` in a second
terminal.

## 5. Set up encryption keys and the database (≈2 min)

The auth engine encrypts personal data such as email addresses at rest,
using Active Record encryption. Generate keys and store them in your
credentials:

```bash
bin/rails db:encryption:init
bin/rails credentials:edit
```

`db:encryption:init` prints an `active_record_encryption:` block. Paste
it into the credentials file and save.

> Without these keys, signing up fails with
> `Missing Active Record encryption credential`.

Then create the tables:

```bash
bin/rails db:migrate
```

## 6. Run it (≈1 min)

```bash
bin/rails server
```

Visit `http://localhost:3000/auth/registration/new` and create an
account. You land on the styled dashboard. Sign in again later at
`/auth/session/new`.

## 7. See what you have

```bash
bin/seams list
```

This lists each engine, the events it publishes, and what it subscribes to.

## Where to go next

- **Add more features:** `bin/seams accounts`, `bin/seams billing` and
  `bin/seams teams`, in that order. Run `bundle install` and
  `bin/rails db:migrate` after each. See the
  [Engine Catalogue](../reference/ENGINE_CATALOGUE.md).
- **Keep your changes to a generated file:** run
  `bin/seams resolve --eject auth/<file>`, and the generator will leave
  that file alone.
- **Understand the boundaries:** [ARCHITECTURE.md](../explanation/ARCHITECTURE.md).
