<!-- markdownlint-disable-next-line MD041 -->
<!-- This file becomes the body of every pull request, so it deliberately
     opens with a section rather than a document title. -->
## What this changes

<!-- What the change does and why it is needed. One or two paragraphs. -->

Closes #

## How it was verified

Nothing is verified until GitHub Actions says so. List the jobs that ran on this
branch and their outcome.

| Job | Result |
| --- | --- |
| `CI / meta` | |
| `CI / gradle` | |
| `CI / godot` | |
| `CI / bundle` | |
| `Lint` | |
| `CodeQL` | |
| `Commit messages` | |

### Coverage intentionally skipped

<!--
Required by the repository verification policy. Name any workflow coverage that
was unavailable or deliberately skipped and why — for example instrumentation
tests, on-device performance, or Play integration. Write "none" if nothing was
skipped.
-->

## Checklist

- [ ] Commits follow `.gitmessage` (Conventional Commits, subject ≤ 100 characters)
- [ ] The change is focused; no unrelated cleanup or reformatting
- [ ] Non-obvious security, lifecycle, compatibility and workflow decisions are commented
- [ ] No value duplicated that already has a source of truth: `VERSION`,
      `config/android/toolchain.properties`, `gradle/libs.versions.toml`
- [ ] Automated coverage updated for the changed behaviour
- [ ] Randomness goes through `RngService` only
- [ ] User-visible strings updated in all five locales (en, it, es, fr, de)
- [ ] UI changes account for accessibility, keyboard, mouse, touch, and phone/tablet layout
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] `THIRD_PARTY_NOTICES.md` updated if a shipped dependency or licensing obligation changed
- [ ] Documented security or release gates updated: `SECURITY.md`,
      `docs/architecture/THREAT_MODEL.md`, `docs/release/READINESS.md`
- [ ] No credential, key or keystore appears in the code, logs, artifacts or this description
