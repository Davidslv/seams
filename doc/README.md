# Seams documentation

The docs are organised by **what you're trying to do**, following the
[Diátaxis](https://diataxis.fr/) framework — one folder per quadrant.
Everything here is also published, searchable and cross-linked, at
**[davidslv.uk/seams](https://davidslv.uk/seams/)**; these files are
the source of truth.

---

## 🎓 [tutorials/](tutorials/) — *learning by doing*

Start here if Seams is new to you. Follow the steps and watch it work.

- **[TUTORIAL.md](tutorials/TUTORIAL.md)** — **Your first engine in 10 minutes.** From `rails new` to a booting, styled host.
- [GETTING_STARTED.md](tutorials/GETTING_STARTED.md) — the fuller install walkthrough (what each generator writes, how to wire it up).

## 🔧 [how-to/](how-to/) — *accomplishing a specific task*

You know what you want; here's how.

- [ADDING_AN_ENGINE.md](how-to/ADDING_AN_ENGINE.md) — build your own engine on the generic generator.
- [REMOVING_AN_ENGINE.md](how-to/REMOVING_AN_ENGINE.md) — remove an engine cleanly.
- [WRITING_AN_ADAPTER.md](how-to/WRITING_AN_ADAPTER.md) — swap in Mailgun, Twilio, Paddle, etc.
- [WRITING_FOLLOW_UP_GENERATORS.md](how-to/WRITING_FOLLOW_UP_GENERATORS.md) — extend an installed engine.
- [DEPLOYING.md](how-to/DEPLOYING.md) — ship a host to production.
- [UPGRADING_FROM_WAVE_8.md](how-to/UPGRADING_FROM_WAVE_8.md) — migrate a pre-Wave-9 host.

## 📖 [reference/](reference/) — *look up a fact while working*

Precise, dependable descriptions of the machinery.

- **[API reference (rubydoc.info/gems/seams)](https://rubydoc.info/gems/seams)** — the public Ruby API (event bus, registries, adapters, configuration).
- [ENGINE_CATALOGUE.md](reference/ENGINE_CATALOGUE.md) — every canonical engine, model, event, and config knob.
- [CURRENT_ATTRIBUTES.md](reference/CURRENT_ATTRIBUTES.md) — the per-request `Current` namespaces and their cascade order.
- [PERMISSIONS.md](reference/PERMISSIONS.md) — ability codes, role hierarchy, the grant map, `authorize_permission!`.
- [INSERTION_POINTS.md](reference/INSERTION_POINTS.md) — the marker format spec.
- [INSERTION_POINTS_CATALOGUE.md](reference/INSERTION_POINTS_CATALOGUE.md) — the canonical 33 markers.
- [OBSERVABILITY.md](reference/OBSERVABILITY.md) — logging/tracing/metrics integration.
- [TESTING.md](reference/TESTING.md) — the per-engine test setup.

## 🎨 [design-system/](design-system/) — *the design engine*

- [DESIGN_SYSTEM.md](design-system/DESIGN_SYSTEM.md) — overview (start here).
- [DESIGN_SYSTEM_FOUNDATIONS.md](design-system/DESIGN_SYSTEM_FOUNDATIONS.md) — tokens & scales.
- [DESIGN_SYSTEM_COMPONENTS.md](design-system/DESIGN_SYSTEM_COMPONENTS.md) — the 33 `ui_*` components.
- [DESIGN_SYSTEM_FORMS.md](design-system/DESIGN_SYSTEM_FORMS.md) — `Design::FormBuilder`.
- [DESIGN_SYSTEM_THEMING.md](design-system/DESIGN_SYSTEM_THEMING.md) — retheme via token override.
- [DESIGN_SYSTEM_ACCESSIBILITY.md](design-system/DESIGN_SYSTEM_ACCESSIBILITY.md) — the accessibility contract.

## 💡 [explanation/](explanation/) — *understand why it's built this way*

Background and rationale. Read when you want the *why*, not the *how*.

- [ARCHITECTURE.md](explanation/ARCHITECTURE.md) — the short overview, including where the design would strain.
- [ARCHITECTURE_WAVE_9.md](explanation/ARCHITECTURE_WAVE_9.md) — full system walk-through (post-Wave-9).
- [ARCHITECTURE_WAVE_10.md](explanation/ARCHITECTURE_WAVE_10.md) — insertion points, follow-up generators, eject CLI.
- [ARCHITECTURE_WAVE_11.md](explanation/ARCHITECTURE_WAVE_11.md) — the admin engine.
- [WAVE_11_PII_GDPR.md](explanation/WAVE_11_PII_GDPR.md) — PII encryption & GDPR handling.
- [adr/](adr/) — Architecture Decision Records: the *why* behind hard-to-reverse calls.

## 🗄 [internal/](internal/) — *maintainer-facing working documents*

Review write-ups and handoffs. Not published to the docs site.

---

For contributors: [CONTRIBUTING.md](../CONTRIBUTING.md) ·
[SECURITY.md](../SECURITY.md) · [CHANGELOG.md](../CHANGELOG.md) ·
[RELEASING.md](../RELEASING.md) · [AGENTS.md](../AGENTS.md)
