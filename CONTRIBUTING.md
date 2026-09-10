# Contributing to DungeonLike

Thank you for your interest. Please read this document before opening an issue or
a pull request.

> **Licensing.** DungeonLike is proprietary (see [`LICENSE.md`](LICENSE.md)).
> By submitting a contribution you assign to the copyright holder, to the fullest
> extent permitted by law, all right, title, and interest in that contribution.
> If you are not willing to do that, please open an issue instead of a pull request.

## Reporting

- **Bugs and feature requests** — use the issue forms at
  [New issue](https://github.com/4Luke4/DungeonLike/issues/new/choose). Blank
  issues are disabled because triage depends on the structured fields.
- **Security vulnerabilities** — **do not** open a public issue. Follow
  [`SECURITY.md`](SECURITY.md).

## Before you start

Open an issue and agree the approach before writing a substantial change.
Unsolicited large pull requests are likely to be declined on scope grounds, not on
quality.

## Working standard

These rules are enforced in review and, where possible, in CI.

1. **Evidence over assumption.** Never guess at API behaviour, platform
   behaviour, dependency versions, or security properties. Cite the authoritative
   project file or upstream primary documentation. Version claims must be
   verifiable.
2. **Respect the sources of truth.** Do not restate a value that is already owned
   by [`VERSION`](VERSION), [`config/android/toolchain.properties`](config/android/toolchain.properties),
   [`gradle/libs.versions.toml`](gradle/libs.versions.toml), or
   [`.github/labels.yml`](.github/labels.yml). Read it from its owner.
3. **Keep changes focused.** No unrelated cleanup, reformatting, or premature
   abstraction. Do not modify files outside the scope you agreed.
4. **Comment what is not obvious.** Document security boundaries, lifecycle
   behaviour, compatibility decisions, and workflow constraints. Do not write
   comments that restate the code.
5. **Provenance matters.** Do not copy code whose licensing or origin is unclear.
   Any new shipped dependency must be added to
   [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) in the same pull request.
6. **Preserve every locale.** A change to user-visible strings must cover English,
   Italian, Spanish, French, and German. UI work must account for accessibility,
   touch, mouse, keyboard, and adaptive phone/tablet layout.

## Verification policy

**Do not run Gradle tasks, builds, tests, Android tooling, emulators, or packaging
locally as project verification.** All executable verification happens in GitHub
Actions, so that results are reproducible and reviewable.

Local work is limited to read-only inspection: reading code, reviewing diffs, and
checking repository status.

A change is **not** verified until the relevant workflow jobs pass. State in your
pull request which jobs verified it, and record any coverage that is unavailable
or intentionally skipped, with the reason.

## Commit messages

Commits follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
and are validated by the `commit-messages` job in `ci.yml`.

Load the repository template once:

```bash
git config commit.template .gitmessage
```

Format:

```text
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

- **Allowed types:** `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`,
  `refactor`, `revert`, `style`, `test`.
- **Description:** imperative, lower-case, no trailing period, **at most 100
  characters** including the type and scope prefix.
- **Breaking changes:** append `!` after the type/scope **and** add a
  `BREAKING CHANGE:` footer.

```text
feat(ui): add keyboard navigation to the inventory grid
fix(engine)!: correct save serialisation for multi-run profiles
```

Dependabot is exempt from this check.

## Pull requests

1. Branch from `main` using a descriptive name, for example
   `feat/inventory-keyboard-nav`.
2. Keep the pull request reviewable. Split unrelated work.
3. Fill in the pull request template completely, including the verification section.
4. Update [`CHANGELOG.md`](CHANGELOG.md) under `## [Unreleased]` for any
   user-visible or operationally significant change, following
   [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
5. Ensure all required checks pass. Do not merge on red.
6. `CODEOWNERS` review is required for sources of truth, automation, legal files,
   and architecture documentation.

## Architecture decisions

Significant or hard-to-reverse technical decisions are recorded as ADRs in
[`docs/architecture/adr/`](docs/architecture/adr/). If your change makes such a
decision, add an ADR in the same pull request. If it invalidates an existing one,
supersede that ADR rather than editing its decision in place.

## Repository validation

The scripts in [`scripts/`](scripts/) encode the invariants above and run in CI:

| Script | Enforces |
| ------ | -------- |
| `validate_version.py` | `VERSION` agrees with `CHANGELOG.md`; both are well-formed |
| `validate_toolchain.py` | Toolchain file is well-formed and not duplicated in workflows |
| `validate_attribution.py` | Required SRD attribution present for every locale |
| `validate_labels.py` | Every label used by automation exists in the catalogue |
| `validate_commits.py` | Commit messages follow the convention |

Each accepts `--help`. They are read-only checks and are safe to run locally.
