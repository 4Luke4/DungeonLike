# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

The version recorded here is always kept identical to the `VERSION` file at the
repository root; `tools/scripts/check_version.py` enforces that in CI.

## [Unreleased]

### Added

- Repository governance: contribution guide, code owners, issue and pull request
  templates, editor and attribute configuration, proprietary licence and
  third-party notices.
- Gradle build for the Android host, pinned to the toolchain declared in
  `config/android/toolchain.properties` (compile and target SDK 37.2 with SDK
  extension 24, build tools 37.0.0, minimum SDK 34, `arm64-v8a` only).
- Kotlin application host embedding the Godot Android library, exposing platform
  entropy, display refresh rates, input-device detection and an achievement
  gateway to the game core.
- Godot game core skeleton with boot, main menu, run shell and credits scenes,
  adaptive phone and tablet layout, and keyboard, mouse and touch input.
- Cryptographic run-seed derivation and an HMAC-DRBG based random number service
  shared by every gameplay system.
- English, Italian, Spanish, French and German localisation scaffolding for both
  the Android host and the game core.
- Continuous integration covering metadata validation, Kotlin unit tests,
  GDScript lint and tests, CodeQL analysis, commit message enforcement, and an
  end-to-end Godot export producing an unsigned debug bundle.
- Architecture, threat model, localisation, random number design and release
  readiness documentation.

## [0.1.0] - 2026-09-15

### Added

- Initial repository with version marker, commit message template and security
  contact information.

[Unreleased]: https://github.com/4Luke4/DungeonLike/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/4Luke4/DungeonLike/releases/tag/v0.1.0
