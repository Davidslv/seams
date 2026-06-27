# Architecture Decision Records

This directory holds Seams' Architecture Decision Records (ADRs): short
documents capturing a single significant, hard-to-reverse decision —
the context, the options weighed, and the consequences.

We use the [MADR 4.0](https://adr.github.io/madr/) format. Each record
is immutable once accepted; if a later decision changes course, add a
new ADR and mark the old one `Superseded by ADR-NNNN` rather than
editing it.

## Index

- [ADR-0001](0001-record-architecture-decisions.md) — Record architecture decisions
- [ADR-0002](0002-design-engine-and-ui-helpers.md) — `design` engine with `ui_*` helpers
- [ADR-0003](0003-tailwind-v4-hard-dependency.md) — Tailwind v4 is a hard dependency
- [ADR-0004](0004-faithful-partial-extraction.md) — Faithful strict-locals partial extraction
- [ADR-0005](0005-design-engine-non-isolated.md) — The `design` engine is non-isolated

## Writing a new ADR

Copy [`template.md`](template.md), number it with the next free
integer, fill it in, and add it to the index above. Bigger directional
decisions usually start as a proposal under `proposals/` (a local
convention) and graduate to an ADR once accepted.
