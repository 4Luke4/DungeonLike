#!/usr/bin/env python3
"""Verify that every label used by automation exists in the label catalogue.

``actions/labeler`` fails its job when told to apply a label the repository does
not have, and ``actions/stale`` cannot mark anything if its marker label is
missing. Both failures were present in this repository before the catalogue was
introduced. This check turns "the label exists" into a reviewable fact enforced
at pull request time rather than a runtime surprise.

Enforced invariants:

1. ``.github/labels.yml`` is well-formed: unique names, valid 6-digit hex colours
   without a leading ``#``, and a description on every entry.
2. Every label referenced by ``.github/labeler.yml`` is defined in the catalogue.
3. Every label referenced by the stale workflow is defined in the catalogue.
4. Every label Dependabot is configured to apply is defined in the catalogue.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - guidance for local runs
    print(
        "PyYAML is required. Install it with: python -m pip install pyyaml",
        file=sys.stderr,
    )
    raise SystemExit(2) from None

REPO_ROOT = Path(__file__).resolve().parent.parent

CATALOG_PATH = Path(".github/labels.yml")
LABELER_PATH = Path(".github/labeler.yml")
DEPENDABOT_PATH = Path(".github/dependabot.yml")
STALE_PATH = Path(".github/workflows/stale.yml")

HEX_COLOR = re.compile(r"^[0-9a-f]{6}$")

# Keys in the stale workflow whose values are label names.
STALE_LABEL_KEYS = (
    "stale-issue-label",
    "stale-pr-label",
    "exempt-issue-labels",
    "exempt-pr-labels",
)


def load_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def load_catalog(root: Path) -> tuple[set[str], list[str]]:
    """Return the defined label names and any structural errors."""
    errors: list[str] = []
    catalog_file = root / CATALOG_PATH
    if not catalog_file.is_file():
        return set(), [f"{CATALOG_PATH} is missing"]

    entries = load_yaml(catalog_file)
    if not isinstance(entries, list):
        return set(), [f"{CATALOG_PATH} must contain a list of label definitions"]

    names: set[str] = set()
    for index, entry in enumerate(entries):
        location = f"{CATALOG_PATH}[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{location}: expected a mapping")
            continue

        name = entry.get("name")
        if not isinstance(name, str) or not name.strip():
            errors.append(f"{location}: 'name' is required and must be a non-empty string")
            continue
        if name in names:
            errors.append(f"{location}: duplicate label name {name!r}")
        names.add(name)

        color = entry.get("color")
        if not isinstance(color, str) or not HEX_COLOR.match(color):
            errors.append(
                f"{location}: label {name!r} needs a 6-digit lower-case hex colour "
                "with no leading '#'"
            )

        description = entry.get("description")
        if not isinstance(description, str) or not description.strip():
            errors.append(f"{location}: label {name!r} needs a description")

    return names, errors


def labels_used_by_labeler(root: Path) -> tuple[set[str], list[str]]:
    path = root / LABELER_PATH
    if not path.is_file():
        return set(), [f"{LABELER_PATH} is missing"]
    document = load_yaml(path)
    if not isinstance(document, dict):
        return set(), [f"{LABELER_PATH} must be a mapping of label name to match rules"]
    return set(document.keys()), []


def labels_used_by_stale(root: Path) -> set[str]:
    """Collect label names from the stale workflow.

    Read textually rather than by walking the parsed workflow tree: the keys of
    interest live inside a step's ``with:`` block, and a shallow textual scan is
    both sufficient and resilient to the workflow being restructured.
    """
    path = root / STALE_PATH
    if not path.is_file():
        return set()

    labels: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        for key in STALE_LABEL_KEYS:
            if line.startswith(f"{key}:"):
                value = line.split(":", 1)[1].strip().strip("'\"")
                labels.update(part.strip() for part in value.split(",") if part.strip())
    return labels


def labels_used_by_dependabot(root: Path) -> set[str]:
    path = root / DEPENDABOT_PATH
    if not path.is_file():
        return set()
    document = load_yaml(path)
    if not isinstance(document, dict):
        return set()

    labels: set[str] = set()
    for update in document.get("updates") or []:
        if isinstance(update, dict):
            for label in update.get("labels") or []:
                if isinstance(label, str):
                    labels.add(label)
    return labels


def check(root: Path) -> list[str]:
    defined, errors = load_catalog(root)
    if errors:
        return errors

    used_by_labeler, labeler_errors = labels_used_by_labeler(root)
    errors.extend(labeler_errors)

    consumers = {
        str(LABELER_PATH): used_by_labeler,
        str(STALE_PATH): labels_used_by_stale(root),
        str(DEPENDABOT_PATH): labels_used_by_dependabot(root),
    }

    for source, used in consumers.items():
        for label in sorted(used - defined):
            errors.append(
                f"{source} references label {label!r}, which is not defined in "
                f"{CATALOG_PATH}. Automation fails when a label does not exist."
            )

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
        print("Label validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Label validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
