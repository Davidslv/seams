# ADR-0003: Tailwind v4 is a hard dependency of the `design` engine

- Status: accepted
- Date: 2026-06-26

> Backfilled from the design-system proposal (Decision D2).

## Context and problem statement

The design engine ships component styling. We had to decide whether to
build a framework-agnostic CSS layer (own build pipeline, own token
system) or to stand on an existing utility framework. A neutral layer
would be portable but would mean reinventing a tokenization and build
story that hosts would still have to wire up.

## Decision drivers

- Theming should be a token override, not a fork of the component CSS.
- Minimise the build machinery a host has to own.
- The reference host (quire-saas) already standardised on Tailwind v4.

## Considered options

- Framework-agnostic CSS with a bespoke build.
- Bootstrap or another component framework.
- Tailwind v4 as a hard dependency, with `@theme` tokens injected into
  the host `application.css`.

## Decision outcome

Chosen option: "Tailwind v4 as a hard dependency", because its `@theme`
mechanism gives exactly the token-override theming model we want, and
hosts get a mature, well-understood build instead of a Seams-specific
one. Retheming becomes a matter of overriding tokens (demonstrated by
the example `_quire.css` theme).

### Consequences

- Good, because theming is a token override and the build is Tailwind's,
  not ours.
- Bad, because the `design` engine is *not* usable on a non-Tailwind
  host; this is an explicit, documented constraint, not a bug.
