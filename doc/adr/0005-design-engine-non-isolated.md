# ADR-0005: The `design` engine is non-isolated

- Status: accepted
- Date: 2026-06-26

> Backfilled from the design-system proposal (Decision D4).

## Context and problem statement

Every other canonical Seams engine is an *isolated* Rails engine
(`isolate_namespace`), which keeps its helpers, routes, and partials
namespaced and prevents host-wide leakage — exactly the boundary
discipline Seams exists to enforce. But a design system's whole job is
to be available host-wide: `ui_button` must work in any host view, and
the `ui/` partials must resolve from anywhere.

## Decision drivers

- `ui_*` helpers and `ui/` partials must be available in every host view.
- The rest of Seams' boundary model depends on isolation; breaking it
  for one engine must be deliberate and contained.

## Considered options

- Keep `design` isolated and require hosts to manually expose helpers/
  partials.
- Make `design` a non-isolated engine whose helpers and partials are
  host-wide.

## Decision outcome

Chosen option: "Non-isolated engine", because a design system is the one
case where host-wide availability is the feature, not a leak. The Seams
generator framework was extended to support this second engine shape so
the exception is a first-class, supported pattern rather than a hack.

### Consequences

- Good, because `ui_*` helpers and `ui/` partials work everywhere in the
  host with no per-view wiring.
- Bad, because `design` is the one canonical engine that does not follow
  the isolation rule; this is called out explicitly in the engine
  catalogue so it isn't mistaken for the norm.
