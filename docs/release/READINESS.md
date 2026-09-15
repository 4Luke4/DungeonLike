# Release readiness

The gates that must be green before DungeonLike is published, and an honest
record of where each one stands today.

This document exists to keep "not done yet" distinguishable from "done and
verified". Anything unverified is written down here rather than assumed.

**Current state: playable, unreleasable.** A run can be played end to end —
archetype, generated dungeon, turn-based encounters, procedural loot, death or
victory — and resumed after an interruption. There is still no store presence
and no signing, no release build has been produced, and nothing has been run on
a physical device. The application is not releasable and no gate below should be
read as passed unless it says so.

## Verification gates

| Gate | State | Notes |
| --- | --- | --- |
| Metadata consistency | Automated | `CI / meta` checks `VERSION`, changelog, locales and randomness usage |
| Game content data | Automated | `CI / meta`, `check_content.py`: schema, references, ranges, locale keys |
| Content reaches the pack | Automated | `CI / bundle` greps the exported pack for `game/data` |
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
cost cannot be measured in CI. There is now gameplay to measure, which there was
not before, so this has moved from impossible to merely undone: **no number has
been taken**, and the target must not be described as met until one has. The
frame pacing policy is built to be measurable — the cap is derived from the
panel and reported through `FramePacingService`.

**The Android Keystore path.** `KeystoreSaveIntegrity` can only run on a device;
there is no JVM implementation of the Android Keystore and the project has no
Robolectric dependency. The constant-time comparison it depends on was extracted
to `:host-core` as `ConstantTime` and is unit-tested, but tagging, verification
and key invalidation are unexercised until they run on hardware.

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
- [ ] Play a full run on a device and verify that saving, killing the process
      and resuming restores the same dungeon
- [ ] Verify that a save written in the editor and copied to a device is
      reported as unsigned rather than refused
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
