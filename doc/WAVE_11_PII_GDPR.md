# Wave 11 — PII encryption & GDPR notes

> Status: **implemented in commit `5dd68c0` and follow-up review fixes.**
> Kept here as a record of the design decisions and the migration path for hosts upgrading from Wave ≤10. The "Scope" section below describes work that has already shipped; the rotation rake task is at `lib/generators/seams/auth/templates/lib/tasks/auth_pii.rake.tt`.

## Why this wave

GDPR (Article 4) treats `email` and any "online identifier" (Google
`sub`, GitHub user id, etc.) as personal data. Today the Auth engine
encrypts OAuth credentials at rest but stores the actual *identifiers*
in plaintext. A leaked DB dump leaks user identities. Wave 11 closes
that gap.

## Current state (as of 2026-05-07, post-Wave-10)

| Column | Table | At-rest state | PII? |
| --- | --- | --- | --- |
| `email`            | `auth_users`           | plaintext  | YES (direct) |
| `password_digest`  | `auth_users`           | bcrypt     | no (one-way hash) |
| `provider_uid`     | `auth_oauth_providers` | plaintext  | YES (online identifier) |
| `access_token`     | `auth_oauth_providers` | encrypted  | credential, not PII strictly |
| `refresh_token`    | `auth_oauth_providers` | encrypted  | credential, not PII strictly |
| `name`             | `auth_api_tokens`      | plaintext  | low risk — user-supplied label |
| `token_digest`     | `auth_api_tokens`      | SHA-256    | no |
| `token_prefix`     | `auth_api_tokens`      | plaintext  | no — first 12 chars only |

## Scope

### 1. Encrypt PII columns

- `Auth::User`: `encrypts :email, deterministic: true, downcase: true`
  - Deterministic so `find_by(email:)` and the uniqueness validation
    keep working.
  - `downcase: true` matches the existing `normalizes :email`.
- `Auth::OAuthProvider`: `encrypts :provider_uid, deterministic: true`
  - Deterministic so the `(provider, provider_uid)` lookup that powers
    OAuth sign-in still resolves.

Trade-off: deterministic encryption is weaker than non-deterministic
(same plaintext → same ciphertext, so frequency analysis on a leaked
DB is theoretically possible). It's still safe at rest and is the
standard Rails 7+ choice when you need to query by the column.

### 2. Migration for existing hosts

A one-shot rake task: `seams:auth:rotate_pii_encryption` that walks
every `auth_users` and `auth_oauth_providers` row, re-saves it so the
new `encrypts` declaration writes ciphertext. Idempotent — re-running
on already-encrypted rows is a no-op.

Document this prominently: hosts already running Wave ≤10 must run the
task once during deploy. New hosts get encrypted columns from the
generator's first migration.

### 3. README — GDPR compliance section

Add a "GDPR / data protection" section to the Auth engine README
covering:

- **Data inventory**: a table listing every PII column the engine
  stores and its encryption state.
- **One-time setup**: `bin/rails db:encryption:init` + storing keys in
  Rails credentials (link to
  https://guides.rubyonrails.org/active_record_encryption.html).
- **Right to erasure (Article 17)**:
  ```ruby
  Auth::User.find_by(email: "...").destroy
  ```
  cascades to `sessions`, `api_tokens`, `oauth_providers` via the
  `dependent: :destroy` already wired up. Document that hosts must
  also erase rows in the host's own `User` table (host_user_id).
- **Right to access / portability (Article 15 / 20)**: stub note that a
  future `Auth::ExportUserData` service will return a JSON dump. For
  now, document the SQL query pattern.
- **Data minimisation in logs**: guidance to log `auth_user_id` not
  `email`. Show how to override Rails' filter_parameters.
- **Retention**: point to `CleanupExpiredSessionsJob` and recommend a
  similar sweeper for stale `OAuthProvider` rows where the user has
  not signed in for N months.

### 4. Optional — `Auth::ExportUserData` service

Deferred. Stub a `# TODO: Wave 11+` in the README. When implemented:

```ruby
result = Auth::ExportUserData.call(user: user)
result.json   # => { user: {...}, sessions: [...], api_tokens: [...], oauth_providers: [...] }
```

`oauth_providers` should redact `access_token` / `refresh_token` —
those are the engine's secrets, not the user's data.

## Spec coverage to add

- Generator spec: `encrypts :email, deterministic: true` appears in
  `Auth::User`; `encrypts :provider_uid, deterministic: true` appears
  in `Auth::OAuthProvider`.
- Generator spec: rotate-PII rake task is generated.
- Integration spec: round-trip — create a user with email "a@b.com",
  read the raw `auth_users.email` cell, assert it's NOT "a@b.com",
  assert `find_by(email: "a@b.com")` still resolves.

## Out of scope for Wave 11

- Field-level audit logging (who-read-which-PII). Useful for
  compliance but a separate concern; defer to a future "Audit" engine.
- Pseudonymisation of `host_user_id`. Engine doesn't control the
  host's primary key; document that the host is responsible.
- Cookie-consent banners. UI concern, not engine concern.

## Order of operations when implementing

1. Add `encrypts` to the two models + migration generator updates.
2. Generator spec coverage.
3. Rotate-PII rake task + integration spec for the round-trip.
4. README rewrite.
5. `bin/audit` + 4-agent critical review before PR.

## References to verify before writing code

- https://guides.rubyonrails.org/active_record_encryption.html
- https://gdpr-info.eu/art-4-gdpr/ (definition of "personal data")
- https://gdpr-info.eu/art-17-gdpr/ (right to erasure)
- https://gdpr-info.eu/art-25-gdpr/ (data protection by design)
