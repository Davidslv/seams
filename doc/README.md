# Seams documentation

This index organises the docs by **what you're trying to do**, following
the [Diátaxis](https://diataxis.fr/) framework. Find your situation, not
a filename.

The files themselves still live flat in `doc/`; this page is the map. (A
physical reorg into quadrant folders is tracked separately — see the docs
proposal.)

---

## 🎓 Tutorials — *learning by doing*

Start here if Seams is new to you. Follow the steps and watch it work.

- **[TUTORIAL.md](TUTORIAL.md)** — **Your first engine in 10 minutes.** From `rails new` to a booting, styled host.
- [GETTING_STARTED.md](GETTING_STARTED.md) — the fuller install walkthrough (what each generator writes, how to wire it up).

## 🔧 How-to guides — *accomplishing a specific task*

You know what you want; here's how.

- [ADDING_AN_ENGINE.md](ADDING_AN_ENGINE.md) — build your own engine on the generic generator.
- [REMOVING_AN_ENGINE.md](REMOVING_AN_ENGINE.md) — remove an engine cleanly.
- [WRITING_AN_ADAPTER.md](WRITING_AN_ADAPTER.md) — swap in Mailgun, Twilio, Paddle, etc.
- [WRITING_FOLLOW_UP_GENERATORS.md](WRITING_FOLLOW_UP_GENERATORS.md) — extend an installed engine.
- [DEPLOYING.md](DEPLOYING.md) — ship a host to production.
- [UPGRADING_FROM_WAVE_8.md](UPGRADING_FROM_WAVE_8.md) — migrate a pre-Wave-9 host.

## 📖 Reference — *look up a fact while working*

Precise, dependable descriptions of the machinery.

- **[API reference (rubydoc.info/gems/seams)](https://rubydoc.info/gems/seams)** — the public Ruby API (event bus, registries, adapters, configuration).
- [ENGINE_CATALOGUE.md](ENGINE_CATALOGUE.md) — every canonical engine, model, event, and config knob.
- [CURRENT_ATTRIBUTES.md](CURRENT_ATTRIBUTES.md) — the per-request `Current` namespaces and their cascade order.
- [PERMISSIONS.md](PERMISSIONS.md) — ability codes, role hierarchy, the grant map, `authorize_permission!`.
- [INSERTION_POINTS.md](INSERTION_POINTS.md) — the marker format spec.
- [INSERTION_POINTS_CATALOGUE.md](INSERTION_POINTS_CATALOGUE.md) — the canonical 33 markers.
- [OBSERVABILITY.md](OBSERVABILITY.md) — logging/tracing/metrics integration.
- [TESTING.md](TESTING.md) — the per-engine test setup.
- Design system: [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) · [foundations](DESIGN_SYSTEM_FOUNDATIONS.md) · [components](DESIGN_SYSTEM_COMPONENTS.md) · [forms](DESIGN_SYSTEM_FORMS.md) · [theming](DESIGN_SYSTEM_THEMING.md) · [accessibility](DESIGN_SYSTEM_ACCESSIBILITY.md)

## 💡 Explanation — *understand why it's built this way*

Background and rationale. Read when you want the *why*, not the *how*.

- [ARCHITECTURE.md](ARCHITECTURE.md) — the short overview.
- [ARCHITECTURE_WAVE_9.md](ARCHITECTURE_WAVE_9.md) — full system walk-through (post-Wave-9).
- [ARCHITECTURE_WAVE_10.md](ARCHITECTURE_WAVE_10.md) — insertion points, follow-up generators, eject CLI.
- [ARCHITECTURE_WAVE_11.md](ARCHITECTURE_WAVE_11.md) — the admin engine.
- [WAVE_11_PII_GDPR.md](WAVE_11_PII_GDPR.md) — PII encryption & GDPR handling.
- [adr/](adr/) — Architecture Decision Records: the *why* behind hard-to-reverse calls.

---

For contributors: [CONTRIBUTING.md](../CONTRIBUTING.md) ·
[SECURITY.md](../SECURITY.md) · [CHANGELOG.md](../CHANGELOG.md) ·
[RELEASING.md](../RELEASING.md)
