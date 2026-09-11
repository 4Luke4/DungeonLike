# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

The current version is recorded in [`VERSION`](VERSION), which is the single
source of truth. `scripts/validate_version.py` fails CI if the two disagree.

## [Unreleased]

### Added

- Gradle build: `settings.gradle.kts`, root build script, `gradle.properties`,
  and a pinned wrapper. The Android toolchain and the application version are
  read from `config/android/toolchain.properties` and `VERSION` through Gradle's
  provider API, so both are tracked as configuration inputs and no build script
  restates an SDK, NDK, ABI, Java or version value.
- `:app` — the thin Kotlin host module. A single Activity hosts the embedded
  engine, declares the `configChanges` set Godot's documentation prescribes, and
  supplies the engine command line. Includes R8 keep rules for the engine's JNI
  surface, a hand-written locale config declaring all five supported languages,
  a vector adaptive launcher icon, and backup rules that restore nothing until a
  versioned save format exists.
- `HostBridge` — the complete, enumerated host-to-engine bridge. It reports the
  current input mode (touch, mouse, keyboard, or both) from a closed set of
  values and signals the engine when a peripheral is attached or removed
  mid-session. It exposes no file-system, credential or entitlement capability.
- `game/` — the Godot project and GDScript game core, exported to a single
  `game.pck` and loaded with `--main-pack`.
- JVM unit tests for the host's input-mode classification and engine
  command-line contract, written over plain data so they need no framework
  stubbing.
- `engine-pack` workflow job: downloads the official Godot editor, verifies it
  against the release SHA-512 manifest **before executing it**, and exports the
  game pack. The pack is a build output and is never committed.
- `bootstrap` workflow job: generates the Gradle wrapper and dependency
  verification metadata in CI, because both are Gradle outputs and the
  verification policy forbids producing them locally. It disables itself once
  they are committed, and remains the supported way to refresh the metadata.
- GDScript lint and format checks (`gdlint`, `gdformat --check`) with a
  hash-pinned toolchain — the coverage ADR 0002 committed to when it accepted
  that neither CodeQL nor super-linter can analyse the game core.
- Scoped `AGENTS.md` files for `.github/`, `scripts/`, `app/` and `game/`.
- ADR 0005, recording build structure, supply-chain verification, the engine
  pack pipeline, and why generated build inputs are bootstrapped through Actions.

### Changed

- `.vscode/extensions.json` reduced to syntax highlighting only, consistent with
  the policy that nothing is built or tested locally. Nine build, lint and
  workflow extensions were removed with the reasoning recorded in the file; the
  two that remain cover GDScript and Kotlin, which Visual Studio Code cannot
  colour on its own. Publisher verification status is stated per entry.
- `scripts/validate_toolchain.py` now also scans Gradle build scripts for
  restated toolchain values, and cross-checks the engine coordinate in the
  version catalogue against `godot.version`/`godot.channel`.
- CodeQL analyses `java-kotlin` in addition to `actions`; super-linter validates
  Kotlin.
- Dependabot manages the `gradle` ecosystem. The engine, AGP and Kotlin are
  excluded: changing any of them alters the shipped binary or the toolchain
  baseline and is a reviewed decision, not a dependency bump.
- `.editorconfig` and `.gitattributes` cover Godot's text formats, with tab
  indentation for GDScript per the official style guide.

### Fixed

- The Gradle project detection in `android.yml` used `[ -f a ] && [ -f b ] || [ -f c ]`,
  which binds as `(a && b) || c` and would have reported a project whenever a
  Groovy settings file existed with no wrapper at all.

### Security

- Gradle dependency verification enabled with SHA-256 and PGP, with committed,
  reviewable metadata. This closes boundary 3 of the threat model: the engine is
  native code shipped to users, and its checksum and signature are now checked on
  every build.
- Dependency resolution restricted to Google Maven and MavenCentral, with content
  filters binding coordinate groups to the repository entitled to serve them and
  `FAIL_ON_PROJECT_REPOS` so no module can add a third source.
- The committed Gradle wrapper jar is validated against Gradle's published
  checksums on every run, and the distribution carries a `distributionSha256Sum`.
- Boundary 4 of the threat model closed: the host-to-engine bridge surface is
  defined, minimal, and validated in both directions.
- The application declares no permissions.

## [0.1.0] - 2026-09-10

Initial repository foundation. This release contains no application code: it
establishes the governance, legal, and automation baseline that all later work
builds on.

### Added

- `VERSION` as the single source of truth for the application version.
- `config/android/toolchain.properties` as the single source of truth for the
  Android SDK, build tools, NDK, CMake, ABI, and Java requirements.
- `gradle/libs.versions.toml` version catalogue and
  `config/build-tool-security.versions` for build-tooling security overrides.
- `LICENSE.md` — proprietary license with explicit carve-outs for CC-BY-4.0 and
  third-party material.
- `THIRD_PARTY_NOTICES.md` — third-party inventory, including the System Reference
  Document 5.2.1 attribution required in all five supported locales.
- `CONTRIBUTING.md`, `.github/CODEOWNERS`, and `.gitattributes`.
- Issue forms for bug reports and feature requests, an issue template
  configuration, and a pull request template.
- `.github/labels.yml` as the declarative label catalogue, `.github/labeler.yml`
  path-based labelling rules, and a label synchronisation workflow, so that every
  label referenced by automation is guaranteed to exist.
- `.github/dependabot.yml` and an auto-merge workflow for low-risk Dependabot
  updates.
- Repository validation scripts under `scripts/`, covering version consistency,
  toolchain integrity, licence attribution, label integrity, and commit messages.
- Architecture and release documentation: threat model, release readiness gates,
  and Architecture Decision Records 0001–0004.
- `.vscode/extensions.json` with verified extension recommendations.

### Changed

- Replaced the placeholder `README.md` and `SECURITY.md` with real content.
- Consolidated continuous integration into a non-redundant set of workflows and
  brought every action up to a current, supported major version.
- Reworked the Android build workflow to read the toolchain from its single
  source of truth, to use JDK 17, and to remain inert until a Gradle project
  exists, rather than failing on every run.
- Corrected the CodeQL workflow, whose analysis matrix was empty and therefore
  silently analysed nothing.
- Corrected the labelling and stale workflows, which referenced missing
  configuration and non-existent labels.

### Removed

- `.github/workflows/super-linter.yml`, superseded by the consolidated
  `ci.yml` linting job.

### Security

- Documented the trust boundaries, signing-material handling, and supply-chain
  risks of the planned architecture in `docs/architecture/THREAT_MODEL.md`.
- Applied least-privilege `permissions` to every workflow.
- Pinned every third-party GitHub Action to a full commit SHA, so a retagged or
  compromised upstream release cannot alter what CI executes. Version comments
  are retained so Dependabot can still propose updates.
- Selected the standard Godot build over the .NET variant, which removes an
  unverifiable vendored binary from the planned dependency graph in favour of a
  signed MavenCentral artifact.

[Unreleased]: https://github.com/4Luke4/DungeonLike/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/4Luke4/DungeonLike/releases/tag/v0.1.0
