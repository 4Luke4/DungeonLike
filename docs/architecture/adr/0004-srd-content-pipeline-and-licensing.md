# ADR 0004: SRD content pipeline and licensing

- **Status:** Accepted
- **Date:** 2026-09-10

## Context

DungeonLike's rules, statistics, and reference data derive from the System
Reference Document 5.2.1. The source material is supplied as five PDFs — English
plus German, French, Italian, and Spanish — totalling roughly 35 MB.

Three separate problems have to be solved together: how the material is licensed
and what that obliges us to do, how it physically enters the repository, and how
it becomes reviewable game data.

### Evidence

The documents state that the SRD 5.2.1 is provided by its publisher under the
**Creative Commons Attribution 4.0 International License (CC-BY-4.0)**, and that
use is conditional on including a specific attribution statement. Each localized
edition carries its own official translation of that statement.

Two further conditions apply directly to this project:

1. No attribution to the publisher or its affiliates may be included **beyond**
   the prescribed statement.
2. Section 5 of CC-BY-4.0 disclaims warranties and limits liability.

The five locales in which the statement is officially published happen to be
exactly the five locales DungeonLike ships, so no machine translation of a legal
notice is required — which is fortunate, since a paraphrased attribution would not
reliably satisfy the licence.

## Decision

### Licensing

The mandated attribution is reproduced in `THIRD_PARTY_NOTICES.md` in all five
locales, using the official published wording. It must also be surfaced in the
application's in-app legal screen **in the user's active locale**, because the
obligation attaches to the distributed work, not to the source repository.

`scripts/validate_attribution.py` fails CI if any locale's statement is missing,
if the required elements (document version, rights holder, source URL, licence
URL) are absent, or if `LICENSE.md` loses its third-party carve-out. The
proprietary licence explicitly does not extend to this material.

No other reference to the publisher is permitted anywhere in the repository, the
application, or store metadata.

### Source documents

The PDFs are **excluded from version control** via `.gitignore`. They are large,
they are binary, and committing them would bloat every clone permanently while
adding nothing that cannot be re-obtained from the published source. Contributors
who need to run the extraction obtain them independently.

### Derived data

Game data is committed as **structured, reviewable, text-based files**, never as
extracted prose blobs. Extraction is a deliberate, reviewed step producing data
that is diffable in a pull request. A change to a monster's statistics must show
up as a readable line-level diff.

Locale-specific data is derived from the corresponding localized edition rather
than translated from English, so terminology matches the official wording in each
language.

### Original content

Anything that is not SRD-derived — narrative, naming, art direction, and the
specific combination of mechanics that makes the game — is original work owned by
the copyright holder and covered by `LICENSE.md`. The repository does not
reference, name, or imitate the branding of any third-party product, and no
third-party trade dress is used as a design target.

## Consequences

**Positive.** The licence obligation is enforced by CI rather than by memory, so
a documentation edit cannot quietly delete a required legal notice. Structured
data keeps content changes reviewable and testable. Excluding the PDFs keeps the
repository small.

**Negative.** A contributor cannot reproduce the content pipeline from a clone
alone; they must obtain the source documents separately, and this must be
documented when the pipeline lands. Deriving five locales from five documents is
more work than translating one, though it yields better terminology.

**Negative.** The "no additional attribution" condition is a genuine constraint on
marketing and store copy, and is easy to violate by accident with an innocuous
"thanks to" line. It is called out in `docs/release/READINESS.md` as a release
gate.

**Neutral.** CC-BY-4.0 permits commercial use, so the premium, paid distribution
model is compatible with the licence provided attribution is correct.

**Revisit if** a newer SRD revision is published, if a sixth locale is added, or
if the extraction pipeline needs to ship data the licence does not cover.
