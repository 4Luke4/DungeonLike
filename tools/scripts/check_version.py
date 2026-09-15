#!/usr/bin/env python3
"""Verify that every place recording the application version agrees.

The version is written down in three files that are edited by different people
for different reasons: ``VERSION`` (the source of truth), ``CHANGELOG.md`` (the
release record) and ``game/project.godot`` (what the engine reports at runtime).
Nothing stops them drifting except this check, and a build whose changelog
describes a different version than the binary is a release incident rather than
a cosmetic problem.

Exits non-zero, listing every disagreement, so one run reports all of them.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]

VERSION_FILE = REPOSITORY_ROOT / "VERSION"
CHANGELOG_FILE = REPOSITORY_ROOT / "CHANGELOG.md"
GODOT_PROJECT_FILE = REPOSITORY_ROOT / "game" / "project.godot"

SEMVER_PATTERN = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
GODOT_VERSION_PATTERN = re.compile(r'^config/version="([^"]*)"', re.MULTILINE)
CHANGELOG_RELEASE_PATTERN = re.compile(r"^## \[(\d+\.\d+\.\d+)\] - \d{4}-\d{2}-\d{2}$", re.MULTILINE)


def main() -> int:
    problems: list[str] = []

    version = VERSION_FILE.read_text(encoding="utf-8").strip()
    if not SEMVER_PATTERN.match(version):
        # Everything else is derived from this value, including the Android
        # versionCode, so an unparseable VERSION is fatal on its own.
        print(f"VERSION must hold a semantic version such as 1.2.3, found {version!r}", file=sys.stderr)
        return 1

    changelog = CHANGELOG_FILE.read_text(encoding="utf-8")
    if "## [Unreleased]" not in changelog:
        problems.append(
            "CHANGELOG.md has no '## [Unreleased]' section; Keep a Changelog requires one "
            "so that work in progress has somewhere to go."
        )

    released = CHANGELOG_RELEASE_PATTERN.findall(changelog)
    if not released:
        problems.append("CHANGELOG.md records no released version in the form '## [1.2.3] - YYYY-MM-DD'.")
    elif version not in released:
        problems.append(
            f"CHANGELOG.md does not record version {version} from VERSION. "
            f"Released versions found: {', '.join(released)}."
        )

    godot_project = GODOT_PROJECT_FILE.read_text(encoding="utf-8")
    godot_match = GODOT_VERSION_PATTERN.search(godot_project)
    if godot_match is None:
        problems.append("game/project.godot declares no config/version.")
    elif godot_match.group(1) != version:
        problems.append(
            f"game/project.godot declares config/version=\"{godot_match.group(1)}\" "
            f"but VERSION says {version}."
        )

    if problems:
        print("Version consistency check failed:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"Version {version} is consistent across VERSION, CHANGELOG.md and game/project.godot.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
