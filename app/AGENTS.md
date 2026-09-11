# Android host instructions

Scope: `app/` — the Kotlin host and its Android resources. The root `AGENTS.md`
still applies; this file adds only what is specific to the host module.

## The host is thin, and that is the whole design

ADR 0002 gives Godot ownership of everything the player sees, including menus,
HUD and settings. The host exists to start the engine, feed it platform facts,
and get out of the way.

**In scope for this module:** activity and lifecycle management, input device
detection, in-app purchase, storage and platform I/O, permissions.

**Out of scope, permanently:** drawing game UI. No Compose, no layouts, no view
hierarchy for anything the player interacts with during play. A pull request that
adds a UI toolkit here is changing an architectural decision and needs a
superseding ADR, not a review comment.

## Engine constraints that are handled structurally

Two limits are documented by the engine itself, and both are met by construction
rather than by defensive code. Neither may be weakened:

- **One engine instance per process.** There is exactly one hosting Activity.
- **Resize and orientation configuration events are unsupported and may crash.**
  The manifest declares `android:configChanges` covering those events so Android
  hands them to the Activity instead of recreating it under a live engine.
  Narrowing that attribute reintroduces a crash the engine documents.

Adaptive phone and tablet layout is therefore expressed inside the engine, using
its anchor and container system, never by letting Android recreate the Activity.

## The bridge

`host/HostBridge.kt` is the **entire** host-to-engine surface, and it stays that
way. Everything the engine can reach is declared in that one class: methods
annotated `@UsedByGodot`, signals listed in `getPluginSignals()`.

- Validate every value crossing the boundary. GDScript has no static analysis
  (ADR 0002), so the host treats engine-side input as untrusted.
- Return values from closed sets where possible, so the engine cannot receive a
  state it has no branch for.
- Never expose file system, storage, credential, entitlement or `Intent`
  dispatch capability through the bridge.
- Adding a member here is a security-relevant change: revisit
  `docs/architecture/THREAT_MODEL.md` in the same pull request.

## Build configuration

- Every SDK, NDK, ABI and Java value comes from
  `config/android/toolchain.properties`, read through Gradle's provider API so
  the file is tracked as a configuration input. Never write such a literal into
  `build.gradle.kts`; CI fails if you do.
- `versionCode` and `versionName` derive from `VERSION`. Do not set either by
  hand.
- `app/src/main/assets/game.pck` is a build output produced in CI, never
  committed. The build fails early if it is missing.
- No signing configuration belongs in this module. Signing material is injected
  at release time from protected secrets.

## Testing

Host logic is written so its rules are expressible over plain data — see
`InputDeviceSnapshot` — and are therefore unit testable on the JVM with no
framework stubbing. `testOptions.unitTests.isReturnDefaultValues` is off
deliberately: if you find yourself wanting it on, the logic has drifted into the
framework and should be pulled back out instead.

## Resources

- Player-facing text is **not** an Android resource. The engine renders and
  localizes everything the player sees (ADR 0002), so translations live in the
  game data. `res/values/strings.xml` holds only the launcher label.
- If a genuinely host-level, user-visible string is ever added, it ships in
  English, Italian, Spanish, French and German in the same change. A locale that
  silently falls back to English is a defect.
- `res/xml/locale_config.xml` is hand-written and declares the five supported
  languages to the system. It is not generated from `values-*` directories,
  because there are none; keep it in step with the locales the game data
  provides.
- Prefer vector resources. Raster assets add bytes per density bucket and carry
  provenance questions that a reviewable XML path does not.
- Permissions: the application declares none. Adding one requires a justification
  in review and in the release readiness gates.
