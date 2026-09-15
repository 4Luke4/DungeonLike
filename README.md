# DungeonLike

DungeonLike is an original, offline, single-player roguelike for Android phones
and tablets. Every run generates its own dungeon, encounters and loot, and is
resolved through turn-based combat built on the rules vocabulary of the System
Reference Document 5.2.1.

> **Status:** pre-release scaffolding. The build, toolchain, host, engine
> integration and continuous integration are in place; gameplay systems are not
> implemented yet. See [`CHANGELOG.md`](CHANGELOG.md) and
> [`docs/release/READINESS.md`](docs/release/READINESS.md).

## Platform envelope

| Property | Value |
| --- | --- |
| Application id | `com.yuumi.dungeonlike` |
| Minimum Android version | 14 (API 34) |
| Compile and target platform | API 37.2, SDK extension 24 |
| Supported ABI | `arm64-v8a` only (64-bit ARM phones and tablets) |
| Distribution | Google Play, one-time purchase |
| Connectivity | Offline, single-player |
| Languages | English (default), Italian, Spanish, French, German |

Exact toolchain versions are declared once, in
[`config/android/toolchain.properties`](config/android/toolchain.properties) and
[`gradle/libs.versions.toml`](gradle/libs.versions.toml). Nothing else in the
repository is allowed to restate them.

## Architecture at a glance

```
┌──────────────────────────────────────────────────────────┐
│ :app  — Kotlin Android host (com.yuumi.dungeonlike)      │
│   GameActivity : GodotHost      hosts GodotFragment      │
│   HostPlugin   : GodotPlugin    the one bridge surface   │
│     · platform entropy (SecureRandom)                    │
│     · display refresh rates                              │
│     · keyboard / mouse / touch device detection          │
│     · achievement gateway                                │
│     · Keystore-backed save integrity                     │
└───────────────┬──────────────────────────────────────────┘
                │ JNI · @UsedByGodot methods and signals
┌───────────────▼──────────────────────────────────────────┐
│ game/ — Godot 4 project (GDScript), shipped as game.pck  │
│   all game logic, all UI, all content                    │
└──────────────────────────────────────────────────────────┘

:host-core — pure JVM Kotlin shared by the host and its unit tests
```

The split, and the rule for deciding what belongs on which side, is documented
in [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md).

## Randomness

Every run draws a 32-byte seed from real platform entropy, then expands it
through a standards-based deterministic random bit generator with independent
streams per system. Runs are therefore unpredictable but exactly reproducible
from their seed, which makes bug reports and automated tests possible. See
[`docs/rng/RNG_DESIGN.md`](docs/rng/RNG_DESIGN.md).

## Building and verifying

Everything executable runs in GitHub Actions. Local work is limited to editing
and read-only inspection — see the verification policy in
[`CONTRIBUTING.md`](CONTRIBUTING.md) and `CLAUDE.md`.

| Workflow | What it proves |
| --- | --- |
| `CI / meta` | `VERSION`, changelog, locales and random-number usage are consistent |
| `CI / gradle` | Kotlin host and `:host-core` compile, unit tests and Android Lint pass |
| `CI / godot` | GDScript lints, formats and passes its GUT test suite |
| `CI / bundle` | The Godot pack exports and an unsigned debug bundle builds end to end |
| `Lint`, `CodeQL`, `Commit messages` | Repository-wide static analysis and commit hygiene |

## Documentation

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — workflow, commit format, review rules
- [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md)
- [`docs/architecture/THREAT_MODEL.md`](docs/architecture/THREAT_MODEL.md)
- [`docs/rng/RNG_DESIGN.md`](docs/rng/RNG_DESIGN.md)
- [`docs/i18n/LOCALIZATION.md`](docs/i18n/LOCALIZATION.md)
- [`docs/release/READINESS.md`](docs/release/READINESS.md)
- [`SECURITY.md`](SECURITY.md) — vulnerability reporting

## Licence

DungeonLike is proprietary; see [`LICENSE.md`](LICENSE.md). Third-party
components keep their own licences and their required attributions are recorded
in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
