# ADR 0002: Engine and UI architecture

- **Status:** Accepted
- **Date:** 2026-09-10

## Context

DungeonLike must ship a visually polished roguelike on Android phones and tablets,
with adaptive layouts, five locales, and full mouse and keyboard support.

Splitting the UI across two runtimes, and choosing a scripting language for the
game core, are both decisions that are expensive to reverse, so the capabilities
and limits of embedding Godot in an Android app were checked against primary
sources rather than assumed.

### Evidence

1. **Embedding is officially supported.** Godot is designed to be consumed as an
   Android library. The standard (non-.NET) build is published to MavenCentral as
   `org.godotengine:godot`, with versions through `4.7.2.stable`. A Kotlin host
   driving an embedded Godot instance is a real, supported configuration.

2. **Two hard runtime limits.** Godot's Android library documentation states that
   only one engine instance is supported per process, and that automatic resizing
   and orientation configuration events are **not supported and may cause a
   crash**. The documented mitigation is to lock orientation or to declare
   `android:configChanges` so the activity handles those events itself.

3. **Distribution differs sharply between the two builds.** The standard engine is
   a signed MavenCentral artifact: `godot-4.7.2.stable.aar` ships alongside a GPG
   signature (`.asc`) and SHA-256/SHA-512 checksums, and resolves as an ordinary
   Gradle dependency. The .NET/C# build is **not published to MavenCentral** at
   all — it exists only as a GitHub release asset
   (`godot-lib.<version>.stable.mono.template_release.aar`).

4. **SDK level asymmetry.** Godot 4.7.2 builds its Android library against
   `compileSdk 36` / `targetSdk 36` with `minSdk 24`. DungeonLike compiles and
   targets API 37 with `minSdk 34`. This is compatible: the Android Gradle plugin
   rejects a dependency compiled against a *higher* SDK than the consumer, not a
   lower one, and our higher `minSdk` is a strict subset of the library's support.

Point 2 is decisive for the UI split. A rich native Kotlin UI layered over a live
Godot surface is precisely the design that provokes resize events — window size
class changes, tablet rotation, multi-window, and foldable posture changes are the
mechanism by which adaptive layouts work.

Point 3 is decisive for the language choice. Choosing C# means adopting a binary
with no package-manager provenance, which no resolver verifies and which
Dependabot cannot track, directly inside the shipped application.

## Decision

**Godot owns all rendering. Kotlin is a thin host. The game core is GDScript on
the standard (non-.NET) engine.**

- **Godot / GDScript** renders everything the player sees, including menus, HUD,
  and settings, and holds all gameplay logic. Adaptive phone and tablet layout is
  expressed with Godot's own anchor and container system, which resizes within a
  single engine instance and does not depend on Android configuration changes.
- **Kotlin** is limited to the Android host: activity and lifecycle management,
  in-app purchase, storage and platform I/O, permissions, and input device
  detection. It does not draw game UI.
- The engine is consumed as the **standard MavenCentral artifact**
  `org.godotengine:godot`, verified by checksum and signature.
- The hosting activity declares `android:configChanges` for size and orientation
  events so that Android does not recreate it underneath the engine, per the
  documented mitigation. A single engine instance is created for the process.
- Input mode (touch, mouse, physical keyboard) is detected on the Android side
  and forwarded to the engine, which owns the resulting interaction model.

### Alternatives considered

**Godot with C#/.NET.** Statically typed, with a mature test ecosystem, and the
only option here that CodeQL can analyse. Rejected because the .NET Android
library is not distributed through any package manager: it would enter the
application as an unverified binary blob that Dependabot cannot see. Trading a
verified, signed, resolver-managed dependency for a manually vendored one is a
poor bargain, and a supply chain is the harder problem to repair later. GDScript
is also the engine's first-class language, so it carries less integration risk.

**Hybrid — Compose for menus, Godot for gameplay.** The most attractive on paper:
native menus tend to feel better and are easier to make accessible. Rejected
because it maximises exposure to the two documented limits. Navigating between a
Compose menu and a Godot surface invites either a second engine instance or
repeated teardown, and the transitions are exactly when resize events fire.

**Drop Godot; pure Kotlin and Compose.** Removes every constraint above and gives
first-class adaptive layout and accessibility. Rejected because it discards the
engine's rendering, animation, scene, and asset pipeline, which a polished
real-time roguelike would then have to reimplement.

## Consequences

**Positive.** One rendering runtime, so there is no seam to keep visually
consistent. The documented single-instance and resize limits are avoided by
construction rather than mitigated case by case. Layout adapts within the engine,
so phone and tablet behaviour is expressed once.

**Positive — supply chain.** The standard engine resolves from MavenCentral as a
signed, checksummed Gradle dependency. This removes what would otherwise have been
the project's largest supply-chain risk, and keeps the engine visible to
Dependabot. The application also ships without a .NET runtime, which reduces both
download size and native surface area.

**Negative — static analysis coverage.** GDScript is supported by **neither
CodeQL nor super-linter**, whereas C# is supported by both. The game core will
therefore have no automated security or lint coverage from the tooling already in
place. This is a real and deliberate cost of this decision. It is mitigated by
adopting `gdtoolkit` (`gdlint`, `gdformat`) as a dedicated linting and formatting
step, and by relying on Godot's own test tooling, when the game core lands. The
Kotlin host remains covered by CodeQL's `java-kotlin` analysis.

**Negative — language ergonomics.** GDScript is dynamically typed, so a class of
error that a C# compiler would reject must instead be caught by static type hints,
tests, and review. Rules-heavy simulation code is exactly where this hurts most,
so typed declarations should be used consistently rather than optionally.

**Negative — accessibility.** Android's accessibility services see a Godot
surface, not a native view tree, so screen-reader support, focus order, and text
scaling must be built deliberately inside the engine rather than inherited from
the platform. This is tracked as a release gate in `docs/release/READINESS.md`.

Kotlin developers cannot contribute UI work, which narrows the contributor pool.

**Neutral.** The engine targets API 36 while the app targets 37. This is
supported today, but it must be re-checked at every engine upgrade and every
Android platform bump, and it means engine-level behaviour changes may lag the
platform.

**Revisit if** Godot gains support for multiple engine instances or for resize
events, or publishes the .NET Android library to MavenCentral with equivalent
signing. Any of those materially changes the trade-off and should prompt a
superseding ADR.
