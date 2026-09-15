#!/usr/bin/env python3
"""Fail the build when a third-party GitHub Action is used on a mutable ref.

A tag or branch can be repointed at different code by whoever controls the
action's repository, so an action referenced as `owner/action@v1` runs whatever
that tag names at the moment the workflow starts. A full commit SHA cannot move,
which is why GitHub's own code scanning reports the mutable form (CWE-829) and
why `docs/architecture/THREAT_MODEL.md` treats the workflow supply chain as a
boundary worth defending.

Actions published by GitHub itself (the `actions` and `github` organisations)
are exempt: their releases are immutable, so a tag there already names fixed
code and pinning would cost readability for no security.

The human-readable version belongs in a trailing comment, which is also what
Dependabot updates:

    uses: owner/action@1234567890abcdef1234567890abcdef12345678 # v1.2.3
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = REPOSITORY_ROOT / ".github" / "workflows"

# Organisations whose releases are immutable, so a tag is already a fixed
# reference. Keep this list short and justified; it is a trust decision.
IMMUTABLE_PUBLISHERS = frozenset({"actions", "github"})

USES = re.compile(r"uses:\s*(?P<owner>[\w.-]+)/(?P<path>[\w./-]+)@(?P<ref>[^\s#]+)")
COMMIT_SHA = re.compile(r"[0-9a-f]{40}")


def main() -> int:
    problems: list[str] = []
    checked = 0

    for workflow in sorted(WORKFLOWS.glob("*.yml")):
        for number, line in enumerate(workflow.read_text(encoding="utf-8").splitlines(), start=1):
            match = USES.search(line)
            if match is None:
                continue
            # A local action is part of this repository and moves with it.
            if match.group("owner") == ".":
                continue
            if match.group("owner") in IMMUTABLE_PUBLISHERS:
                continue

            checked += 1
            reference = match.group("ref")
            if not COMMIT_SHA.fullmatch(reference):
                problems.append(
                    f"{workflow.relative_to(REPOSITORY_ROOT)}:{number}: "
                    f"{match.group('owner')}/{match.group('path')} is pinned to "
                    f"'{reference}', which is a mutable reference"
                )

    if problems:
        print("Third-party actions must be pinned to a commit SHA:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print(
            "\nResolve the tag to a commit with:\n"
            "    gh api repos/<owner>/<repo>/git/ref/tags/<tag>\n"
            "dereferencing an annotated tag through git/tags/<sha>, and keep the "
            "version in a trailing comment so Dependabot can still update it.",
            file=sys.stderr,
        )
        return 1

    print(f"{checked} third-party action reference(s) are pinned to a commit SHA.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
