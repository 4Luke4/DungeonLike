<!--
Thank you for contributing. Please complete every section.
Pull requests that leave the Verification section empty will not be reviewed —
see CONTRIBUTING.md, "Verification policy".
-->

## Summary

<!-- What does this change do, and why? Link the issue it resolves. -->

Closes #

## Type of change

<!-- Tick all that apply. Must match the Conventional Commit type used. -->

- [ ] `feat` — new capability
- [ ] `fix` — bug fix
- [ ] `perf` — performance improvement
- [ ] `refactor` — behaviour-preserving restructuring
- [ ] `docs` — documentation only
- [ ] `test` — test coverage only
- [ ] `build` / `ci` / `chore` — tooling, automation, or maintenance
- [ ] `revert` — reverts a previous change
- [ ] **Breaking change** (`!` used, and a `BREAKING CHANGE:` footer added)

## Approach

<!--
Explain how the change works and why you chose this approach.
Per CONTRIBUTING.md, cite evidence for any claim about API behaviour, platform
behaviour, or dependency versions. Do not assert versions you have not verified.
-->

## Verification

> **All executable verification runs in GitHub Actions.** Do not report results
> from locally run Gradle tasks, builds, tests, emulators, or packaging.

Which workflow jobs verified this change?

- [ ] `ci.yml` — `lint`
- [ ] `ci.yml` — `validate`
- [ ] `ci.yml` — `commit-messages`
- [ ] `android.yml` — build and tests
- [ ] `codeql.yml` — static analysis

**Coverage intentionally absent or unavailable** (state what, and why):

<!--
Required by AGENTS.md. Write "None" if the change is fully covered.
Example: "android.yml is inert — no Gradle project exists yet."
-->

## Checklist

- [ ] Commits follow Conventional Commits and the `.gitmessage` template
- [ ] Change is focused; no unrelated cleanup or reformatting
- [ ] Non-obvious security boundaries, lifecycle behaviour, and compatibility
      decisions are commented
- [ ] No value owned by a source of truth (`VERSION`,
      `config/android/toolchain.properties`, `gradle/libs.versions.toml`,
      `.github/labels.yml`) has been duplicated
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`, or not applicable
- [ ] No credentials, keystores, or signing material in code, logs, artifacts, or
      this description

## Product invariants

<!-- Tick if applicable, or mark N/A. These are hard product requirements. -->

- [ ] All five locales updated (English, Italian, Spanish, French, German)
- [ ] Phone **and** tablet layouts verified
- [ ] Touch, mouse, and keyboard input all behave correctly
- [ ] Accessibility considered (focus order, labels, contrast, scaling)
- [ ] Still 64-bit `arm64-v8a` only, minimum API 34
- [ ] `THIRD_PARTY_NOTICES.md` updated for any new shipped dependency
- [ ] An ADR was added or superseded under `docs/architecture/adr/`

## Screenshots or recordings

<!-- For any user-visible change, include phone and tablet captures. -->
