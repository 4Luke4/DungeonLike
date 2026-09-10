# Threat model

- **Status:** Living document
- **Last reviewed:** 2026-09-10
- **Scope:** The DungeonLike Android application, this repository, and the build
  and release pipeline that connects them.

This document records what is worth protecting, where trust changes hands, and
which risks have been accepted. It is updated whenever a change alters a
documented boundary, as required by `AGENTS.md`.

> **Current state.** The application does not exist yet. Boundaries 1 and 2 are
> live today; boundaries 3 to 6 describe the planned architecture and are recorded
> now so that the controls are designed in rather than retrofitted. Each is marked
> accordingly.

## 1. Assets

| Asset | Why it matters | Impact if compromised |
| ----- | -------------- | --------------------- |
| Release signing key | Sole proof that a build is genuinely ours | Critical — an attacker could publish a malicious app update under our identity |
| Play Console credentials | Control the store listing and rollout | Critical — malicious release, or takedown of the listing |
| Repository write access | Determines what reaches a release build | High — supply-chain compromise via workflow or dependency changes |
| Source code and game design | The commercial product itself | High — the app is sold; the repository is proprietary |
| Player save data | Player progress on device | Medium — loss or corruption destroys progress |
| Purchase entitlement | Whether the user paid | Medium — revenue loss through bypass |
| CI tokens and secrets | Privileged automation | High — an over-privileged token is a path to the assets above |

The application is a single-player, paid, offline-capable game. It collects no
personal data and operates no backend, which removes an entire class of risk:
there is no user database to breach, no session to hijack, and no server to
attack. This is a deliberate design property and should be preserved.

## 2. Trust boundaries

### Boundary 1 — Contributor to repository *(live)*

Anyone may open a pull request against a public repository.

**Threats.** Malicious code in a pull request; a workflow change that exfiltrates
secrets; a poisoned dependency; committed credentials.

**Controls.**

- `CODEOWNERS` requires the owner's review for automation, sources of truth,
  legal files, and architecture documentation.
- Every workflow declares least-privilege `permissions`, defaulting to
  `contents: read`.
- Checkouts set `persist-credentials: false` wherever the job does not push, so a
  writable token is not left on disk for arbitrary tooling to read.
- CodeQL analyses the `actions` language, which is currently the only executable
  code in the repository.
- Gitleaks runs in CI as defence in depth against committed secrets.
- Validation script dependencies are hash-pinned, so a compromised release cannot
  alter what CI enforces.

**Accepted risk.** Actions are pinned to major version tags rather than commit
SHAs. Tags are mutable, so a compromised upstream action could serve altered code.
Accepted for now in exchange for automatic security patches from Dependabot; the
blast radius is limited by least-privilege tokens. Revisit before the first
signed release, when a compromised action would gain access to signing material.

### Boundary 2 — `pull_request_target` and elevated tokens *(live)*

Two workflows use `pull_request_target`, which runs in the base repository's
context with a writable token.

**Threat.** The classic exploit is checking out and executing untrusted head code
with those privileges, turning a fork pull request into arbitrary code execution
with a write token.

**Controls.**

- `label.yml` performs **no checkout**. `actions/labeler` reads the changed-file
  list from the API.
- `dependabot-auto-merge.yml` performs **no checkout**, and is gated on both
  `github.actor` and `pull_request.user.login` being Dependabot.
- Both constraints are documented inline in the workflows so a future edit that
  adds a checkout step is visibly wrong in review.

**Accepted risk.** Auto-merge trusts Dependabot's metadata to classify an update
as `patch`/`minor`. Major updates always require a human. Required status checks
still gate the merge, so auto-merge shortens the wait for a green update rather
than bypassing verification.

### Boundary 3 — Engine binary acquisition *(planned)*

Godot's .NET Android library is **not published to MavenCentral** and must be
obtained as a GitHub release asset or built from source (ADR 0002).

**Threat.** This is the single largest supply-chain risk in the planned
architecture. A dependency without package-manager provenance is one that
Dependabot cannot track, that no resolver verifies, and whose substitution would
place attacker-controlled native code directly inside the shipped application.

**Planned controls.**

- Pin the exact engine version in `config/android/toolchain.properties`.
- Verify the artifact's checksum against the published release before use, and
  fail the build on mismatch.
- Record the expected checksum in the repository so a change to it is reviewable.
- Document the update procedure, including re-verification.
- Prefer a reproducible from-source build if verification proves insufficient.

**Status.** Open. Must be resolved in the engine integration pull request.

### Boundary 4 — Kotlin host to embedded engine *(planned)*

The Kotlin host and the C# game core exchange data across the Godot bridge.

**Threats.** Malformed data crossing the boundary; an over-broad bridge surface
that exposes host capabilities to engine-side code; leaking entitlement state.

**Planned controls.** Keep the bridge minimal and explicitly enumerated. Validate
at the boundary rather than trusting the caller. Never expose file-system or
credential APIs directly to engine code.

### Boundary 5 — Device and player data *(planned)*

Save data and settings live in app-private storage.

**Threats.** Save tampering to gain advantage; corruption causing progress loss;
data leaking through world-readable storage or backups.

**Planned controls.** App-private storage only. Treat all persisted data as
untrusted on read and validate it. Fail safe on corruption rather than crashing.
Configure backup rules deliberately.

**Accepted risk.** A single-player game on a device the player controls cannot be
protected against a determined owner modifying their own save. This is explicitly
out of scope: there is no competitive integrity to defend and no server to
protect. Anti-tamper effort here would cost more than it returns.

### Boundary 6 — Purchase entitlement *(planned)*

DungeonLike is a paid, one-time-purchase app.

**Threats.** Entitlement bypass; replay of a purchase response.

**Planned controls.** Rely on the platform's purchase verification. Do not invent
a bespoke licensing scheme.

**Accepted risk.** A fully offline paid app cannot make entitlement
unbypassable on a device the user controls. Mitigation is proportionate: use the
platform mechanism correctly and accept the residual risk rather than degrading
the experience for paying users with intrusive checks.

### Boundary 7 — Release and signing *(planned)*

**Threats.** Signing key theft or leakage into logs or artifacts; an unauthorised
release; a tampered artifact between build and publication.

**Planned controls.**

- No credential, keystore, or signing material is ever committed, logged, or
  placed in artifacts or pull request text. This is stated in `SECURITY.md` and
  enforced by `.gitignore` and Gitleaks.
- Signing material is injected at release time from protected secrets, scoped to
  a protected environment with required approval.
- Release workflows are separate from pull request workflows, so a fork pull
  request can never reach signing material.

## 3. Out of scope

- Compromise of the developer's own workstation.
- Attacks requiring a rooted device or an already-compromised operating system.
- Vulnerabilities in Android, Google Play, or upstream third-party projects —
  report those to their maintainers.
- Denial of service against a player's own device.

## 4. Review triggers

Re-review this document when:

- a new external dependency or binary artifact is introduced;
- a workflow gains privileges, or a new `pull_request_target` usage appears;
- signing or release automation is added or changed;
- the application begins collecting data, or gains any network capability;
- the engine integration lands, resolving Boundary 3.

## 5. Open items

| # | Item | Boundary | Owner |
| - | ---- | -------- | ----- |
| 1 | Define and implement checksum verification for the Godot .NET AAR | 3 | Engine integration PR |
| 2 | Decide whether to pin actions to commit SHAs before first signed release | 1 | Release readiness |
| 3 | Define the Kotlin ↔ engine bridge surface and its validation | 4 | Engine integration PR |
| 4 | Configure Android backup rules for save data | 5 | Save system PR |
