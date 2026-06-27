# ADR-0004: Faithful strict-locals partial extraction (not a ViewComponent rewrite)

- Status: accepted
- Date: 2026-06-26

> Backfilled from the design-system proposal (Decision D3).

## Context and problem statement

The design engine's components were extracted from a working source
system (quire-saas' "Compositor"), which is built on Rails strict-locals
partials with auto-wired helpers. We had to decide whether to port them
faithfully or rewrite them as ViewComponents on the way in.

## Decision drivers

- The source system is proven in production; a rewrite reintroduces risk.
- Strict-locals partials need no extra runtime dependency.
- A rewrite would be a large, behaviour-changing effort for no clear gain.

## Considered options

- Rewrite every component as a ViewComponent.
- Faithful extraction of the strict-locals partial + auto-wire model.

## Decision outcome

Chosen option: "Faithful extraction", because porting the proven model
1:1 keeps the components' behaviour identical to their battle-tested
source and avoids adding the ViewComponent dependency. The engine ships
strict-locals partials with `locals:` magic comments and auto-wired
`ui_*` helpers.

### Consequences

- Good, because behaviour matches the source system and there's no extra
  runtime dependency.
- Bad, because teams who prefer ViewComponent get partials instead; they
  can wrap them themselves.
- Note: every component partial must declare its `locals:` magic comment,
  and templates must be registered in the generator (a generated-but-
  unregistered template is silently missing from hosts — caught by the
  runtime component spec).
