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

**Accepted risk.** GitHub-published actions (`actions/*`, `github/*`) are
referenced by major version tag. These are immutable releases from a first-party
publisher, and CodeQL's unpinned-action rule does not flag them.

**Resolved.** Third-party actions were previously referenced by mutable tag, on
the reasoning that tag references were the price of automatic Dependabot updates.
That reasoning was wrong: Dependabot updates SHA-pinned actions too, using the
trailing `# vX` version comment. CodeQL flagged all four occurrences, and every
third-party action is now pinned to a full commit SHA, so a retagged or
compromised upstream release cannot alter what CI executes. New third-party
actions must be added the same way.

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

### Boundary 3 — Engine binary acquisition *(live)*

The standard Godot Android library is published to MavenCentral as
`org.godotengine:godot`, alongside a GPG signature (`.asc`) and SHA-256/SHA-512
checksums (ADR 0002).

**Threat.** The engine is native code running inside the shipped application, so
substituting it would place attacker-controlled code directly in front of users.

**Why this is now a much smaller risk.** An earlier revision of this architecture
selected the .NET/C# engine build, which is **not** published to any package
manager and exists only as a GitHub release asset. That would have been the single
largest supply-chain risk in the project: a binary with no resolver verification
that Dependabot could not track. Choosing the standard engine replaces it with an
ordinary, signed, resolver-managed Gradle dependency.

**Controls.**

- The exact engine version is pinned in `config/android/toolchain.properties`,
  and `validate_toolchain.py` cross-checks it against the Gradle catalogue, so
  the engine cannot be swapped by editing one file.
- The engine is resolved from MavenCentral only; the AAR is not vendored.
  Repositories are content-filtered and `FAIL_ON_PROJECT_REPOS` is set, so no
  module can introduce a third source.
- Gradle dependency verification is enabled with `sha256` and `pgp`. Every
  resolved artifact's checksum and signature are checked on every build, and the
  build fails on mismatch.
- `gradle/verification-metadata.xml` is committed, so a change to what the build
  trusts appears in a diff and passes through review. The engine's own signing
  key is among the trusted keys, so `org.godotengine:godot:4.7.2.stable` is
  verified by signature, not merely by checksum.
- `gradle/verification-keyring.keys` is committed alongside it, pinning the
  trusted public key material itself. Without it every build would fetch keys
  from a public key server during resolution, which is both a network dependency
  and a reproducibility hole: an unreachable key server becomes a verification
  failure on a build that changed nothing.
- The Gradle wrapper jar is validated against Gradle's published checksums on
  every run, closing the adjacent "tampered wrapper" path.

**Accepted risk — partial signature coverage.** 18 of the signing keys in the
resolved dependency graph could not be retrieved from any key server, and Gradle
recorded them as ignored keys. Those artifacts are verified by **SHA-256
checksum only**, not by signature. This is a real limitation and is recorded
rather than papered over: a checksum pins exactly the bytes reviewed at
generation time, so substitution is still detected, but the chain back to a
publisher identity is missing for those entries. The engine itself is not among
them.

**Accepted risk.** Dependabot is deliberately not allowed to bump the engine: an
engine change alters shipped native code and must be a reviewed decision with the
documented Android library constraints re-validated (ADR 0002, ADR 0003).

**Status.** **Resolved** by the engine integration pull request. See ADR 0005.

### Boundary 3a — Engine tooling executed in CI *(live)*

The `engine-pack` job downloads the official Godot editor and runs it to export
the game pack that ships inside the application.

**Threat.** A substituted or corrupted editor download would produce a pack
containing attacker-chosen content, inside an otherwise perfectly verified build.

**Controls.** The archive is verified against the release's own `SHA512-SUMS.txt`
**before it is executed**, and the job fails if the asset is not listed in the
manifest. The engine binary is cached by version, so the verified artifact is
reused rather than re-fetched.

**Accepted risk.** That manifest is the publisher's own release asset and is not
independently signed, so it defends against corruption and substitution in
transit rather than against a compromise of the publisher. This is strictly
better than an unverified download, and is recorded in ADR 0005.

### Boundary 4 — Kotlin host to embedded engine *(live)*

The Kotlin host and the GDScript game core exchange data across the Godot bridge.

**Threats.** Malformed data crossing the boundary; an over-broad bridge surface
that exposes host capabilities to engine-side code; leaking entitlement state.

**Controls.**

- The bridge is one class, `app/src/main/kotlin/com/yuumi/dungeonlike/host/HostBridge.kt`,
  and it is the whole surface. Methods reachable from the engine are annotated
  `@UsedByGodot`; receivable signals are enumerated in `getPluginSignals()`.
  Reviewing the bridge means reading one file.
- The surface exposes no file-system, storage, credential, entitlement or
  `Intent` dispatch capability. It currently answers exactly one question —
  which input devices are attached — and returns a value from a closed set, so
  the engine cannot be handed a state it has no branch for.
- The engine side treats host values as untrusted in return: an unrecognised
  value is surfaced rather than displayed unchecked.
- Adding a member to the bridge is a security-relevant change and triggers a
  review of this document, as stated in `app/AGENTS.md`.

**Additional exposure from the language choice.** GDScript is analysed by neither
CodeQL nor super-linter, so the game core has no automated security coverage from
the existing tooling (ADR 0002). Because the engine side cannot be scanned, the
host must treat everything crossing this boundary as untrusted, and review of
engine-side code carries more weight than it otherwise would. `gdtoolkit`
(`gdlint`, `gdformat`) now runs in `ci.yml` as the partial mitigation that
ADR 0002 committed to.

**Status.** Surface defined and minimal. Re-review whenever it grows.

### Boundary 5 — Device and player data *(planned)*

Save data and settings live in app-private storage.

**Threats.** Save tampering to gain advantage; corruption causing progress loss;
data leaking through world-readable storage or backups.

**Planned controls.** App-private storage only. Treat all persisted data as
untrusted on read and validate it. Fail safe on corruption rather than crashing.

**Partial control in place.** `res/xml/data_extraction_rules.xml` excludes
application data from both cloud backup and device transfer. Until a save format
exists that can version and validate itself, restoring data written by another
build into a fresh install is precisely the corrupt-input case this boundary
requires to fail safe, so nothing is restored at all. Revisit when the save
system lands.

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
- **the host-to-engine bridge gains a member** — the surface is the control, so
  growing it is the change worth re-reading this document for;
- the engine version, or the tooling executed by the `engine-pack` job, changes.

## 5. Open items

| # | Item | Boundary | Owner |
| - | ---- | -------- | ----- |
| 1 | ~~Checksum verification for the Godot Android library~~ — **closed**: Gradle dependency verification (sha256 + pgp) with committed metadata | 3 | Engine integration PR |
| 2 | ~~Define the Kotlin ↔ engine bridge surface and its validation~~ — **closed**: `HostBridge` is the whole surface, enumerated and value-constrained | 4 | Engine integration PR |
| 3 | Save-data backup rules revisited once a versioned, self-validating save format exists (currently nothing is backed up or transferred) | 5 | Save system PR |
| 4 | Entitlement verification against the platform purchase mechanism | 6 | Billing PR |
| 5 | Release signing from protected secrets, in a workflow separate from pull request workflows | 7 | Release automation PR |
