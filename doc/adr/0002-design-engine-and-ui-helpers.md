# ADR-0002: `design` engine with `ui_*` helpers

- Status: accepted
- Date: 2026-06-26

> Backfilled from the design-system proposal (Decision D1).

## Context and problem statement

The design-system engine needed two names: one for the system itself
(the engine, CLI command, folder, and Ruby namespace) and one for the
individual building blocks a host author types every day (the view
partials and their helpers). Conflating them would force an awkward
single word to do both jobs.

## Decision drivers

- The CLI/engine name should describe the *system* ("a design system").
- The per-component helper should read naturally at the call site in a
  view (`ui_button`, `f.ui_field`).
- Consistency with the rest of the canonical engines (`bin/seams <name>`).

## Considered options

- One name for everything (e.g. `design_button`, `bin/seams design`).
- One name for everything (e.g. `ui`, `bin/seams ui`).
- Split: system = `design`, part-level helper/view prefix = `ui`.

## Decision outcome

Chosen option: "Split", because the system-vs-part distinction maps
cleanly onto the two audiences. The engine, CLI command, folder, and
Ruby namespace are all `design`; the view folder and helper prefix are
`ui` — so hosts write `ui_button` and `f.ui_field` while the engine
stays `Design::*`.

### Consequences

- Good, because call sites read naturally and the engine name describes
  the whole system.
- Bad, because there are two names to learn; the docs must explain the
  `design` (system) vs `ui` (part) split up front.
