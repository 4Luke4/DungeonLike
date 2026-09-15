# Architecture

DungeonLike is one Android application containing two codebases: a thin Kotlin
host and a Godot game core written in GDScript. This document records where the
line between them runs, why it runs there, and which dependencies the project
has deliberately chosen not to take.

## Shape

```
┌──────────────────────────────────────────────────────────────┐
│ :app — Kotlin                                                │
│                                                              │
│  GameActivity : AppCompatActivity, GodotHost                 │
│    hosts a GodotFragment · one engine instance per process   │
│    getCommandLine() → --main-pack res://game.pck             │
│    getHostPlugins() → HostPlugin                             │
│                                                              │
│  HostPlugin : GodotPlugin       ← the entire bridge          │
│    hostEntropy · displayRefreshRateHz · supportedRefreshRates│
│    hasPhysicalKeyboard · hasPointerDevice · hasGameController│
│    achievementsAvailable · unlockAchievement · increment…    │
│    signal input_devices_changed                              │
│                                                              │
│  HostEntropySource · RefreshRateProvider · InputDeviceWatcher│
│  AchievementGateway · SaveIntegrity                          │
└───────────────────────────┬──────────────────────────────────┘
                            │ JNI
┌───────────────────────────▼──────────────────────────────────┐
│ game/ — GDScript, shipped as game.pck                        │
│                                                              │
│  HostBridge  the only caller of Engine.get_singleton()       │
│  RngService  all randomness                                  │
│  FramePacingService · InputModeService                       │
│  LocaleService · SettingsService                             │
│                                                              │
│  scenes: boot → main_menu → run_shell · credits              │
└──────────────────────────────────────────────────────────────┘

:host-core — Kotlin with no Android API usage, unit-tested in CI
```

## Where the line runs

**The host owns platform capability.** Entropy, display modes, input hardware,
Play integration, keystore operations, the activity, the manifest and the
handful of strings that must exist before the engine runs.

**The game owns everything else.** All rules, all content, all interface, all
player-facing text.

The test for a new piece of work is whether it needs an Android API. If it does
not, it belongs in GDScript, even when Kotlin would be more familiar to write.

The reason is not taste. The game core ships as a pack the host loads, and the
two are built by different toolchains with different test stories: the Kotlin
side is compiled and unit-tested by Gradle, the GDScript side is linted and
tested by the engine. Logic that drifts into the host becomes logic that the
game's own test suite cannot reach.

## The bridge

`HostPlugin` is the only surface between the two, and `HostBridge` is the only
thing that talks to it. Both constraints exist so that the boundary can be read
in one sitting.

Three rules come from the engine rather than from preference:

* A method reachable from GDScript is annotated `@UsedByGodot`, and the engine
  matches the name **exactly** — there is no `snake_case` conversion, so the
  GDScript call spells the Kotlin name.
* Bridge calls run on the engine's thread. They must be cheap and must not
  block; anything the platform pushes asynchronously is delivered as a signal.
* Only primitives cross: `Int`, `Long`, `Float`, `Boolean`, `String`,
  `ByteArray` (arriving as `PackedByteArray`), `IntArray` (as
  `PackedInt32Array`) and `Array<String>` (as `PackedStringArray`).

`HostBridge` degrades every call when the plugin is absent. That is what keeps
the project runnable in the editor on a desktop machine, where there is no
Android host at all — without it, the only way to run the game would be to
deploy it.

## Engine lifecycle

Three constraints are load-bearing and come from the Godot Android library's
documentation:

1. **One engine instance per process.** `GameActivity` is the only place an
   engine is created, and it reuses the restored fragment rather than committing
   a second one.
2. **No automatic resize or orientation events.** An embedded instance can crash
   on them, so the activity declares a fixed `android:screenOrientation` and a
   `configChanges` set wide enough that the activity is not recreated. The
   manifest value and the engine's `display/window/handheld/orientation` must
   agree; today both mean sensor landscape.
3. **The pack is passed on the command line.** The game is exported to
   `game.pck` and loaded with `--main-pack`, rather than shipping the raw
   project inside `assets/`.

## Build

```
config/android/toolchain.properties   SDK, build tools, ABI, Java, engine version
gradle/libs.versions.toml             library and plugin versions
VERSION                               application version → versionName, versionCode
```

The root build script reads the first two, cross-checks them, and fails if they
disagree. No module restates a value from them.

AGP 9 compiles Kotlin itself, so the Kotlin Gradle plugin is not applied
anywhere — it is in fact incompatible with the AGP 9 DSL. `:host-core` is an
Android library module rather than a plain JVM one for the same reason: one
Kotlin compiler for the whole build, and no plugin compatibility matrix to
track.

## Deliberate non-dependencies

**No Play Billing library.** The application is a one-time purchase. Play itself
enforces the entitlement for a paid application; a billing integration would add
a dependency, a permission surface and a failure mode to support a purchase flow
the product does not have.

**No network stack, and no `INTERNET` permission in the base manifest.** The
game is offline and single-player. The permission belongs to the Play Games
integration alone, when that is wired.

**No Play Games Services dependency yet.** It is declared in the version catalog
but not depended on: unlocking a real achievement needs a Play Console games
project and a `game_ids` resource that do not exist. The game calls an
`AchievementGateway` interface whose only implementation today is a no-op, so
adding the backend later changes one binding and no call sites.

**No analytics, no crash reporter, no advertising identifier.** Nothing in the
product needs them, and each would turn an application that collects nothing
into one with a privacy policy to maintain.

## Related documents

* [Threat model](THREAT_MODEL.md)
* [Random number design](../rng/RNG_DESIGN.md)
* [Localisation](../i18n/LOCALIZATION.md)
* [Release readiness](../release/READINESS.md)
