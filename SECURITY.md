# Security Policy

## Scope

This policy covers the DungeonLike Android application, its build and release
automation in this repository, and the data it stores on a user's device.

Out of scope: the Google Play Store platform itself, the Android operating
system, third-party upstream projects (report those to their own maintainers),
and findings that require a rooted device or an already-compromised host.

## Supported versions

DungeonLike follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The authoritative current version is in [`VERSION`](VERSION).

Security fixes are provided for the **most recent released minor version only**.
Because the application is distributed exclusively through Google Play, users
receive fixes via the store's update mechanism, and older builds are not
serviced.

| Version | Supported |
| ------- | --------- |
| 0.1.x   | ✅ Current development baseline |
| < 0.1   | ❌ Does not exist |

This table is updated on every release. Pre-1.0 versions carry no stability
guarantee: while the major version is `0`, a minor bump may include breaking
changes, as permitted by SemVer.

## Reporting a vulnerability

**Do not open a public issue for a security vulnerability.**

Report privately through GitHub's coordinated disclosure flow:

1. Go to <https://github.com/4Luke4/DungeonLike/security/advisories/new>.
2. Describe the issue, the affected version or commit, and the impact.
3. Include reproduction steps, and a proof of concept where possible.

If private reporting is unavailable to you, open a public issue containing
**only** a request for a private contact channel — no technical detail.

### What to expect

| Stage | Target |
| ----- | ------ |
| Acknowledgement of your report | within 7 days |
| Initial assessment and severity triage | within 14 days |
| Status update while work is ongoing | at least every 30 days |
| Fix released, or a documented decision not to fix | within 90 days of triage |

These are good-faith targets for a project maintained by a single individual, not
a contractual commitment.

If a report is **accepted**, you will be told the planned fix and release, and
credited in the advisory and changelog unless you ask otherwise. If a report is
**declined**, you will be told why — commonly: out of scope, not reproducible, or
an accepted risk already recorded in the threat model.

Please give us a reasonable opportunity to ship a fix before disclosing publicly.

## Safe harbour

We will not pursue or support legal action against research conducted in good
faith under this policy, provided you avoid privacy violations, data destruction,
and service degradation, and you do not access, modify, or exfiltrate data that
is not your own.

## Handling of secrets and signing material

No credential, API key, keystore, or signing material is ever committed to this
repository, or emitted into logs, build artifacts, or pull request text. Release
signing material is held outside the repository and injected at release time
through protected secrets.

If you believe a secret has been committed or leaked, report it through the
private channel above and treat it as compromised.

## Further reading

- [`docs/architecture/THREAT_MODEL.md`](docs/architecture/THREAT_MODEL.md) —
  assets, trust boundaries, and accepted risks.
- [`docs/release/READINESS.md`](docs/release/READINESS.md) — the security gates a
  release must clear.
