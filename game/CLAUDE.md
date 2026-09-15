# Godot game core instructions

These rules apply to `game/`. They complement the repository root `CLAUDE.md`;
nothing here repeats it.

## Project conventions

- **Tabs** for indentation, as the official Godot style guide and `gdformat`
  require. `.editorconfig` already configures this; do not reformat with spaces.
- Typed GDScript everywhere: annotate variables, parameters and return types.
  `gdlint` runs in CI and untyped code is a review blocker.
- File and function names are `snake_case`; class names and scene root nodes are
  `PascalCase`; scene files are `snake_case.tscn`.
- Scripts live under `scripts/`, scenes under `scenes/`, translations under
  `localization/`, content data under `data/`, tests under `tests/unit/`. A
  scene's script sits beside it or in the matching `scripts/` subdirectory —
  never both.
- Gameplay is divided by what it decides: `scripts/rules/` holds the rules
  primitives, `scripts/generation/` builds the map and its encounters,
  `scripts/combat/` resolves a fight, `scripts/loot/` generates items,
  `scripts/run/` holds the run and is the only thing that changes it,
  `scripts/content/` reads `data/`. None of them is a `Node`: a run must be
  playable through in a test with no scene tree.

## Randomness is not optional

`randi()`, `randf()`, `randi_range()`, `randf_range()`, `Array.shuffle()` and
direct `RandomNumberGenerator` use are **forbidden** outside
`scripts/autoload/rng_service.gd`. CI fails the build on any occurrence.

Every draw goes through `RngService`, on a named stream:

```gdscript
var damage: int = RngService.roll("encounter", 2, 6)
var index: int = RngService.next_below("loot", table.size())
```

The reasons — unbiased sampling, stream independence, seed reproducibility and
verifiable fairness — are in `docs/rng/RNG_DESIGN.md`. A system that draws from
the wrong stream silently changes every other system's sequence, so pick the
stream deliberately.

Content generated per room draws from a stream scoped to that room:

```gdscript
var stream := RngService.stream_for(RngService.STREAM_ENCOUNTER, node.id)
```

**Interface code never draws at all.** Not from `cosmetic` either: presentation
variation is drawn once when a room is generated and stored on the record. A
shuffled flourish in a view would shift every later gameplay draw, nothing would
appear to break, and the run would simply stop replaying from its seed.

## Autoloads

Autoloads are services, not state buckets. The registered set is:

| Autoload | Responsibility |
| --- | --- |
| `HostBridge` | The only access point to the Kotlin host |
| `RngService` | All randomness |
| `FramePacingService` | Refresh-rate policy and idle power behaviour |
| `InputModeService` | Touch, keyboard and pointer mode |
| `LocaleService` | Language selection and fallback |
| `SettingsService` | Persisted player settings |

Adding an autoload requires a reason in `docs/architecture/ARCHITECTURE.md`.
Never call `Engine.get_singleton()` for the host plugin outside `HostBridge`:
the bridge is what makes the project still run in the editor on desktop, where
no Android host exists.

## Performance and power

The frame-rate policy is deliberate, not accidental. V-Sync is enabled, Swappy
frame pacing runs in `pipeline_forced_on` so that `Engine.max_fps` is honoured
rather than silently downgraded, and the cap is derived at runtime from the
panel's real refresh rate. Static screens enable low-processor mode so that a
menu does not drain the battery.

Do not set `Engine.max_fps`, toggle `low_processor_mode`, or change the V-Sync
mode anywhere except `FramePacingService`.

## Input and layout

Every interaction must work with touch, with a physical keyboard, and with a
mouse — Android tablets and desktop-mode devices routinely have all three.
Bind actions in the input map rather than reading raw keys, keep focus
navigation intact for keyboard users, and lay out with anchors and containers so
that the same scene adapts from a phone to a tablet.

## Content and licensing

Rules terminology derives from the System Reference Document 5.2.1 under
CC-BY-4.0, with the attribution recorded in `THIRD_PARTY_NOTICES.md` and shown
in the credits scene. Do not paste document text wholesale into scenes or data
files, and do not reference any other game — this project is an original work.

`game/data/` carries **mechanical values only** — ability scores, armour class,
hit dice, dice expressions, damage types and rules-term names — and every
player-visible string in it is a key into `game/localization/`.
`tools/scripts/check_content.py` allows no free text in those files at all,
which turns the rule above from something to remember into something the build
enforces. Flavour prose, monster names and item names are written originally for
this project and live in the translation tables, where a reviewer sees all five
languages at once.
