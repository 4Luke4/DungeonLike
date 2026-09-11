# Validation script instructions

Scope: `scripts/` — the Python checks that encode repository invariants and run
in the `validate` job of `ci.yml`. The root `AGENTS.md` still applies; this file
adds only what is specific to these scripts.

## What belongs here

A script belongs in this directory when it asserts an invariant that would
otherwise be enforced only by memory: a source of truth agreeing with its
consumers, a licence obligation still being present, a convention being followed.

If a rule can be checked mechanically, check it here rather than describing it in
prose and hoping. A rule documented but unenforced decays.

## Contract

- **Read-only and side-effect free.** These scripts inspect the working tree and
  print findings. They never write, format, or fix. This is what makes them safe
  to run locally under the repository's verification policy, which forbids local
  builds but not local inspection.
- **Exit status is the result**: `0` on success, non-zero on failure. Print every
  failure, not just the first, so one run tells the whole story.
- **Messages are actionable.** State the file, the line where one exists, what
  was found, what was expected, and which file owns the value. A validator that
  only says "validation failed" costs more time than it saves.
- **Accept `--root`** so the script can be pointed at a different checkout, and
  default to the repository containing the script.
- **Standard library first.** A third-party import must be justified; today only
  PyYAML is used, to parse the label catalogue. Anything added must be pinned by
  hash in `requirements.txt`, and installed with `--require-hashes`.

## Style

- Target the Python version the workflow installs. Use `from __future__ import
  annotations` and modern type hints throughout.
- Ruff is configured in `.github/linters/.ruff.toml` and runs through
  super-linter; line length is 100, matching `.editorconfig`.
- The module docstring states which invariants the script enforces, as a numbered
  list. That list is the script's specification and is expected to be read by
  someone deciding whether a new rule belongs in an existing script or a new one.
- Comment the *reason* an invariant exists, not the mechanics of the check.
  "Bare integers are excluded because they collide with action versions" is worth
  writing; "loop over the lines" is not.

## Changing an invariant

Tightening a check is ordinary work. **Loosening or removing one is not**: it
silently widens what the repository will accept. Say in the pull request which
rule was relaxed and why, and if the rule came from an ADR, supersede the ADR
rather than quietly draining it of force.
