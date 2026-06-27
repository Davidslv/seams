<!--
Thanks for contributing to Seams! Keep PRs small and single-concern —
a reviewer should be able to read the diff top to bottom.
-->

## What & why

<!-- What does this change do, and why? Link the issue: Closes #N
     (one `Closes #N` per issue — GitHub only auto-closes the first in
     a comma-separated list). -->

Closes #

## Type of change

- [ ] Bug fix
- [ ] New generator / template
- [ ] New feature on an existing engine
- [ ] Docs only
- [ ] Refactor / chore

## Documentation

<!-- Seams ships a code generator: a change to the command surface or a
     generated template almost always needs a docs change too. -->

- [ ] Docs updated (README / `doc/` / generated engine README), **or** N/A
- [ ] New/changed CLI commands or flags are documented in the README
      "What you get" section
- [ ] Public Ruby API has YARD comments (`@param` / `@return` / `@example`)
- [ ] `CHANGELOG.md` `[Unreleased]` updated (Added / Changed / Deprecated /
      Removed / Fixed / Security)

## Verification

- [ ] `bin/audit` passes (rubocop + rspec + bundle-audit + brakeman),
      and the full integration suite for substantive changes
- [ ] For template/generator changes: generated a real host and booted
      it (green specs alone can hide a silently-missing template — see
      CONTRIBUTING.md)

## Notes for the reviewer

<!-- Anything you want the reviewer to look at closely, trade-offs, or
     follow-ups intentionally left out of scope. -->
