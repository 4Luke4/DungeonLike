# Android host instructions

These rules apply to `app/` and `host-core/`. They complement the repository
root `CLAUDE.md`; nothing here repeats it.

## The host owns platform capability, and nothing else

The Kotlin host exists to reach Android APIs that GDScript cannot. It is not a
place for game logic, content, or UI.

Belongs in `app/`:

- platform entropy (`java.security.SecureRandom`);
- display capability (supported modes, refresh rates);
- input-device detection (physical keyboard, pointer, game controller);
- Google Play integration (achievements today, entitlement checks later);
- Android Keystore operations for tamper-evident saves;
- the Android activity, manifest, permissions and resources.

Belongs in `game/` instead: dungeon generation, combat, items, progression,
every screen the player sees, and every string the player reads except the
launcher label and the few pre-engine error strings in `res/values*/`.

If a change would put a rule, a number that affects play, or a piece of content
into Kotlin, it is in the wrong module.

## The bridge is one class

`bridge/HostPlugin.kt` is the **only** surface exposed to GDScript. Adding a
capability means adding a method there and documenting it, not opening a second
channel.

- A method callable from GDScript must carry `@UsedByGodot`. The name is matched
  exactly — Godot performs no `snake_case` to `camelCase` coercion — so the
  GDScript call site and the Kotlin method name must be spelled identically.
- Signals are declared in `getPluginSignals()` and emitted with `emitSignal()`.
  Use a signal for anything the platform pushes (device attached, display mode
  changed); use a method for anything the game pulls.
- Keep every bridge method cheap and non-blocking. The engine's main thread
  calls into it; long work must be dispatched and answered with a signal.
- Bridge parameters and return values stay primitive (`Int`, `Long`, `Float`,
  `Boolean`, `String`, `IntArray`, `Array<String>`). Do not push Android types
  across the boundary.

## Engine lifecycle constraints

These are load-bearing and were taken from the Godot Android library
documentation, not from preference:

- Only **one** Godot instance may exist per process.
- Automatic resize and orientation configuration changes can crash an embedded
  instance. `GameActivity` therefore declares both `android:screenOrientation`
  and `android:configChanges` in the manifest, and the Godot project's
  `display/window/handheld/orientation` must agree with the manifest value.
  Changing one without the other is a defect.
- The game pack is loaded through `GodotHost.getCommandLine()` with
  `--main-pack`. The `aaptOptions.ignoreAssetsPattern` override in
  `app/build.gradle.kts` is required for Godot's asset layout; removing it
  breaks the packaged game silently.

## Testability

Anything that can run without a device belongs in `:host-core`, which has no
Android dependencies and is unit-tested by CI on every pull request.
`app/src/test` covers host classes that only need the JVM. Instrumentation tests
in `app/src/androidTest` are written but not run in CI — the application targets
`arm64-v8a` only and hosted runners offer no matching device.

## Permissions

The base manifest requests no permissions. A permission may only be added
together with the reason in `docs/architecture/THREAT_MODEL.md`. `INTERNET` in
particular belongs to the Play Games integration alone, never to the base
application.
