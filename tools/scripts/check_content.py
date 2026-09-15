#!/usr/bin/env python3
"""Fail the build when the game's content data is malformed or incomplete.

Everything the player fights, wears and walks through is declared in JSON under
``game/data``. None of it is code, so none of it is checked by a compiler, and a
mistake in it fails in one of two ways that are both worse than a build error:
a mistyped key silently takes a default value and quietly changes the balance of
every run, or a missing translation reaches a player as a raw ``MONSTER_*`` key
on screen.

This script is the compiler those files do not otherwise have.

Two properties of the environment shape it:

* It runs in the ``meta`` job of ``.github/workflows/ci.yml``, which sets up
  Python and then runs the checkers directly. Nothing is pip-installed there, so
  this script uses **only the standard library** — no ``jsonschema``. Adding a
  dependency for one script would mean adding an install step, a lock file and a
  supply-chain surface to a job whose whole point is that it is cheap.
* It runs without Godot, so it cannot load the project. Every rule here is
  therefore expressed against the raw files.

The prose rule in ``check_prose`` is a licensing control as much as a
localisation one: ``game/CLAUDE.md`` forbids pasting source-document text into
data files, and the surest way to enforce that is to allow no free text in them
at all. Every player-visible string is a key into the localisation tables, where
a reviewer sees all five languages side by side.
"""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path
from typing import Any

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DATA_ROOT = REPOSITORY_ROOT / "game" / "data"
LOCALIZATION_ROOT = REPOSITORY_ROOT / "game" / "localization"

# The schema version every data file must declare. Bumping it is a deliberate
# act: it exists so that a future format change cannot silently reinterpret
# files written under the old one.
SCHEMA_VERSION = 1

IDENTIFIER = re.compile(r"^[a-z][a-z0-9_]*$")
LOCALE_KEY = re.compile(r"^[A-Z][A-Z0-9_]*$")

# Dice are the one place a typo is invisible: "2d6++2" parses as nothing and a
# lenient reader would treat it as zero damage.
DICE = re.compile(r"^\d{1,2}d(2|3|4|6|8|10|12|20|100)([+-]\d{1,3})?$")

# The challenge ratings below 1 are fractions, which is why this is a set of
# strings rather than a numeric range.
CHALLENGE_RATINGS = frozenset(
    {"0", "1/8", "1/4", "1/2"} | {str(number) for number in range(1, 31)}
)

ABILITIES = frozenset({"str", "dex", "con", "int", "wis", "cha"})

DAMAGE_TYPES = frozenset({
    "acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic",
    "piercing", "poison", "psychic", "radiant", "slashing", "thunder",
})

# Only the conditions the combat resolver actually implements. Listing one here
# that nothing applies would be dead content; applying one that is not listed
# would be a silent no-op.
CONDITIONS = frozenset({
    "blinded", "frightened", "incapacitated", "invisible", "paralysed",
    "poisoned", "prone", "restrained", "stunned", "unconscious",
})

ROOM_KINDS = frozenset({"encounter", "treasure", "rest", "elite", "boss"})

EQUIPMENT_SLOTS = frozenset({"main_hand", "off_hand", "armour", "trinket"})

RARITIES = frozenset({"common", "uncommon", "rare", "very_rare"})

# Effects an item or a power may carry. The resolver switches on exactly these,
# so an unknown kind is a silent no-op rather than a crash — which is why it is
# rejected here instead.
EFFECT_KINDS = frozenset({
    "attack_bonus", "armour_class_bonus", "ability_bonus", "bonus_damage",
    "max_hit_points", "damage_resistance", "on_hit_condition",
})


class Problem(list):
    """Collected failures, so one run reports every mistake rather than the first."""

    def at(self, where: str, message: str) -> None:
        self.append(f"{where}: {message}")


def load(path: Path, collection: str, problems: Problem) -> list[dict[str, Any]]:
    """Reads one data file and returns its records, or an empty list on failure."""
    relative = path.relative_to(REPOSITORY_ROOT)
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as failure:
        problems.at(str(relative), f"could not be read as JSON ({failure})")
        return []

    if document.get("schema") != SCHEMA_VERSION:
        problems.at(
            str(relative),
            f"declares schema {document.get('schema')!r}, expected {SCHEMA_VERSION}",
        )
    records = document.get(collection)
    if not isinstance(records, list) or not records:
        problems.at(str(relative), f"has no non-empty '{collection}' array")
        return []
    return records


