#!/usr/bin/env python3
"""Verify that required third-party attribution is present for every locale.

The System Reference Document 5.2.1 is licensed under CC-BY-4.0, which permits
use only if the licensor's attribution statement accompanies the work. Losing
that statement is a licence violation, and it is exactly the kind of thing a
routine documentation edit can delete without anyone noticing. This check makes
its removal a build failure.

Enforced invariants:

1. ``THIRD_PARTY_NOTICES.md`` exists and carries an attribution statement for
   every supported locale.
2. Each statement names the document, its rights holder, the source URL, and the
   CC-BY-4.0 licence URL, which are the elements the licence requires.
3. ``LICENSE.md`` keeps the carve-out declaring that third-party material is not
   covered by the proprietary grant.

The checks match on required *elements* rather than on an exact byte-for-byte
string, so that wrapping and punctuation can change without weakening the test.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

NOTICES_PATH = Path("THIRD_PARTY_NOTICES.md")
LICENSE_PATH = Path("LICENSE.md")

# Locales the application ships. English is the default.
SUPPORTED_LOCALES = {
    "en": "English",
    "it": "Italiano",
    "es": "Español",
    "fr": "Français",
    "de": "Deutsch",
}

# A locale-distinctive fragment of each official attribution statement. These are
# deliberately short: enough to prove the correct localized wording is present,
# without pinning the whole sentence.
LOCALE_MARKERS = {
    "en": "This work includes material from the System Reference Document",
    "it": "Quest'opera include materiale tratto dal System Reference Document",
    "es": "Esta obra incluye material procedente del documento de referencia del sistema",
    "fr": "Cette œuvre inclut du matériel issu du System Reference Document",
    "de": "Dieses Werk enthält Material aus dem Systemreferenzdokument",
}

# Elements CC-BY-4.0 requires the attribution to carry.
REQUIRED_ELEMENTS = {
    "the document version": r"5\.2\.1",
    "the rights holder": r"Wizards of the Coast LLC",
    "the source URL": r"https://www\.dndbeyond\.com/srd",
    "the licence URL": r"https://creativecommons\.org/licenses/by/4\.0/",
}

# The proprietary licence must keep saying it does not cover third-party material.
LICENSE_CARVE_OUT = [
    r"CC-BY-4\.0|Creative Commons Attribution 4\.0",
    r"THIRD_PARTY_NOTICES\.md",
]


def normalise(text: str) -> str:
    """Collapse whitespace so a marker still matches across a line wrap.

    Markdown blockquotes are hard-wrapped for readability, which splits the
    attribution sentence across lines. Comparing on normalised text keeps the
    check robust against reflowing.
    """
    without_quotes = re.sub(r"^\s*>\s?", "", text, flags=re.MULTILINE)
    return re.sub(r"\s+", " ", without_quotes)


def check(root: Path) -> list[str]:
    errors: list[str] = []

    notices_file = root / NOTICES_PATH
    if not notices_file.is_file():
        return [f"{NOTICES_PATH} is missing; it carries a mandatory licence obligation"]

    notices = normalise(notices_file.read_text(encoding="utf-8"))

    for code, name in sorted(SUPPORTED_LOCALES.items()):
        marker = normalise(LOCALE_MARKERS[code])
        if marker not in notices:
            errors.append(
                f"{NOTICES_PATH}: missing the required SRD 5.2.1 attribution for "
                f"{name} ({code})"
            )

    for description, pattern in REQUIRED_ELEMENTS.items():
        if not re.search(pattern, notices):
            errors.append(
                f"{NOTICES_PATH}: attribution does not state {description}, "
                "which CC-BY-4.0 requires"
            )

    license_file = root / LICENSE_PATH
    if not license_file.is_file():
        errors.append(f"{LICENSE_PATH} is missing")
    else:
        license_text = license_file.read_text(encoding="utf-8")
        for pattern in LICENSE_CARVE_OUT:
            if not re.search(pattern, license_text):
                errors.append(
                    f"{LICENSE_PATH}: the third-party carve-out no longer references "
                    f"/{pattern}/. The proprietary grant must not appear to cover "
                    "CC-BY-4.0 material."
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
        print("Attribution validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(
        "Attribution validation passed "
        f"({len(SUPPORTED_LOCALES)} locales verified)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
