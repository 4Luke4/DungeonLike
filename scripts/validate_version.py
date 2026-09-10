#!/usr/bin/env python3
"""Verify that VERSION and CHANGELOG.md agree and are well-formed.

VERSION is the single source of truth for the application version. This check
exists because a release where the two disagree is silently wrong: the store
listing, the in-app about screen, and the changelog would each claim something
different, and nothing would fail at build time.

Enforced invariants:

1. VERSION holds exactly one bare SemVer 2.0.0 string, with no ``v`` prefix.
   The prefix is a git tag convention only, so no consumer has to strip it.
2. CHANGELOG.md follows Keep a Changelog: an ``## [Unreleased]`` section, then
   released sections ``## [x.y.z] - YYYY-MM-DD``.
3. The newest released section matches VERSION exactly.
4. Released versions appear in strictly descending order, so the file reads
   newest-first and no release is duplicated.
5. Every version referenced by a section has a matching link definition.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# SemVer 2.0.0, from the official grammar at https://semver.org/spec/v2.0.0.html
SEMVER = re.compile(
    r"^(?P<major>0|[1-9]\d*)"
    r"\.(?P<minor>0|[1-9]\d*)"
    r"\.(?P<patch>0|[1-9]\d*)"
    r"(?:-(?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)"
    r"(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?"
    r"(?:\+(?P<build>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"
)

UNRELEASED_HEADING = re.compile(r"^## \[Unreleased\]\s*$", re.MULTILINE)
RELEASE_HEADING = re.compile(
    r"^## \[(?P<version>[^\]]+)\] - (?P<date>\d{4}-\d{2}-\d{2})\s*$", re.MULTILINE
)
LINK_DEFINITION = re.compile(r"^\[(?P<label>[^\]]+)\]:\s*\S+\s*$", re.MULTILINE)


def sort_key(version: str) -> tuple[int, int, int]:
    """Return the (major, minor, patch) ordering key for a validated version."""
    match = SEMVER.match(version)
    assert match is not None, f"unvalidated version reached sort_key: {version}"
    return (
        int(match.group("major")),
        int(match.group("minor")),
        int(match.group("patch")),
    )


def check(root: Path) -> list[str]:
    errors: list[str] = []

    version_file = root / "VERSION"
    changelog_file = root / "CHANGELOG.md"

    if not version_file.is_file():
        return ["VERSION is missing"]
    if not changelog_file.is_file():
        return ["CHANGELOG.md is missing"]

    raw = version_file.read_text(encoding="utf-8")

    # A stray second line is a common and dangerous edit: naive readers that take
    # the whole file would silently embed a newline into the version string.
    stripped_lines = [line for line in raw.splitlines() if line.strip()]
    if len(stripped_lines) != 1:
        errors.append(
            f"VERSION must contain exactly one non-empty line, found {len(stripped_lines)}"
        )
        return errors

    version = stripped_lines[0].strip()

    if version.startswith("v"):
        errors.append(
            f"VERSION must not carry a 'v' prefix (found {version!r}); "
            "the prefix belongs on git tags only"
        )
    elif not SEMVER.match(version):
        errors.append(f"VERSION {version!r} is not valid SemVer 2.0.0")

    changelog = changelog_file.read_text(encoding="utf-8")

    if not UNRELEASED_HEADING.search(changelog):
        errors.append("CHANGELOG.md is missing its '## [Unreleased]' section")

    releases = [
        (m.group("version"), m.group("date")) for m in RELEASE_HEADING.finditer(changelog)
    ]

    if not releases:
        errors.append("CHANGELOG.md contains no released section '## [x.y.z] - YYYY-MM-DD'")
        return errors

    for released_version, _ in releases:
        if not SEMVER.match(released_version):
            errors.append(
                f"CHANGELOG.md section [{released_version}] is not valid SemVer 2.0.0"
            )

    if any(e.startswith("CHANGELOG.md section") for e in errors):
        return errors

    newest = releases[0][0]
    if not errors and newest != version:
        errors.append(
            f"VERSION ({version}) does not match the newest CHANGELOG.md release ({newest})"
        )

    ordered = [sort_key(v) for v, _ in releases]
    if ordered != sorted(ordered, reverse=True):
        errors.append(
            "CHANGELOG.md releases must be listed newest-first in strictly descending order"
        )
    if len(ordered) != len(set(ordered)):
        errors.append("CHANGELOG.md contains duplicate release versions")

    # Keep a Changelog uses reference-style links; a section without a matching
    # definition renders as literal '[0.1.0]' text in the published changelog.
    defined = {m.group("label") for m in LINK_DEFINITION.finditer(changelog)}
    for label in ["Unreleased", *[v for v, _ in releases]]:
        if label not in defined:
            errors.append(f"CHANGELOG.md has no link definition for [{label}]")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="Repository root to validate (default: the repository containing this script)",
    )
    args = parser.parse_args()

    errors = check(args.root)
    if errors:
        print("Version validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Version validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
