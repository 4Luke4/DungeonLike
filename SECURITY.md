# Security Policy

DungeonLike is an offline, single-player Android application. It ships no server
component, and the project operates no service that processes player data. The
security surface is therefore limited to the application itself, its supply
chain, and this repository's automation.

## Supported versions

Security fixes are produced for the most recent published version only. The
current version is recorded in [`VERSION`](VERSION) and
[`CHANGELOG.md`](CHANGELOG.md).

| Version | Supported |
| --- | --- |
| Latest release published on Google Play | Yes |
| Any earlier release | No — update through Google Play |
| Pre-release `0.x` development builds | No |

Because distribution is exclusively through Google Play, the supported version
is whatever Play currently serves. There is no side-loaded or self-hosted
distribution channel, and any build obtained elsewhere is unsupported.

## Reporting a vulnerability

Report privately. **Do not open a public issue for a suspected vulnerability.**

1. Open a private report through GitHub Security Advisories:
   <https://github.com/4Luke4/DungeonLike/security/advisories/new>.
2. Include the affected version, the device and Android version, what an
   attacker gains, and the minimal steps to reproduce. A run seed and a logcat
   excerpt help; please redact anything personal before attaching it.

What to expect:

| Stage | Target |
| --- | --- |
| Acknowledgement of the report | 3 business days |
| Initial assessment and severity | 10 business days |
| Status update cadence while open | Every 14 days |
| Fix released for an accepted high-severity issue | 90 days, or sooner |

If a report is declined, the reasoning is explained in the advisory thread.
Accepted reports are credited in the advisory and in `CHANGELOG.md` unless the
reporter asks otherwise. There is no bug bounty.

## In scope

- The published application: local privilege boundaries, save-file integrity,
  handling of untrusted input, and any unintended data exposure.
- Fairness of the random number generation used for runs and loot, as described
  in [`docs/rng/RNG_DESIGN.md`](docs/rng/RNG_DESIGN.md).
- This repository's supply chain: workflow permissions, dependency automation,
  and anything that could cause an unreviewed change to reach a build.

## Out of scope

- Google Play, Google Play services and Play Games infrastructure — report those
  to Google.
- Attacks that require a rooted device, a modified operating system, or physical
  access to an unlocked device.
- The fact that a player can read or modify data on their own device. Save
  integrity is tamper-**evident**, not tamper-proof; the threat model in
  [`docs/architecture/THREAT_MODEL.md`](docs/architecture/THREAT_MODEL.md)
  explains what is and is not defended, and why an offline single-player game
  does not treat the device owner as an adversary.

## Handling of secrets

No credential, signing key or keystore is ever committed to this repository, or
written to workflow logs, build artifacts or pull request text. Release signing
material lives only in protected GitHub environments. If you believe a secret
has been exposed, report it through the private channel above rather than
opening an issue.
