# Deploying

Seams ships a multi-stage Dockerfile, a Kamal config skeleton, and a
Procfile via the install generator. None of them is mandatory — Rails 8
already generates a Dockerfile, and Heroku/Render/Fly hosts can read
the Procfile directly.

## What `seams:install` generates

| File                      | Purpose                                                                |
| ---                       | ---                                                                    |
| `Dockerfile`              | Multi-stage build. Layer-caches engine gemspecs separately. Skip if you have your own. |
| `bin/docker-entrypoint`   | Runs `db:prepare` on container start so engine migrations apply automatically. |
| `Procfile`                | `web:` + `worker:` definitions for Heroku-style hosts.                |
| `config/deploy.yml`       | Kamal skeleton — fill in hosts and secrets.                           |

Each is created only if the host doesn't already have one (Rails 8's
own `Dockerfile`/`bin/docker-entrypoint` are kept verbatim).

## Engine-aware Docker layer caching

The Dockerfile copies `engines/` early in the bundle-install layer so
adding a new engine doesn't invalidate the bundler cache for the
others:

```dockerfile
FROM base AS gems
COPY Gemfile Gemfile.lock ./
COPY engines/ ./engines/    # <- engine gemspecs land here
RUN bundle install
```

When the install generator runs again (e.g. after `bin/seams billing`),
it doesn't rewrite the Dockerfile — but `bundle install` inside the
container picks up the new engine gemspec on the next image build.

## Databases in production (Rails 8)

A Rails 8 app has **four** production databases in `config/database.yml`:
`primary`, plus `cache`, `queue` and `cable` for Solid Cache, Solid Queue
and Solid Cable. `DATABASE_URL` only configures `primary`. Unless you
configure the other three, `db:prepare` creates the primary database and
then fails, because it tries a local socket for the rest:

```text
connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed
```

Give each of them a URL. Rails reads `<NAME>_DATABASE_URL` for a named
database. They can live on the same Postgres server as long as the
database names differ:

```bash
DATABASE_URL=postgres://app:secret@db.example.com/app_production
CACHE_DATABASE_URL=postgres://app:secret@db.example.com/app_production_cache
QUEUE_DATABASE_URL=postgres://app:secret@db.example.com/app_production_queue
CABLE_DATABASE_URL=postgres://app:secret@db.example.com/app_production_cable
```

Alternatively, edit the `production:` block of `config/database.yml` to
point all four at your server.

> Verified with a generated app running every engine against
> `postgres:18` in Docker. With all four URLs set, the container ran
> `db:prepare` and served requests.

## Encryption keys

The auth engine encrypts personal data (such as email addresses) with
Active Record encryption. Production needs the same three keys as
development:

```bash
bin/rails db:encryption:init     # prints an active_record_encryption: block
bin/rails credentials:edit       # paste it in (or credentials:edit --environment production)
```

Ship the key that decrypts those credentials as `RAILS_MASTER_KEY`, or
`config/credentials/production.key` if you use per-environment
credentials. Without the encryption keys, the app boots, but the first
sign-up or sign-in raises
`Missing Active Record encryption credential: active_record_encryption.deterministic_key`.

> [!WARNING]
> Keep these keys stable. Rotating or losing them makes existing
> encrypted rows unreadable. Follow the Rails
> [key rotation guide](https://guides.rubyonrails.org/active_record_encryption.html#rotating-keys)
> before changing them.

## Migrations

`bin/docker-entrypoint` runs `bundle exec rails db:prepare` when the
container starts the web server. Workers skip it. That's idempotent — Rails skips already-applied migrations —
but if you'd rather control migrations from a one-off task (Kamal's
`pre-deploy` hook, GitHub Actions step, etc.) comment that line out.

## Kamal

`config/deploy.yml` is a starter. The fields that matter:

```yaml
service: my-app
image: my-org/my-app

servers:
  web:    [1.2.3.4]
  worker:
    cmd: bundle exec rails solid_queue:start
    hosts: [1.2.3.5]

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - CACHE_DATABASE_URL
    - QUEUE_DATABASE_URL
    - CABLE_DATABASE_URL
    - REDIS_URL
    - STRIPE_SECRET_KEY
    - STRIPE_WEBHOOK_SECRET
```

Engines run in the same container — there's no per-engine deployment
because the modular monolith model is one process. If you ever want
to split (e.g. a heavy worker engine onto its own machine), the
adapter pattern means you can extract a service without rewriting
the engine.

## Heroku / Render / Fly

The `Procfile` works on all three. `web:` runs Puma; `worker:` runs
Solid Queue (Rails 8's default async backend). If you use Sidekiq,
swap the worker line:

```procfile
worker: bundle exec sidekiq -c 5 -q default -q billing -q notifications
```

## Secrets every Seams app needs

| Variable                  | Set when                             |
| ---                       | ---                                  |
| `RAILS_MASTER_KEY`        | Always. Decrypts the credentials that hold the Active Record encryption keys. |
| `DATABASE_URL`            | Always (host-supplied).              |
| `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` | Rails 8 apps, unless `config/database.yml` points these databases elsewhere. See [Databases in production](#databases-in-production-rails-8). |
| `REDIS_URL`               | If using Sidekiq / ActionCable Redis. |
| `STRIPE_SECRET_KEY`       | If the Billing engine is installed.   |
| `STRIPE_WEBHOOK_SECRET`   | Same.                                 |
| `SMTP_*`                  | If the Notifications engine sends real email. |

## Healthcheck

Rails 8's default Dockerfile exposes `/up`. Reuse it:

```yaml
# config/deploy.yml (Kamal)
healthcheck:
  path: /up
  port: 3000
```

## CI → image build

The CI workflow shipped by the install generator (`.github/workflows/ci.yml`)
runs lint + per-engine tests on every push. To extend it to push a
production image to your registry on `main`, add a `release` job that
runs after the matrix succeeds:

```yaml
release:
  needs: [lint, security, test_engine, test_app]
  if: github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v7
    - uses: docker/build-push-action@v6
      with:
        push: true
        tags: my-org/my-app:${{ github.sha }}
```
