# Threat model

DungeonLike is an offline, single-player Android game distributed through Google
Play as a one-time purchase. It has no server, no account, no network protocol
and no user-generated content. That makes the threat model unusually small, and
writing it down is mostly a matter of being explicit about what is **not**
defended, so that a future change does not quietly assume protection that was
never there.

This document is a documented security gate: a change that alters a boundary
described here updates it in the same pull request.

## What the product handles

| Asset | Where it lives | Why it matters |
| --- | --- | --- |
| Save data | Application-private storage | The player's progress |
| Player settings | Application-private storage | Convenience only |
| Run seeds | In the save, and shown on screen | Fairness and reproducibility |
| Save-integrity key | Android Keystore, never exported | Detects an altered save |
| Purchase entitlement | Google Play | The product is paid for |
| Achievement progress | Local, and Play Games when wired | Player-visible progress |

Nothing personal is collected. There is no analytics, no crash reporter and no
advertising identifier, so there is no personal data to lose.

## Who is not an adversary

**The device owner.** This is the central decision. On a single-player offline
game, the player can already read and modify anything on their own device, and
treating them as an attacker would mean spending effort on measures they can
always defeat while making the application more hostile to the people who paid
for it. Modifying your own save is not an attack; it is a decision about your own
game.

Consequences that follow, deliberately:

* Save data is authenticated, not encrypted. The point is to **detect** a save
  the game did not write, so that a corrupted or edited file is reported rather
  than loaded as though it were valid — which is what otherwise turns into an
  unreproducible bug report.
* Run seeds are displayed on purpose, which means a player can look one up or
  replay it. That is a feature.
* There is no root detection, no emulator detection and no integrity attestation
  of the running process.

## Boundaries

### 1. The JNI bridge

The only path between the Kotlin host and the game core is `HostPlugin`. It is
reachable from GDScript by name, so every method treats its arguments as
untrusted: `hostEntropy` bounds the requested length rather than allocating what
it is asked for, and the achievement calls swallow failures rather than throwing
across the engine boundary, where an exception would take the process down.

The bridge exposes no file paths, no arbitrary reflection and no way to launch
an intent. Adding a method that did any of those would change this boundary and
requires updating this document.

### 2. The game pack

`game.pck` ships inside the signed application package. Its integrity comes from
Play's signing of the package as a whole; the game performs no separate
verification, because a pack an attacker could replace implies a package they
could already modify, which is a defeated boundary at a lower level.

The pack is not encrypted. Encrypting it would put the key in the binary next to
it, which protects against nothing and costs start-up time.

### 3. Local storage

Saves and settings are in application-private storage, which the platform keeps
other applications out of. Saves carry an HMAC-SHA256 tag produced with a key
generated in the Android Keystore and never exported, so a save copied from
another device fails its check. The tag comparison is constant-time, because a
comparison that returns early leaks how much of a forged tag was correct.

Settings are not authenticated. There is nothing in them worth forging.

Cloud backup and device transfer are disabled for the application's data. A
restored save could not pass an integrity check made with a key bound to the
original device, so allowing backup would mean honest players being told their
save was tampered with after changing phones.

### 4. Google Play

Purchase entitlement is enforced by Play, not by the application; there is no
licence check in the binary. Play Games Services, when wired, will be the only
component that needs network access, and the `INTERNET` permission belongs to
that integration alone — never to the base application.

Achievements are reported optimistically and are never a precondition for play,
so a failure to reach Play cannot block an offline session.

### 5. The supply chain

The largest realistic risk to this project is not an attack on the running game
but a change reaching a build unreviewed.

* Every workflow declares least-privilege `permissions`; the default is
  `contents: read`.
* Every third-party action is pinned to a full commit SHA, with the version in a
  trailing comment. A tag or a branch can be repointed at different code by
  whoever controls that repository, so an action referenced as `owner/action@v1`
  runs whatever that tag names at the moment the workflow starts — with access to
  the workflow's token and its runner. A commit SHA cannot move.
  `tools/scripts/check_action_pinning.py` enforces this on every pull request,
  so a new workflow cannot quietly reintroduce a mutable reference.
  Actions published by GitHub itself are exempt because their releases are
  immutable; that exemption is a trust decision and is listed explicitly in the
  checker rather than inferred.
* Dependencies are pinned in one version catalogue, and one toolchain file pins
  the SDK, build tools and engine version.
* The Godot editor and its export templates are downloaded in CI and verified
  against the checksums published with the release before anything is unpacked.
* The Gradle wrapper jar is validated against Gradle's published checksums on
  every run once it is committed.
* Dependabot may merge unattended only patch and minor updates to tooling that
  cannot reach the installed application; anything touching the engine, the
  Android Gradle plugin or Play services is reviewed by a person.
* `pull_request_target` is used in exactly two workflows, neither of which
  checks out or executes repository code from the pull request.
* No credential, signing key or keystore is committed, logged or placed in an
  artifact. Release signing material lives only in a protected environment.

## Explicit non-goals

* Anti-cheat and anti-tamper of any kind.
* Protecting game content from extraction.
* Defending against an attacker with physical access to an unlocked device.
* Defending against a compromised operating system or a rooted device.

## Review triggers

Update this document in the same pull request that:

* adds a method to `HostPlugin`, or any other path between host and game;
* adds a permission to the manifest;
* adds a network call, an SDK that makes one, or any form of telemetry;
* changes how saves are written, authenticated or backed up;
* changes workflow permissions, or what Dependabot may merge unattended;
* introduces user-generated or downloadable content.
