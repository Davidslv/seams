# Project Governance

This document describes how Seams is governed and how decisions are
made. It is deliberately lightweight and will grow with the project.

## Current model: single maintainer

Seams is maintained by one person (see
[MAINTAINERS.md](MAINTAINERS.md)), who acts as a benevolent dictator:
final say on scope, design, and releases rests with the lead
maintainer. This is stated honestly rather than dressed up as a
committee — the intent is to grow beyond it as contributors arrive.

The gem materialises the patterns taught in
[Modular Rails: Architecture for the Long Game](https://davidslv.uk/modular-rails/),
so architectural direction tracks the book: changes that would
contradict the book's model (engine isolation, event-driven
cross-engine communication, boundary enforcement) need a strong case.

## Roles

- **Users** — anyone who runs `bin/seams`. Feedback via issues shapes
  the roadmap.
- **Contributors** — anyone who opens a pull request or issue.
  Documentation, tests, and generator-template review are valued
  equally with code.
- **Maintainers** — trusted contributors with merge rights, listed in
  [MAINTAINERS.md](MAINTAINERS.md). Maintainers review and merge
  changes, cut releases, and steward the project's direction.

## Path from contributor to maintainer

1. **Contributor** — one or more merged PRs.
2. **Reviewer** — after a track record of high-quality reviews and
   changes, a maintainer may invite you to help triage and review.
3. **Maintainer** — sustained, trusted involvement leads to an
   invitation to become a maintainer with merge and release rights.

## Decision making

- **Everyday changes** (bug fixes, docs, tests, a template polish) are
  decided by **lazy consensus**: a PR with maintainer approval, green
  CI (see [CONTRIBUTING.md](CONTRIBUTING.md) for the required checks),
  and no unresolved objections may be merged.
- **Substantial changes** (a new engine, a new public API, a change to
  the event bus or boundary-enforcement model, breaking changes to
  generated code) require a linked issue or proposal describing the
  rationale, and maintainer approval.
- **Disagreements** are resolved by discussion aimed at consensus; the
  lead maintainer breaks ties.

## Releases

Releases follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and the process in [RELEASING.md](RELEASING.md). Pre-1.0, minor
versions may contain breaking changes; they are flagged in
[CHANGELOG.md](CHANGELOG.md).

## Changing this document

Governance changes are proposed by PR against this file and decided by
the maintainers.