def check_fields(
    where: str,
    record: dict[str, Any],
    required: dict[str, type | tuple[type, ...]],
    optional: dict[str, type | tuple[type, ...]],
    problems: Problem,
) -> None:
    """Rejects missing fields, wrong types and — importantly — unknown fields.

    Rejecting unknown fields is what catches a misspelling such as
    ``armor_class``: without it the record simply has no armour class and the
    reader silently supplies a default.
    """
    for name, expected in required.items():
        if name not in record:
            problems.at(where, f"is missing required field '{name}'")
        elif not isinstance(record[name], expected):
            problems.at(where, f"field '{name}' should be {expected}")
    for name, expected in optional.items():
        if name in record and not isinstance(record[name], expected):
            problems.at(where, f"field '{name}' should be {expected}")
    for name in record:
        if name not in required and name not in optional:
            problems.at(where, f"has unknown field '{name}' (a typo, or a schema change?)")


def check_dice(where: str, field: str, value: Any, problems: Problem) -> None:
    if not isinstance(value, str) or not DICE.fullmatch(value):
        problems.at(where, f"field '{field}' is not a dice expression: {value!r}")


def check_enum(where: str, field: str, value: Any, allowed: frozenset, problems: Problem) -> None:
    if value not in allowed:
        problems.at(where, f"field '{field}' is {value!r}, not one of {sorted(allowed)}")


def check_damage_list(where: str, entries: Any, problems: Problem) -> None:
    if not isinstance(entries, list) or not entries:
        problems.at(where, "damage must be a non-empty list")
        return
    for index, entry in enumerate(entries):
        spot = f"{where} damage[{index}]"
        if not isinstance(entry, dict):
            problems.at(spot, "must be an object")
            continue
        check_fields(spot, entry, {"dice": str, "type": str}, {}, problems)
        if "dice" in entry:
            check_dice(spot, "dice", entry["dice"], problems)
        if "type" in entry:
            check_enum(spot, "type", entry["type"], DAMAGE_TYPES, problems)


def check_effects(where: str, effects: Any, problems: Problem) -> None:
    """Validates an effect list against the kinds the resolver implements."""
    if not isinstance(effects, list) or not effects:
        problems.at(where, "effects must be a non-empty list")
        return
    for index, effect in enumerate(effects):
        spot = f"{where} effects[{index}]"
        if not isinstance(effect, dict):
            problems.at(spot, "must be an object")
            continue
        kind = effect.get("kind")
        check_enum(spot, "kind", kind, EFFECT_KINDS, problems)
        if kind in {"attack_bonus", "armour_class_bonus"}:
            check_fields(spot, effect, {"kind": str, "amount": int}, {}, problems)
            if not 1 <= effect.get("amount", 0) <= 5:
                problems.at(spot, "amount must be between 1 and 5")
        elif kind == "max_hit_points":
            # Rolled once when the item is generated and then stored, so the
            # same item never changes value between sessions.
            check_fields(spot, effect, {"kind": str, "roll": str}, {}, problems)
            if "roll" in effect:
                check_dice(spot, "roll", effect["roll"], problems)
        elif kind == "ability_bonus":
            check_fields(spot, effect, {"kind": str, "ability": str, "amount": int}, {}, problems)
            if "ability" in effect:
                check_enum(spot, "ability", effect["ability"], ABILITIES, problems)
            if not 1 <= effect.get("amount", 0) <= 4:
                problems.at(spot, "amount must be between 1 and 4")
        elif kind == "bonus_damage":
            check_fields(spot, effect, {"kind": str, "damage": dict}, {}, problems)
            if isinstance(effect.get("damage"), dict):
                check_damage_list(spot, [effect["damage"]], problems)
        elif kind == "damage_resistance":
            check_fields(spot, effect, {"kind": str, "damage_type": str}, {}, problems)
            if "damage_type" in effect:
                check_enum(spot, "damage_type", effect["damage_type"], DAMAGE_TYPES, problems)
        elif kind == "on_hit_condition":
            check_fields(
                spot,
                effect,
                {"kind": str, "condition": str, "save_ability": str,
                 "difficulty_class": int, "rounds": int},
                {},
                problems,
            )
            if "condition" in effect:
                check_enum(spot, "condition", effect["condition"], CONDITIONS, problems)
            if "save_ability" in effect:
                check_enum(spot, "save_ability", effect["save_ability"], ABILITIES, problems)


