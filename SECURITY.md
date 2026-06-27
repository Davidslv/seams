# Security Policy

## Supported versions

Seams is pre-1.0 and under active development. Security fixes are
applied to the `main` branch and released in the next gem version.
There are no long-term support branches yet.

| Version | Supported |
| --- | --- |
| `main` / latest release | ✅ |
| older releases | ❌ (upgrade to the latest) |

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Seams is a code *generator*: a vulnerability in a template can be
copied into every host that runs the affected generator, so we treat
template and generated-code issues as security-relevant too (examples:
missing authorization on a generated controller, an information
disclosure in a generated scope, an injection in a generated view).

Report privately via either:

- **GitHub Security Advisories** — the preferred route. Open a draft
  advisory at
  <https://github.com/Davidslv/seams/security/advisories/new>.
- **Email** — `davidslv.london@gmail.com` with `[seams security]` in
  the subject line.

Please include:

- the generator and/or file affected (e.g. `seams:teams`,
  `app/controllers/teams/invitations_controller.rb`);
- the version or commit SHA;
- a description of the impact and, ideally, a minimal reproduction
  (a generated host, the request, the observed vs. expected behaviour).

## What to expect

- **Acknowledgement** within 3 business days.
- An initial assessment (severity, affected generators) within 7 days.
- We will keep you updated as a fix is developed, credit you in the
  release notes if you wish, and coordinate a disclosure date.

## Scope

In scope: the gem's own code under `lib/`, the generator templates
under `lib/generators/seams/**/templates/`, and the code those
templates produce in a host.

Out of scope: vulnerabilities in third-party dependencies (report
those upstream — though please flag them so we can pin/patch), and
issues that require a host to deliberately misconfigure or remove a
generated security control.
