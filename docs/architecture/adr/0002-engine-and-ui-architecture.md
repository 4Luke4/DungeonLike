# ADR 0002: Engine and UI architecture

- **Status:** Accepted
- **Date:** 2026-09-10

## Context

DungeonLike must ship a visually polished roguelike on Android phones and tablets,
with adaptive layouts, five locales, and full mouse and keyboard support. The
project brief proposed Godot with C# for the game core and Kotlin for the UI.

Splitting the UI across two runtimes is the part that needs justification, so the
capabilities and limits of embedding Godot in an Android app were checked against
primary sources rather than assumed.

### Evidence

1. **Embedding is officially supported.** Godot is designed to be consumed as an
   Android library, and Godot 4.7.2-stable publishes
   `godot-lib.4.7.2.stable.mono.template_release.aar` — a .NET/C# build. A Kotlin
   host driving an embedded C# Godot instance is therefore a real, supported
   configuration, not a workaround.

2. **Two hard runtime limits.** Godot's Android library documentation states that
   only one engine instance is supported per process, and that automatic resizing
   and orientation configuration events are **not supported and may cause a
   crash**. The documented mitigation is to lock orientation or to declare
   `android:configChanges` so the activity handles those events itself.

3. **The .NET library is not on MavenCentral.** MavenCentral publishes
   `org.godotengine:godot` and `org.godotengine:godot-debug` through
   `4.7.2.stable`, but no `mono` variant. The C# AAR exists only as a GitHub
   release asset and cannot be resolved as an ordinary Maven coordinate.

4. **SDK level asymmetry.** Godot 4.7.2 builds its Android library against
   `compileSdk 36` / `targetSdk 36` with `minSdk 24`. DungeonLike compiles and
   targets API 37 with `minSdk 34`. This is compatible: the Android Gradle plugin
   rejects a dependency compiled against a *higher* SDK than the consumer, not a
   lower one, and our higher `minSdk` is a strict subset of the library's support.

Point 2 is decisive. A rich native Kotlin UI layered over a live Godot surface is
precisely the design that provokes resize events — window size class changes,
tablet rotation, multi-window, and foldable posture changes are the mechanism by
which adaptive layouts work.

## Decision

**Godot owns all rendering. Kotlin is a thin host.**

- **Godot / C#** renders everything the player sees, including menus, HUD, and
  settings, and holds all gameplay logic. Adaptive phone and tablet layout is
  expressed with Godot's own anchor and container system, which resizes within a
  single engine instance and does not depend on Android configuration changes.
- **Kotlin** is limited to the Android host: activity and lifecycle management,
  in-app purchase, storage and platform I/O, permissions, and input device
  detection. It does not draw game UI.
- The hosting activity declares `android:configChanges` for size and orientation
  events so that Android does not recreate it underneath the engine, per the
  documented mitigation. A single engine instance is created for the process.
- Input mode (touch, mouse, physical keyboard) is detected on the Android side
  and forwarded to the engine, which owns the resulting interaction model.

### Alternatives considered

**Hybrid — Compose for menus, Godot for gameplay.** Closest to the original brief
and the most attractive on paper: native menus tend to feel better and are easier
to make accessible. Rejected because it maximises exposure to the two documented
limits. Navigating between a Compose menu and a Godot surface invites either a
second engine instance or repeated teardown, and the transitions are exactly when
resize events fire.

**Drop Godot; pure Kotlin and Compose.** Removes every constraint above and gives
first-class adaptive layout and accessibility. Rejected because it discards the
engine's rendering, animation, scene, and asset pipeline, which a polished
real-time roguelike would then have to reimplement.

**Godot without C#, using GDScript.** Sidesteps the unpublished mono AAR entirely.
Rejected because the brief calls for C#, and a statically typed language with a
mature test ecosystem is a better fit for rules-heavy simulation.

## Consequences

**Positive.** One rendering runtime, so there is no seam to keep visually
consistent. The documented single-instance and resize limits are avoided by
construction rather than mitigated case by case. Layout adapts within the engine,
so phone and tablet behaviour is expressed once.

**Negative.** Accessibility is the real cost: Android's accessibility services see
a Godot surface, not a native view tree, so screen-reader support, focus order,
and text scaling must be built deliberately inside the engine rather than
inherited from the platform. This is tracked as a release gate in
`docs/release/READINESS.md`.

Kotlin developers cannot contribute UI work, which narrows the contributor pool.

**Negative — supply chain.** Because the .NET AAR is not on MavenCentral, it must
be obtained as a verified GitHub release asset or built from source. Either way it
becomes a binary dependency with no dependency-manager provenance, and Dependabot
cannot track it. Checksum verification and a documented update procedure are
required; the risk is recorded in `docs/architecture/THREAT_MODEL.md`.

**Neutral.** The engine targets API 36 while the app targets 37. This is
supported today, but it must be re-checked at every engine upgrade and every
Android platform bump, and it means engine-level behaviour changes may lag the
platform.

**Revisit if** Godot gains support for multiple engine instances or for resize
events, or publishes the .NET Android library to MavenCentral. Any of those
materially changes the trade-off and should prompt a superseding ADR.
