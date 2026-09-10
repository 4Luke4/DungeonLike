# Release readiness

- **Status:** Living document
- **Last reviewed:** 2026-09-10

The gates a DungeonLike release must clear before it is published to Google Play.
A gate is either **met**, **not met**, or **not applicable with a recorded
reason** — never silently skipped.

> **Current state.** No release has been made. `0.1.0` is a repository foundation
> with no application code, so most gates below are not yet applicable. They are
> recorded now so that the first release is measured against a standard defined
> in advance rather than one invented under deadline pressure.

## How to use this document

1. Work through every section. Record the evidence, not just a tick.
2. Evidence means a passing GitHub Actions job, a linked artifact, or a
   documented decision. **Locally run builds and tests are not evidence** — see
   the verification policy in `AGENTS.md` and `CONTRIBUTING.md`.
3. Any gate marked not applicable states why, in the release pull request.

## 1. Versioning and changelog

- [ ] `VERSION` bumped according to Semantic Versioning.
- [ ] `CHANGELOG.md` has a released section matching `VERSION`, with a date.
- [ ] `## [Unreleased]` is empty or carries only genuinely unreleased work.
- [ ] Comparison links at the bottom of the changelog are correct.
- [ ] `ci.yml` → `validate` passed, proving the above mechanically.
- [ ] Release tagged `vX.Y.Z`, matching `VERSION` with the `v` prefix.

## 2. Build and toolchain

- [ ] `android.yml` build and test jobs passed on the release commit.
- [ ] Toolchain values come solely from `config/android/toolchain.properties`.
- [ ] `minSdk` is 34; `compileSdk` and `targetSdk` are as recorded in ADR 0003.
- [ ] Release artifact contains **only** `arm64-v8a`; no 32-bit or x86 slice.
- [ ] Native libraries are 16 KB page-size compatible, as required for recent
      Android releases on 64-bit devices.
- [ ] App bundle builds reproducibly from a clean checkout of the tagged commit.
- [ ] Release build is minified and resource-shrunk, and the mapping file is
      retained for deobfuscating crash reports.

## 3. Security

- [ ] `codeql.yml` passed with no new alerts at or above the agreed severity.
- [ ] Gitleaks reported no secrets.
- [ ] No credential, keystore, or signing material appears in the repository,
      logs, artifacts, or release notes.
- [ ] Signing performed with the release key from protected secrets, in a
      protected environment.
- [ ] `docs/architecture/THREAT_MODEL.md` reviewed; every open item is either
      closed or explicitly accepted for this release.
- [ ] **Boundary 3 resolved:** the Godot .NET library's checksum is verified
      against the published release, and the expected value is recorded in the
      repository.
- [ ] Dependency updates reviewed; no known-vulnerable shipped dependency.
- [ ] App requests only the permissions it genuinely needs, each justified.
- [ ] No debug logging of sensitive data; debuggable flag unset in release.

## 4. Licensing and attribution

- [ ] `ci.yml` → `validate` confirmed the SRD 5.2.1 attribution is present for all
      five locales.
- [ ] The attribution is visible in the **in-app** legal screen, in the user's
      active locale — not only in the repository.
- [ ] **No attribution to the publisher or its affiliates beyond the prescribed
      statement** appears in the app, the store listing, or marketing copy. This
      is a licence condition and is easy to breach with a well-meaning credit line.
- [ ] `THIRD_PARTY_NOTICES.md` lists every shipped dependency, including Godot's
      MIT notice and the relevant entries from the engine's copyright file.
- [ ] No third-party branding, trade dress, or trademark is used or imitated.
- [ ] `LICENSE.md` carve-outs remain accurate.

## 5. Localization

- [ ] All five locales complete: English, Italian, Spanish, French, German.
- [ ] No untranslated or placeholder strings in any shipped locale.
- [ ] Locale-specific data derives from the corresponding official edition, not
      from a translation of the English one (ADR 0004).
- [ ] Layouts verified against the longest translation; no clipping or overlap.
- [ ] Numbers, dates, and plurals format correctly per locale.
- [ ] Store listing localized for all five locales.

## 6. Adaptive layout and input

- [ ] Verified on a phone and on a tablet, in portrait and landscape.
- [ ] Layout adapts within the engine (ADR 0002); the host activity declares
      `android:configChanges` so it is not recreated underneath the engine.
- [ ] No crash or visual corruption on rotation, multi-window, or a foldable
      posture change — the specific failure modes the engine documents.
- [ ] Touch input: all interactive targets are comfortably reachable and sized.
- [ ] **Mouse**: hover, click, right-click, and scroll all behave correctly.
- [ ] **Physical keyboard**: full navigation, shortcuts, and text entry; no
      action is reachable only by touch.
- [ ] Input device detection switches the interaction model correctly, including
      when a peripheral is connected or removed mid-session.

## 7. Accessibility

> Called out explicitly because ADR 0002 identifies accessibility as the main
> cost of rendering entirely inside the engine: platform accessibility services
> see a single surface, not a native view tree, so nothing is inherited for free.

- [ ] Screen-reader support verified with TalkBack.
- [ ] Focus order is logical and every interactive element is reachable.
- [ ] Text scaling honoured without clipping or overlap.
- [ ] Contrast meets WCAG AA for text and essential UI.
- [ ] No information conveyed by colour alone.
- [ ] Motion, flashing, and screen-shake can be reduced or disabled.
- [ ] No gameplay-critical action requires a fine-timing gesture with no alternative.

## 8. Quality and stability

- [ ] Unit tests pass in CI.
- [ ] No known crash in the core loop: start a run, play, die, restart.
- [ ] Save and load verified, including an upgrade from the previous release.
- [ ] Corrupt or truncated save data fails safe rather than crashing.
- [ ] Performance acceptable on a low-end supported device, not just a flagship.
- [ ] Memory and battery use are reasonable for a sustained session.
- [ ] Cold start time measured and acceptable.

## 9. Store and commercial

- [ ] Application ID is `com.yuumi.dungeonlike`.
- [ ] `versionCode` strictly greater than the previous release.
- [ ] Configured as a paid, one-time purchase.
- [ ] Purchase entitlement verified on a real device against the platform
      mechanism.
- [ ] Store listing, screenshots (phone **and** tablet), and description complete
      in all five locales.
- [ ] Content rating questionnaire completed accurately.
- [ ] Data safety form accurate — currently: no data collected, no data shared.
- [ ] Privacy policy published and linked, consistent with the data safety form.
- [ ] Target API level satisfies Google Play's current requirement.

## 10. Post-release

- [ ] Staged rollout used; crash and ANR rates monitored before full release.
- [ ] Release tagged, and a GitHub release created with notes from the changelog.
- [ ] Mapping file uploaded so crash reports deobfuscate.
- [ ] Rollback plan understood: a Play release cannot be un-published, so the
      remedy is a forward fix and halting the rollout.
- [ ] `SECURITY.md` supported-versions table updated.

## Sign-off

| Field | Value |
| ----- | ----- |
| Version | |
| Release commit | |
| Verified by | |
| Date | |
| Gates not applicable, with reasons | |