def collect_locale_keys(problems: Problem) -> set[str]:
    """Every key declared in every localisation table, with its row fully translated.

    A key that exists but is blank in one language is treated as absent: shipping
    an empty cell is the failure this is meant to prevent, and
    ``check_locales.py`` reports the same row from the other direction.
    """
    keys: set[str] = set()
    tables = sorted(LOCALIZATION_ROOT.glob("*.csv"))
    if not tables:
        problems.at("game/localization", "contains no CSV translation tables")
        return keys

    for table in tables:
        with table.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                key = (row.get("keys") or "").strip()
                if key:
                    keys.add(key)
    return keys


def check_prose(where: str, record: Any, problems: Problem) -> None:
    """Rejects any free text in a data file.

    Every string in ``game/data`` must be an identifier, a localisation key, a
    dice expression, a challenge rating or a member of a closed vocabulary.
    Anything else is prose, and prose belongs in the localisation tables — both
    because a translator has to see it and because ``game/CLAUDE.md`` forbids
    source-document text from reaching these files.
    """
    if isinstance(record, dict):
        for value in record.values():
            check_prose(where, value, problems)
    elif isinstance(record, list):
        for value in record:
            check_prose(where, value, problems)
    elif isinstance(record, str):
        acceptable = (
            IDENTIFIER.fullmatch(record)
            or LOCALE_KEY.fullmatch(record)
            or DICE.fullmatch(record)
            or record in CHALLENGE_RATINGS
        )
        if not acceptable:
            problems.at(
                where,
                f"contains free text {record!r}; prose belongs in the localisation "
                f"table, not in game/data",
            )


def check_identity(
    where_file: str,
    records: list[dict[str, Any]],
    seen: dict[str, str],
    problems: Problem,
) -> None:
    """Ids are unique across the whole database, not merely within one file."""
    for record in records:
        identifier = record.get("id")
        if not isinstance(identifier, str) or not IDENTIFIER.fullmatch(identifier):
            problems.at(where_file, f"has an invalid id {identifier!r}")
            continue
        if identifier in seen:
            problems.at(where_file, f"id '{identifier}' is already declared in {seen[identifier]}")
        else:
            seen[identifier] = where_file


