# ADR 0003: Android toolchain baseline

- **Status:** Accepted
- **Date:** 2026-09-10

## Context

DungeonLike needs a defensible Android baseline: which API levels it compiles
against and supports, which ABIs it ships, and which JDK it builds with. The
project brief specified API 34 minimum, API 37 compile/target, build tools
`37.0.0`, and 64-bit devices only.

API 37 is recent enough that its availability could not be taken on trust, so
every value below was checked against a primary source before being adopted.
`AGENTS.md` forbids speculation about dependency versions, and a toolchain
declaration is the worst possible place for a guess: it fails late, in CI, with
an opaque error.

### Evidence

Google's SDK repository index (`repository2-3.xml`) lists on the **stable**
channel:

| Package | Availability |
| ------- | ------------ |
| `platforms;android-37.0`, `37.1`, `37.2` | stable; `37.2` carries SDK extension level 24 |
| `build-tools;37.0.0` | stable, and the only 37.x build-tools release |
| `ndk;29.0.14206865` | stable |
| `cmake;4.1.2` | stable |

Further:

- **AGP 9.4.0** is stable on Google Maven, and its release notes state the
  maximum supported API level is 37.
- **JDK 17 is the floor**, established independently twice: the AGP 9.4.0 artifact
  is compiled to Java 17 bytecode (class file major version 61), and Godot 4.7.2's
  Android library declares `JavaVersion.VERSION_17`.
- **Minor SDK versions are now real.** From API 36.1 onward an API level is a
  `major.minor` pair, and the SDK package id is `platforms;android-<major>.<minor>`.
  Tooling that assumes a bare integer will request a package that does not exist.
- **Godot 4.7.2 builds its Android library at `compileSdk`/`targetSdk` 36** with
  `minSdk 24` (ADR 0002).

## Decision

The Android toolchain is declared once, in
`config/android/toolchain.properties`, and read from there by every consumer.

| Setting | Value | Rationale |
| ------- | ----- | --------- |
| `minSdk` | 34 | Product requirement. Removes a large volume of legacy compatibility branching. |
| `compileSdk` | 37, minor 2 | Highest stable minor; gives access to the newest APIs. |
| `targetSdk` | 37, minor 2 | Matches `compileSdk`, so no behaviour change is silently deferred. |
| SDK extension | 24 | The level shipped by `platforms;android-37.2`. |
| Build tools | `37.0.0` | Only stable 37.x release. |
| NDK | `29.0.14206865` | Deliberately matched to Godot's NDK. |
| CMake | `4.1.2` | Current stable. |
| ABI | `arm64-v8a` only | 64-bit requirement; also keeps download size down. |
| Java | 17 | Verified floor for both AGP 9.4.0 and Godot 4.7.2. |

Two rules make this durable:

1. **No consumer restates a value owned here.** Workflows and build scripts read
   the properties file. `scripts/validate_toolchain.py` fails CI if a workflow
   hardcodes a value the file owns, and cross-checks that
   `gradle/libs.versions.toml` agrees on the AGP and Kotlin versions.
2. **Product invariants are asserted, not merely documented.** The same script
   fails if `minSdk` moves off 34, if the ABI list is not exactly `arm64-v8a`, or
   if `compileSdk` drops below `targetSdk`.

The NDK is pinned to the engine's revision rather than the newest available.
Mixing NDK revisions between the engine and the application is a known source of
subtle STL and linker mismatches, which surface as runtime crashes rather than
build failures. Coupling is the cheaper failure mode.

## Consequences

**Positive.** A toolchain bump is a one-line, reviewable change with CI-enforced
consistency. The 64-bit-only, single-ABI build keeps the premium app's download
size small. Compiling and targeting the same level means platform behaviour
changes are confronted deliberately.

**Negative.** `minSdk 34` excludes every device below Android 14, which is a
deliberate reduction of the addressable market. Targeting the newest platform
means opt-in behaviour changes must be handled as they arrive rather than
deferred. Pinning the NDK to Godot's revision means the engine, not the platform,
paces native toolchain updates.

**Negative — asymmetry to monitor.** The app targets API 37 while the engine's
library targets 36. This is supported, but it is not free: engine-level platform
behaviour may lag, and the combination must be re-validated at every engine and
platform bump.

**Neutral.** Shipping a single ABI means no x86_64 slice, so a release artifact
cannot run on a standard emulator image. Instrumentation testing must use ARM64
emulator images or physical devices, which affects CI runner selection when
device tests are introduced.

**Revisit when** a newer stable minor of API 37 or an API 38 platform ships, when
Godot moves to a newer NDK or raises its own target SDK, or if a 32-bit or
emulator ABI is ever needed for testing.
