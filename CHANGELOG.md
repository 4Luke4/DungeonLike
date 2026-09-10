# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

The current version is recorded in [`VERSION`](VERSION), which is the single
source of truth. `scripts/validate_version.py` fails CI if the two disagree.

## [Unreleased]

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
