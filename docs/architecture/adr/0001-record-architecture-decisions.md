# ADR 0001: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-09-10

## Context

DungeonLike is making a number of decisions that are expensive to reverse: the
game engine, the split between the Kotlin host and the GDScript game core, the
Android API baseline, and how licensed reference material is turned into game data.

These decisions are being taken while the repository is still empty, which means
the reasoning behind them exists only in the head of whoever made them. Six months
later the code shows *what* was chosen but not *why*, and the constraints that
forced a choice are indistinguishable from arbitrary preference. That is how a
project ends up either cargo-culting a constraint that no longer applies, or
casually undoing one that still does.

The specific risk here is concrete. Several of the constraints in this project are
non-obvious and externally imposed — for example, the documented limitation that
an embedded Godot engine supports only one instance per process and does not
support resize events. Anyone encountering the resulting architecture without an
explanation would reasonably assume it was a stylistic choice and try to
"improve" it.

## Decision

We record architecturally significant decisions as Architecture Decision Records
in `docs/architecture/adr/`, following Michael Nygard's format.

A decision is architecturally significant if it is costly to reverse, constrains
future work, or would surprise a competent engineer reading the code.

- Files are named `NNNN-short-title.md` with a zero-padded sequence number.
- Each ADR carries a status: `Proposed`, `Accepted`, `Superseded by ADR-NNNN`, or
  `Deprecated`.
- ADRs are immutable once accepted. A changed decision is captured in a **new**
  ADR that supersedes the old one; the original is updated only to point at its
  successor.
- An ADR is added in the same pull request as the change it justifies.

Every ADR must state the evidence behind it. Claims about platform behaviour,
dependency capability, or version availability cite a primary source, because a
decision justified by an assumption is not actually justified.

## Consequences

**Positive.** The reasoning behind hard-to-reverse choices survives. Reviewers can
challenge a decision on its recorded rationale. When a constraint disappears —
for instance, if Godot later supports resize events — the ADR that depended on it
is easy to find and revisit.

**Negative.** Writing an ADR costs time, and the judgement of what counts as
"significant" is imperfect. Recording too few is the more likely failure, so when
in doubt, write one.

**Neutral.** ADRs describe a decision at a point in time. A superseded ADR is
history, not documentation of current behaviour, and should be read as such.
