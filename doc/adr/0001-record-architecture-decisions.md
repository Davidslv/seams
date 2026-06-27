# ADR-0001: Record architecture decisions

- Status: accepted
- Date: 2026-06-27

## Context and problem statement

Seams makes a number of decisions that are hard to reverse once hosts
have generated code against them (engine boundaries, namespaces, hard
dependencies). These decisions were being captured in `proposals/`
files that are a deliberately local, uncommitted convention — so the
rationale wasn't discoverable in the published repository. New
contributors couldn't see *why* a boundary was drawn the way it was.

## Decision drivers

- Rationale must be discoverable in the repository, not only on a
  maintainer's laptop.
- The format should be lightweight enough that writing one isn't a
  chore, and standard enough to be recognisable.
- Records must be immutable so history stays honest.

## Considered options

- Keep rationale in `proposals/` only (local, uncommitted).
- Michael Nygard's original ADR format.
- MADR 4.0.

## Decision outcome

Chosen option: "MADR 4.0", because it is the current de-facto standard,
is more structured than Nygard's format (explicit decision drivers and
considered options), and stays short. Proposals remain the place where
a decision is *worked out*; an ADR is where the *accepted* decision is
recorded for posterity.

### Consequences

- Good, because the "why" behind each hard-to-reverse decision is now
  in the repo and linked from the docs.
- Good, because the design-system decisions (D1–D4) get backfilled as
  ADR-0002 through ADR-0005.
- Bad, because there are now two places (proposals + ADRs) and authors
  must remember to graduate an accepted proposal into an ADR.