def main() -> int:  # noqa: C901 — one linear pass per file reads better than ten helpers
    problems = Problem()
    locale_keys = collect_locale_keys(problems)
    seen_ids: dict[str, str] = {}

    def require_key(where: str, key: Any) -> None:
        if not isinstance(key, str) or not LOCALE_KEY.fullmatch(key):
            problems.at(where, f"localisation key {key!r} is not of the form UPPER_SNAKE_CASE")
        elif key not in locale_keys:
            problems.at(where, f"localisation key '{key}' exists in no translation table")

    # --- Monsters -----------------------------------------------------------
    monsters = load(DATA_ROOT / "monsters.json", "monsters", problems)
    check_identity("monsters.json", monsters, seen_ids, problems)
    monster_ids = {record.get("id") for record in monsters}
    for monster in monsters:
        where = f"monsters.json[{monster.get('id')}]"
        check_prose(where, monster, problems)
        check_fields(
            where,
            monster,
            {
                "id": str, "name_key": str, "size": str, "creature_type": str,
                "challenge": str, "armour_class": int, "hit_dice": str, "speed_ft": int,
                "abilities": dict, "proficiency_bonus": int,
                "saving_throw_proficiencies": list, "damage_resistances": list,
                "damage_immunities": list, "damage_vulnerabilities": list,
                "condition_immunities": list, "actions": list, "cosmetic_variants": int,
            },
            {},
            problems,
        )
        require_key(where, monster.get("name_key"))
        check_enum(where, "challenge", monster.get("challenge"), CHALLENGE_RATINGS, problems)
        check_dice(where, "hit_dice", monster.get("hit_dice"), problems)
        if not 1 <= monster.get("armour_class", 0) <= 30:
            problems.at(where, "armour_class must be between 1 and 30")
        if monster.get("cosmetic_variants", 0) < 1:
            problems.at(where, "cosmetic_variants must be at least 1")
        for ability, score in (monster.get("abilities") or {}).items():
            check_enum(where, "abilities key", ability, ABILITIES, problems)
            if not isinstance(score, int) or not 1 <= score <= 30:
                problems.at(where, f"ability '{ability}' is {score!r}, expected 1-30")
        if set(monster.get("abilities") or {}) != ABILITIES:
            problems.at(where, "must declare all six ability scores")
        for field, allowed in (
            ("saving_throw_proficiencies", ABILITIES),
            ("damage_resistances", DAMAGE_TYPES),
            ("damage_immunities", DAMAGE_TYPES),
            ("damage_vulnerabilities", DAMAGE_TYPES),
            ("condition_immunities", CONDITIONS),
        ):
            for value in monster.get(field) or []:
                check_enum(where, field, value, allowed, problems)
        if not monster.get("actions"):
            problems.at(where, "has no actions and could never act")
        for action in monster.get("actions") or []:
            spot = f"{where} action[{action.get('id')}]"
            check_identity("monsters.json actions", [action], seen_ids, problems)
            require_key(spot, action.get("name_key"))
            check_damage_list(spot, action.get("damage"), problems)
            if "rider_save" in action:
                rider = action["rider_save"]
                check_fields(
                    spot + " rider_save",
                    rider,
                    {"ability": str, "difficulty_class": int,
                     "on_failure_condition": str, "condition_rounds": int},
                    {},
                    problems,
                )
                check_enum(spot, "rider ability", rider.get("ability"), ABILITIES, problems)
                check_enum(
                    spot, "rider condition",
                    rider.get("on_failure_condition"), CONDITIONS, problems,
                )

    # --- Item bases ---------------------------------------------------------
    bases = load(DATA_ROOT / "item_bases.json", "item_bases", problems)
    check_identity("item_bases.json", bases, seen_ids, problems)
    base_ids = {record.get("id") for record in bases}
    declared_groups: set[str] = set()
    for base in bases:
        where = f"item_bases.json[{base.get('id')}]"
        check_prose(where, base, problems)
        check_enum(where, "slot", base.get("slot"), EQUIPMENT_SLOTS, problems)
        require_key(where, base.get("name_key"))
        if base.get("item_level", 0) < 1:
            problems.at(where, "item_level must be at least 1")
        if base.get("value_cp", 0) < 1:
            problems.at(where, "value_cp must be positive")
        groups = base.get("affix_groups") or []
        if not groups:
            problems.at(where, "declares no affix_groups and could never be enchanted")
        declared_groups.update(groups)
        if "damage" in base:
            check_damage_list(where, [base["damage"]], problems)
        # A base is either a weapon (it deals damage) or armour (it grants AC).
        if "damage" not in base and "base_armour_class" not in base \
                and base.get("slot") != "trinket":
            problems.at(where, "has neither damage nor base_armour_class")

    # --- Affixes ------------------------------------------------------------
    affixes = load(DATA_ROOT / "affixes.json", "affixes", problems)
    check_identity("affixes.json", affixes, seen_ids, problems)
    used_groups: set[str] = set()
    for affix in affixes:
        where = f"affixes.json[{affix.get('id')}]"
        check_prose(where, affix, problems)
        check_fields(
            where,
            affix,
            {
                "id": str, "role": str, "name_key": str, "inflected": bool,
                "affix_groups": list, "tier": int, "min_item_level": int,
                "budget_cost": int, "weight": int, "exclusive_group": str, "effects": list,
            },
            {},
            problems,
        )
        check_enum(where, "role", affix.get("role"), frozenset({"prefix", "suffix"}), problems)
        used_groups.update(affix.get("affix_groups") or [])
        if affix.get("budget_cost", 0) < 1:
            problems.at(where, "budget_cost must be positive")
        if affix.get("weight", 0) < 1:
            problems.at(where, "weight must be positive, or it could never be drawn")
        if affix.get("min_item_level", 0) < 1:
            problems.at(where, "min_item_level must be at least 1")
        check_effects(where, affix.get("effects"), problems)

        # The two naming conventions must not drift: an inflected adjective has
        # three gender forms and no plain row, an invariant phrase has exactly
        # the plain row. docs/i18n/LOCALIZATION.md explains why.
        name_key = affix.get("name_key")
        if isinstance(name_key, str):
            if affix.get("inflected"):
                for form in ("MS", "FS", "NS"):
                    require_key(where, f"{name_key}_{form}")
                if name_key in locale_keys:
                    problems.at(
                        where,
                        f"is inflected, so '{name_key}' must not also exist as a plain row",
                    )
            else:
                require_key(where, name_key)
                for form in ("MS", "FS", "NS"):
                    if f"{name_key}_{form}" in locale_keys:
                        problems.at(
                            where,
                            f"is not inflected, so '{name_key}_{form}' must not exist",
                        )

    for orphan in sorted(declared_groups - used_groups):
        problems.at("affixes.json", f"no affix can roll on group '{orphan}' declared by a base")
    for unknown in sorted(used_groups - declared_groups):
        problems.at("affixes.json", f"group '{unknown}' is used by an affix but by no base")

    # --- Uniques ------------------------------------------------------------
    uniques = load(DATA_ROOT / "uniques.json", "uniques", problems)
    check_identity("uniques.json", uniques, seen_ids, problems)
    for unique in uniques:
        where = f"uniques.json[{unique.get('id')}]"
        check_prose(where, unique, problems)
        check_fields(
            where,
            unique,
            {
                "id": str, "base": str, "name_key": str, "rarity": str,
                "min_depth": int, "weight": int, "attunement": bool, "effects": list,
            },
            {},
            problems,
        )
        require_key(where, unique.get("name_key"))
        check_enum(where, "rarity", unique.get("rarity"), RARITIES, problems)
        if unique.get("base") not in base_ids:
            problems.at(where, f"base '{unique.get('base')}' is not a declared item base")
        if unique.get("min_depth", 0) < 1:
            problems.at(where, "min_depth must be at least 1")
        check_effects(where, unique.get("effects"), problems)

    # --- Powers -------------------------------------------------------------
    powers = load(DATA_ROOT / "powers.json", "powers", problems)
    check_identity("powers.json", powers, seen_ids, problems)
    power_ids = {record.get("id") for record in powers}
    for power in powers:
        where = f"powers.json[{power.get('id')}]"
        check_prose(where, power, problems)
        require_key(where, power.get("name_key"))
        require_key(where, power.get("description_key"))
        if power.get("uses_per_encounter", 0) < 1:
            problems.at(where, "uses_per_encounter must be at least 1")
        if "damage" in power:
            check_damage_list(where, power["damage"], problems)
        if "heal" in power:
            check_dice(where, "heal", power["heal"], problems)
        if "condition" in power:
            check_enum(where, "condition", power["condition"], CONDITIONS, problems)
        for field in ("attack_ability", "save_ability"):
            if field in power:
                check_enum(where, field, power[field], ABILITIES, problems)

    # --- Archetypes ---------------------------------------------------------
    archetypes = load(DATA_ROOT / "archetypes.json", "archetypes", problems)
    check_identity("archetypes.json", archetypes, seen_ids, problems)
    for archetype in archetypes:
        where = f"archetypes.json[{archetype.get('id')}]"
        check_prose(where, archetype, problems)
        check_fields(
            where,
            archetype,
            {
                "id": str, "name_key": str, "description_key": str, "abilities": dict,
                "hit_die": str, "proficiency_bonus": int, "attack_ability": str,
                "saving_throw_proficiencies": list, "starting_items": list, "powers": list,
            },
            {},
            problems,
        )
        require_key(where, archetype.get("name_key"))
        require_key(where, archetype.get("description_key"))
        check_dice(where, "hit_die", archetype.get("hit_die"), problems)
        check_enum(
            where, "attack_ability", archetype.get("attack_ability"), ABILITIES, problems,
        )
        if set(archetype.get("abilities") or {}) != ABILITIES:
            problems.at(where, "must declare all six ability scores")
        for item in archetype.get("starting_items") or []:
            if item not in base_ids:
                problems.at(where, f"starting item '{item}' is not a declared item base")
        for power in archetype.get("powers") or []:
            if power not in power_ids:
                problems.at(where, f"power '{power}' is not a declared power")

    # --- Encounter tables ---------------------------------------------------
    tables = load(DATA_ROOT / "encounter_tables.json", "encounter_tables", problems)
    check_identity("encounter_tables.json", tables, seen_ids, problems)
    table_ids = {record.get("id") for record in tables}
    for table in tables:
        where = f"encounter_tables.json[{table.get('id')}]"
        check_prose(where, table, problems)
        for index, entry in enumerate(table.get("entries") or []):
            spot = f"{where} entry[{index}]"
            if entry.get("weight", 0) < 1:
                problems.at(spot, "weight must be positive, or it could never be drawn")
            if not entry.get("groups"):
                problems.at(spot, "has no monster groups and would be an empty encounter")
            for group in entry.get("groups") or []:
                if group.get("monster") not in monster_ids:
                    problems.at(spot, f"monster '{group.get('monster')}' is not declared")
                # A count is either a fixed number or a roll. Both are ordinary:
                # a lone boss is 1, a pack of rats is "2d3".
                count = group.get("count")
                if isinstance(count, bool) or not isinstance(count, (int, str)):
                    problems.at(spot, f"count {count!r} must be an integer or a dice expression")
                elif isinstance(count, int):
                    if not 1 <= count <= 12:
                        problems.at(spot, f"fixed count {count} must be between 1 and 12")
                else:
                    check_dice(spot, "count", count, problems)

    # --- Dungeon themes -----------------------------------------------------
    themes = load(DATA_ROOT / "themes.json", "dungeon_themes", problems)
    check_identity("themes.json", themes, seen_ids, problems)
    covered: set[int] = set()
    deepest = 0
    for theme in themes:
        where = f"themes.json[{theme.get('id')}]"
        check_prose(where, theme, problems)
        check_fields(
            where,
            theme,
            {
                "id": str, "name_key": str, "description_key": str, "depth_range": list,
                "encounter_table": str, "cosmetic_variants": int, "room_weights": dict,
            },
            {},
            problems,
        )
        require_key(where, theme.get("name_key"))
        require_key(where, theme.get("description_key"))
        if theme.get("encounter_table") not in table_ids:
            problems.at(where, f"encounter table '{theme.get('encounter_table')}' is not declared")
        depth_range = theme.get("depth_range") or []
        if len(depth_range) != 2 or not all(isinstance(bound, int) for bound in depth_range):
            problems.at(where, "depth_range must be two integers")
        elif depth_range[0] > depth_range[1] or depth_range[0] < 1:
            problems.at(where, f"depth_range {depth_range} is inverted or starts below 1")
        else:
            covered.update(range(depth_range[0], depth_range[1] + 1))
            deepest = max(deepest, depth_range[1])
        weights = theme.get("room_weights") or {}
        for kind in weights:
            check_enum(where, "room_weights key", kind, ROOM_KINDS, problems)
        if set(weights) != ROOM_KINDS:
            problems.at(where, f"room_weights must declare every kind: {sorted(ROOM_KINDS)}")
        if sum(value for value in weights.values() if isinstance(value, int)) < 1:
            problems.at(where, "room_weights sum to zero, so no room could be chosen")

    # A gap here is a depth the generator could reach and find no theme for,
    # which would strand a run mid-descent.
    missing = sorted(set(range(1, deepest + 1)) - covered)
    if missing:
        problems.at("themes.json", f"no theme covers depth(s) {missing}")

    if problems:
        print("Content data check failed:", file=sys.stderr)
        for problem in sorted(problems):
            print(f"  - {problem}", file=sys.stderr)
        print(
            f"\n{len(problems)} problem(s). Content lives in game/data and every "
            f"player-visible string is a key into game/localization.",
            file=sys.stderr,
        )
        return 1

    print(
        f"Content data is well formed: {len(monsters)} monsters, {len(bases)} item bases, "
        f"{len(affixes)} affixes, {len(uniques)} uniques, {len(powers)} powers, "
        f"{len(archetypes)} archetypes, {len(themes)} themes."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
