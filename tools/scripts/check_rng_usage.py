#!/usr/bin/env python3
"""Fail the build when gameplay code draws randomness outside RngService.

Every random draw in DungeonLike goes through one service, and the reasons are
recorded in docs/rng/RNG_DESIGN.md: unbiased sampling, independent per-system
streams, and runs that replay exactly from their seed. A single stray
``randi()`` breaks the last of those silently — the run still plays, it simply
stops being reproducible, and nobody notices until a bug report cannot be
reproduced from its seed.

The check is textual on purpose. GDScript has no way to forbid a global
function, so the only place this can be enforced is here.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
GAME_ROOT = REPOSITORY_ROOT / "game"

# The one file allowed to produce randomness, plus the suite that tests it.
EXEMPT_PATHS = {
    GAME_ROOT / "scripts" / "autoload" / "rng_service.gd",
    GAME_ROOT / "tests" / "unit" / "test_rng_service.gd",
}

# Each pattern is paired with what to use instead, so the failure tells the
# author how to fix it rather than only that they were wrong.
FORBIDDEN = [
    (re.compile(r"\brandi_range\s*\("), "RngService.next_in_range(stream, low, high)"),
    (re.compile(r"\brandf_range\s*\("), "RngService.next_float(stream) scaled to the range"),
    (re.compile(r"\brandi\s*\("), "RngService.next_below(stream, bound)"),
    (re.compile(r"\brandf\s*\("), "RngService.next_float(stream)"),
    (re.compile(r"\brandomize\s*\("), "RngService.begin_run()"),
    (re.compile(r"\.shuffle\s*\("), "RngService.shuffled(stream, array)"),
    (re.compile(r"\.pick_random\s*\("), "RngService.pick(stream, array)"),
    (re.compile(r"\bRandomNumberGenerator\b"), "RngService"),
]

# A comment or documentation line may legitimately name a forbidden call while
# explaining why it is forbidden.
COMMENT = re.compile(r"^\s*#")


def main() -> int:
    violations: list[str] = []

    for path in sorted(GAME_ROOT.rglob("*.gd")):
        if path in EXEMPT_PATHS:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if COMMENT.match(line):
                continue
            for pattern, replacement in FORBIDDEN:
                if pattern.search(line):
                    relative = path.relative_to(REPOSITORY_ROOT)
                    violations.append(
                        f"{relative}:{number}: {line.strip()}\n"
                        f"      use {replacement} instead"
                    )
                    break

    if violations:
        print("Randomness must go through RngService:", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        print(
            "\nSee docs/rng/RNG_DESIGN.md for why. If a new case genuinely belongs "
            "in the service, add it there rather than exempting the caller.",
            file=sys.stderr,
        )
        return 1

    print("All randomness goes through RngService.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
