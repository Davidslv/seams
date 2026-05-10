# Releasing seams

This document describes how a maintainer cuts a new release of the
`seams` gem to [rubygems.org](https://rubygems.org/gems/seams). It
covers both the routine flow (one tag push, CI does the rest) and
the one-time trusted-publisher setup that makes the routine flow
work.

If you've cloned this repo as a contributor and don't have publish
rights, you can stop reading here — `bundle install`, run the tests,
open a PR. The rest of this file is for the people whose name is on
[`Owners`](https://rubygems.org/gems/seams/owners) at rubygems.org.

---

## The routine flow (one tag push)

Every release after `v0.1.0` is a single five-line shell ritual:

```bash
# 1. Bump the version
$EDITOR lib/seams/version.rb
# Change `VERSION = "0.1.0"` to the new SemVer.

# 2. Promote the changelog
$EDITOR CHANGELOG.md
# Move the in-flight entries from `[Unreleased]` to `[0.2.0] — YYYY-MM-DD`.

# 3. Commit
git add lib/seams/version.rb CHANGELOG.md
git commit -m "Release v0.2.0"
git push origin main

# 4. Tag + push the tag
git tag -a v0.2.0 -m "v0.2.0 — <one-line summary>"
git push origin v0.2.0
```

The tag push triggers
[`.github/workflows/release.yml`](.github/workflows/release.yml).
The workflow:

1. **Verifies the tag matches `Seams::VERSION`.** Fails fast if
   they've drifted (e.g. you forgot the version bump in step 1).
2. **Runs `bin/audit --fast`.** Rubocop + the unit suite + brakeman
   + bundler-audit. If any of those fail, the gem doesn't ship.
3. **Mints a short-lived rubygems.org token via OIDC.** No long-lived
   API key in CI secrets — the workflow's GitHub identity is
   verified against rubygems.org's trusted-publisher configuration
   on every push.
4. **Builds + pushes the gem.** `gem build seams.gemspec` + `gem
   push seams-<version>.gem`. The new version becomes immediately
   visible at <https://rubygems.org/gems/seams>.

Watch the workflow at
<https://github.com/Davidslv/seams/actions/workflows/release.yml>.
Typical run time ~2 minutes.

After the workflow goes green, cut a GitHub release at the new tag:

```bash
gh release create v0.2.0 --title "v0.2.0 — <summary>" --notes-from-tag
# or paste your own notes:
gh release create v0.2.0 --title "v0.2.0 — <summary>" --notes "$(cat <<EOF
<release notes — usually the CHANGELOG entry for the version>
EOF
)"
```

That's the whole flow. Three files edited, one commit, one tag, one
optional GitHub release. CI handles credentials + build + push.

---

## One-time setup: rubygems.org trusted publisher

This needs to be done **once** to make the routine flow work. If
the trusted publisher is already registered (you can check at
<https://rubygems.org/gems/seams/trusted_publishers>), skip this
section.

The trusted publisher binds the workflow's GitHub-issued OIDC
identity to push rights on the `seams` gem at rubygems.org. No
secret is ever stored — rubygems.org verifies the OIDC token
cryptographically against GitHub's identity provider on every push.

1. Sign in to rubygems.org with an account on the gem's owner list.
2. Visit <https://rubygems.org/gems/seams/trusted_publishers/new>.
3. Choose **GitHub Actions** as the publisher type.
4. Fill the form:

   | Field | Value |
   |---|---|
   | Repository owner | `Davidslv` |
   | Repository name | `seams` |
   | Workflow filename | `release.yml` |
   | Environment | `rubygems` |

5. Save. The trusted publisher appears at
   <https://rubygems.org/gems/seams/trusted_publishers>.

The `Environment` value matches the `environment.name` in
`release.yml` and is the cheapest extra security boundary — the
workflow only mints OIDC tokens when running in the `rubygems`
environment, which a separate "deploy approver" can be required for
if the project ever wants two-person review on releases. (Today
the environment has no approval requirement; it's there as a
hook.)

After the trusted publisher is registered, **revoke any personal
API keys** that were used for past manual pushes:

- <https://rubygems.org/profile/api_keys>

From here on, every release is OIDC-authenticated. There's no key
in `~/.gem/credentials`, no key in CI secrets, no key in the repo.

---

## Manual fallback

If for some reason the workflow can't run (GitHub Actions outage,
trusted publisher not yet registered, the workflow file itself is
broken), you can publish from your laptop:

1. Mint a short-lived API key at
   <https://rubygems.org/profile/api_keys> with `push_rubygem`
   scope and a 1-day expiry.
2. Save it to `~/.gem/credentials`:
   ```bash
   mkdir -p ~/.gem
   chmod 0700 ~/.gem
   cat > ~/.gem/credentials <<'CREDS'
   ---
   :rubygems_api_key: rubygems_<paste-the-key-here>
   CREDS
   chmod 0600 ~/.gem/credentials
   ```
3. Build + push:
   ```bash
   bin/audit
   gem build seams.gemspec
   gem push seams-<version>.gem
   ```
4. After the push succeeds, **revoke the key** at
   <https://rubygems.org/profile/api_keys>. Treat any key that has
   touched `gem push` as compromised.

This path is documented for completeness, not as the recommended
flow. Use the routine flow whenever GitHub Actions is healthy.

---

## Versioning policy

`seams` follows [Semantic Versioning](https://semver.org/):

- **Major** (`1.0.0`, `2.0.0`, ...) — breaking change to a public
  API. Examples: removing a generator, changing the shape of a
  generator's output, renaming a public class. Only ever cut from
  a Wave that's been advertised as breaking. Pre-`1.0.0`, breaking
  changes can land in a minor version (rubygems convention) but the
  CHANGELOG must call them out explicitly.
- **Minor** (`0.2.0`, `0.3.0`, ...) — new features, additive
  changes, new generators. Examples: a new follow-up generator, a
  new opt-in engine, a new config knob with a sensible default.
- **Patch** (`0.1.1`, `0.1.2`, ...) — bug fixes, doc updates,
  rubocop / brakeman / bundle-audit fixes that don't change
  behaviour. Examples: a typo in a generator template, a missing
  marker, a CI-only fix.

The CHANGELOG follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — every
entry under a version's heading is grouped by `Added`, `Changed`,
`Deprecated`, `Removed`, `Fixed`, `Security`.
