# Repository automation instructions

Scope: `.github/` — workflows, issue and pull request templates, labels, and
Dependabot configuration. The root `AGENTS.md` still applies; this file adds only
what is specific to automation.

## Privilege

- Every workflow declares `permissions` explicitly. The default is
  `contents: read`, and a job that needs more opts in at the job level, never at
  the workflow level, so widening one job cannot widen the others.
- Checkouts set `persist-credentials: false` unless the job genuinely pushes.
  Leaving a writable token on disk hands it to every tool the job then runs.
- `pull_request_target` runs in the base repository's context with a writable
  token. A workflow using it **must not check out or execute head code**. Today
  `label.yml` and `dependabot-auto-merge.yml` both rely on this, and both work
  purely from API data. Adding a checkout step to either is a privilege
  escalation, not a convenience.

## Third-party actions

- Actions published by GitHub (`actions/*`, `github/*`) may be referenced by
  major version tag: those are immutable releases from a first-party publisher.
- **Every other action is pinned to a full commit SHA**, with a trailing
  `# vX.Y.Z` comment. A tag is mutable, so a retagged or compromised upstream
  release would otherwise change what CI executes without any diff. The version
  comment is what lets Dependabot keep proposing updates to a SHA-pinned action.
- Prefer an existing pinned action over adding a new one. Several jobs already
  reuse the same `gradle/actions` SHA for different sub-actions.

## Sources of truth in workflows

- Toolchain values are read from `config/android/toolchain.properties` at run
  time. `scripts/validate_toolchain.py` fails the build if a workflow restates
  one, so a bump stays a single-line change.
- Every label referenced by `labeler.yml`, `stale.yml` or `dependabot.yml` must
  exist in `labels.yml`. `actions/labeler` fails outright when asked to apply a
  label the repository does not have, and `validate_labels.py` catches that
  before it reaches CI.

## Workflow design

- Keep the workflow set non-redundant. Related checks belong as jobs of one
  workflow, sharing a checkout strategy and a status surface, rather than as
  separate workflows racing for the same cache.
- Every workflow sets a `concurrency` group. `main` is excluded from
  cancellation so the default branch's history of runs stays intact.
- A permanently failing or permanently empty check is worse than no check: it
  teaches reviewers to ignore red. Guard work that cannot run yet behind an
  explicit condition, and say so in a `::notice::`.
- Tools that produce evidence upload it with `if: ${{ !cancelled() }}`. A report
  matters most when the job failed.

## Pinned tooling

- Python tooling installed in a workflow is hash-pinned, transitive dependencies
  included, so a compromised release cannot alter what CI enforces. See
  `scripts/requirements.txt` and `linters/gdtoolkit-requirements.txt`.

## Never

- Never place a credential, keystore, signing key, or token value in a workflow
  file, a log line, an artifact, or a job summary.
- Never grant `pull-requests: write` to a linter for the convenience of a
  comment. Annotations and the job summary already carry the findings.
