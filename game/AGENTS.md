# Game core instructions

Scope: `game/` — the Godot project and the GDScript game core. The root
`AGENTS.md` still applies; this file adds only what is specific to the engine
side.

## This code is not statically analysed

CodeQL does not support GDScript, and neither does super-linter. ADR 0002
accepted that cost knowingly, which means the safety net other parts of this
repository enjoy does not exist here. Two consequences follow, and they are the
most important thing on this page:

1. **Review carries the weight.** A defect here will not be caught by a scanner.
   Read engine-side changes more carefully than you would read host code.
2. **`gdtoolkit` is not optional.** `gdlint` and `gdformat --check` run in the
   `gdscript` job of `ci.yml` and are the only automated coverage this code gets.

## Language conventions

- **Use static type hints consistently**, not occasionally. GDScript is
  dynamically typed, so a class of error the Kotlin compiler would reject must be
  caught here by typed declarations, tests and review. Rules-heavy simulation
  code is exactly where untyped values hurt most.
- Indent with **tabs**, per the official GDScript style guide and the editor
  default. `.editorconfig` encodes this.
- Document exported members and any non-obvious rule with `##` doc comments.

## Trust

The host is a separate trust domain. Values arriving from it are validated before
use, and an unrecognised value is surfaced rather than pasted into the interface
or assumed benign (`THREAT_MODEL.md`, boundary 4).

Names shared with the host — the plugin singleton name and its signal names —
are a cross-language contract. A mismatch fails **silently**, because a missing
singleton is an absent lookup rather than an error, so both sides carry a comment
pointing at the other.

## Project files

- Scenes and resources stay in Godot's **text** formats (`.tscn`, `.tres`) so
  changes remain reviewable line by line. Binary scene formats are not committed.
- `project.godot` and `export_presets.cfg` are committed and reviewed: they
  decide what ends up in the shipped pack.
- `.godot/` is a generated import cache and is never committed. CI regenerates it
  before exporting.
- `export_credentials.cfg` must never be committed; it holds secrets.
- Keep `config/features` in step with the engine version pinned in
  `config/android/toolchain.properties`.

## UI and layout

The engine owns every pixel the player sees, so accessibility and adaptive layout
are built here or not at all — Android's accessibility services see one surface,
not a view tree, and nothing is inherited for free.

- Express phone and tablet layout with anchors and containers, sized to the
  viewport, so one layout adapts rather than branching per device.
- Support touch, mouse and physical keyboard. The host reports which are
  attached, including when a peripheral appears mid-session; no action may be
  reachable by touch alone.
- Every user-visible string must exist in all five supported locales, with
  locale-specific data derived from the corresponding official source document
  rather than translated from English (ADR 0004).
