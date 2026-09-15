# Release readiness

The gates that must be green before DungeonLike is published, and an honest
record of where each one stands today.

This document exists to keep "not done yet" distinguishable from "done and
verified". Anything unverified is written down here rather than assumed.

**Current state: pre-release scaffolding.** The toolchain, host, engine
integration and continuous integration are in place. There is no gameplay, no
store presence and no signing. The application is not releasable and no gate
below should be read as passed unless it says so.

## Verification gates

| Gate | State | Notes |
| --- | --- | --- |
| Metadata consistency | Automated | `CI / meta` checks `VERSION`, changelog, locales and randomness usage |
| Kotlin unit tests | Automated | `CI / gradle` |
| Android Lint | Automated | `CI / gradle`, warnings are errors |
| GDScript lint and format | Automated | `CI / godot` |
| GDScript tests | Automated | `CI / godot`, GUT |
| Engine export and bundle | Automated | `CI / bundle`, unsigned debug artifacts |
| Repository lint | Automated | `Lint`, super-linter |
| Static security analysis | Automated | `CodeQL`, `java-kotlin` and `actions` |
| Commit format | Automated | `Commit messages` |

## Coverage intentionally not run

Recorded here because the verification policy requires unavailable or skipped
coverage to be explicit rather than silently absent.

**Instrumentation tests.** `app/src/androidTest` is written and kept compiling
but never executed in CI. The application ships `arm64-v8a` only and the hosted
runners provide no matching device or emulator. It must be run on real hardware,
or on an ARM runner, before the first release.

**On-device performance.** The sustained 60/90/120 fps target and its battery
cost cannot be measured in CI, and cannot be measured meaningfully at all until
there is gameplay to measure. The frame pacing policy is built to be
measurable — the cap is derived from the panel and reported through
`FramePacingService` — but no number has been taken.

**GDScript static analysis.** CodeQL does not support GDScript. The game core is
covered by `gdlint` and by the repository's own checks in `tools/scripts/`. This
is a real gap in coverage, not an absence of findings.

**Release build shrinking.** R8 rules exist for the engine's reflective entry
points but no release build has been produced, so they are unproven. A release
build must be smoke-tested on a device before shipping; a missing `-keep` shows
up only at runtime.

## Blocking work before a first release

### Store and account

- [ ] Create the Google Play application listing for `com.yuumi.dungeonlike`
- [ ] Configure it as a paid, one-time-purchase title in every target market
- [ ] Complete the data safety declaration — the application collects nothing
- [ ] Prepare store assets and localised listings for all five languages
- [ ] Content rating questionnaire

### Signing

- [ ] Generate an upload key and enrol in Play App Signing
- [ ] Store the upload keystore and its credentials in a protected GitHub
      environment, never in the repository
- [ ] Add a release workflow that signs and uploads from that environment only
- [ ] Verify that no signing material reaches logs, artifacts or pull requests

### Play Games Services

- [ ] Create the Play Games project and define achievements
- [ ] Add the `game_ids` resource, kept out of version control
- [ ] Replace `NoOpAchievementGateway` with the Play Games implementation
- [ ] Add the `INTERNET` permission to that variant only, and update the threat
      model to match
- [ ] Verify that an offline session is unaffected when Play is unreachable

### Technical compliance

- [ ] Verify 16 KB page size compatibility of every shipped native library, as
      Play requires for applications targeting recent Android versions
- [ ] Confirm the bundle contains `arm64-v8a` only and no other architecture
- [ ] Run the instrumentation suite on physical hardware, phone and tablet
- [ ] Measure sustained frame rate and battery drain on a 60, a 90 and a 120 Hz
      device
- [ ] Verify the application with a keyboard and a mouse attached, including
      focus navigation throughout
- [ ] Accessibility pass: text scaling, contrast, screen reader labels
- [ ] Verify every screen in all five languages, including the longest strings

### Legal

- [ ] In-application credits and licences screen showing the required
      attribution and the engine's own notices
- [ ] `THIRD_PARTY_NOTICES.md` reconciled against the dependencies that actually
      ship in the release build
- [ ] Privacy policy, stating that no data is collected

## Supported versions

Only the most recent published version receives fixes. The current version is in
`VERSION` and `CHANGELOG.md`; see `SECURITY.md`.
