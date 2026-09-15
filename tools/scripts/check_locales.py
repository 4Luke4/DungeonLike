#!/usr/bin/env python3
"""Verify that the shipped languages agree everywhere, and that none is short.

DungeonLike ships five languages across two technology stacks: the Android host
declares them as resource qualifiers and a locale configuration, and the game
core declares them in a translation table, in the engine project settings and in
a service constant. A language added to one and forgotten in another does not
fail any build — it simply ships as English to some players and as a missing
string to others.

Checks performed:

* every declaration site lists exactly the same locales;
* every key in every translation table has a non-empty value in every language;
* no key is declared in two tables, which would shadow one of them silently;
* every _GRAMMAR row holds a grammar tag rather than prose;
* every string in the Android default resources exists in every translated one.

Exits non-zero, listing every problem found.
"""

from __future__ import annotations

import csv
import re
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]

LOCALES_CONFIG = REPOSITORY_ROOT / "app" / "src" / "main" / "res" / "xml" / "locales_config.xml"
ANDROID_RES = REPOSITORY_ROOT / "app" / "src" / "main" / "res"
LOCALIZATION_ROOT = REPOSITORY_ROOT / "game" / "localization"
GODOT_PROJECT = REPOSITORY_ROOT / "game" / "project.godot"
LOCALE_SERVICE = REPOSITORY_ROOT / "game" / "scripts" / "autoload" / "locale_service.gd"

# The Android default resource directory holds the untranslated language.
DEFAULT_LOCALE = "en"

# Keys whose value is intentionally identical in every language. The attribution
# statement is reproduced verbatim under the terms of the licence it comes with,
# so translating it would be a licence violation rather than a courtesy.
UNTRANSLATED_KEYS = frozenset({"CREDITS_SRD_ATTRIBUTION", "MENU_TITLE", "CREDITS_GAME_HEADING"})

# Item names are assembled from parts, and these rows carry the word order for
# each language rather than any words of their own. Several are identical across
# languages simply because several languages order the parts the same way; that
# is the correct answer, not a missing translation.
# docs/i18n/LOCALIZATION.md explains the scheme.
NAME_PATTERN_PREFIX = "ITEM_NAME_"

# A _GRAMMAR row records the grammatical gender of the translation beside it, so
# that a prefix adjective can agree with the noun it qualifies. Its value is a
# tag, not prose, and two languages agreeing on a gender is ordinary.
GRAMMAR_SUFFIX = "_GRAMMAR"
GRAMMAR_TAG = re.compile(r"^(m|f|n)(s|p)$")


def declared_in_locales_config() -> list[str]:
    root = ElementTree.parse(LOCALES_CONFIG).getroot()
    namespace = "{http://schemas.android.com/apk/res/android}"
    return [element.attrib[f"{namespace}name"] for element in root.findall("locale")]


def declared_in_android_resources() -> list[str]:
    locales = [DEFAULT_LOCALE]
    for directory in sorted(ANDROID_RES.glob("values-*")):
        suffix = directory.name.removeprefix("values-")
        # Resource qualifiers cover far more than language (density, night mode,
        # screen size). Only the two-letter language directories are locales.
        if re.fullmatch(r"[a-z]{2}", suffix):
            locales.append(suffix)
    return locales


def translation_tables() -> list[Path]:
    """Every translation table, in a stable order.

    The strings are split across several tables — interface, rules vocabulary
    and content — so that a reviewer can read one domain at a time instead of a
    single file of several hundred rows. Every table has the same shape and the
    same rules apply to all of them.
    """
    return sorted(LOCALIZATION_ROOT.glob("*.csv"))


def declared_in_translation_tables() -> list[str]:
    """The locale columns, which must be identical in every table."""
    headers = set()
    for table in translation_tables():
        with table.open(encoding="utf-8", newline="") as handle:
            headers.add(tuple(next(csv.reader(handle))[1:]))
    if len(headers) != 1:
        # Reported as a disagreement by the caller; returning one of them keeps
        # the comparison meaningful.
        return sorted(sorted(headers)[0]) if headers else []
    return list(headers.pop())


def declared_in_godot_project() -> list[str]:
    text = GODOT_PROJECT.read_text(encoding="utf-8")
    match = re.search(r"^locale/translations=PackedStringArray\((.*)\)$", text, re.MULTILINE)
    if match is None:
        return []
    return sorted({locale for _, locale in re.findall(r"([a-z_]+)\.([a-z]{2})\.translation", match.group(1))})


def declared_in_locale_service() -> list[str]:
    text = LOCALE_SERVICE.read_text(encoding="utf-8")
    match = re.search(r"^const SUPPORTED_LOCALES: PackedStringArray = \[(.*)\]$", text, re.MULTILINE)
    if match is None:
        return []
    return re.findall(r'"([a-z]{2})"', match.group(1))


def android_strings(locale: str) -> dict[str, str]:
    directory = ANDROID_RES / ("values" if locale == DEFAULT_LOCALE else f"values-{locale}")
    path = directory / "strings.xml"
    if not path.is_file():
        return {}
    root = ElementTree.parse(path).getroot()
    return {element.attrib["name"]: (element.text or "") for element in root.findall("string")}


def main() -> int:
    problems: list[str] = []

    expected = declared_in_locales_config()
    if not expected:
        print("app/src/main/res/xml/locales_config.xml declares no locales.", file=sys.stderr)
        return 1

    sites = {
        "app/src/main/res/values-*": declared_in_android_resources(),
        "game/localization/*.csv": declared_in_translation_tables(),
        "game/project.godot": declared_in_godot_project(),
        "game/scripts/autoload/locale_service.gd": declared_in_locale_service(),
    }
    for name, declared in sites.items():
        if sorted(declared) != sorted(expected):
            problems.append(
                f"{name} declares {sorted(declared)} but locales_config.xml declares {sorted(expected)}."
            )

    # A key must be unique across every table, not merely within one of them:
    # the engine merges them into a single lookup, so a duplicate would silently
    # shadow whichever table happened to load second.
    seen_keys: dict[str, str] = {}

    for table in translation_tables():
        name = table.name
        with table.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))

        for row in rows:
            key = (row.get("keys") or "").strip()
            if not key:
                problems.append(f"{name} contains a row with no key.")
                continue
            if key in seen_keys:
                problems.append(f"{name}: key '{key}' is already declared in {seen_keys[key]}.")
            else:
                seen_keys[key] = name

            for locale in expected:
                value = (row.get(locale) or "").strip()
                if not value:
                    problems.append(f"{name}: key '{key}' has no {locale} translation.")

            if key.endswith(GRAMMAR_SUFFIX):
                # Not prose but a grammatical tag, and languages legitimately
                # agree on gender, so the identical-value rule does not apply.
                for locale in expected:
                    value = (row.get(locale) or "").strip()
                    if value and not GRAMMAR_TAG.fullmatch(value):
                        problems.append(
                            f"{name}: key '{key}' has {locale} value '{value}', which is not a "
                            f"grammar tag such as 'ms', 'fs' or 'ns'."
                        )
                continue

            if key.startswith(NAME_PATTERN_PREFIX) or key in UNTRANSLATED_KEYS:
                continue

            values = {(row.get(locale) or "").strip() for locale in expected}
            if len(values) == 1 and len(expected) > 1:
                problems.append(
                    f"{name}: key '{key}' is identical in every language. If that is intended, "
                    f"add it to UNTRANSLATED_KEYS in this script with the reason."
                )

    reference = android_strings(DEFAULT_LOCALE)
    for locale in expected:
        if locale == DEFAULT_LOCALE:
            continue
        translated = android_strings(locale)
        # The application name is the product name and is deliberately not
        # translated, so it exists only in the default resources.
        missing = set(reference) - set(translated) - {"app_name"}
        if missing:
            problems.append(f"values-{locale}/strings.xml is missing: {', '.join(sorted(missing))}.")
        unknown = set(translated) - set(reference)
        if unknown:
            problems.append(
                f"values-{locale}/strings.xml defines strings the default resources do not: "
                f"{', '.join(sorted(unknown))}."
            )

    if problems:
        print("Localisation check failed:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"Locales {', '.join(expected)} are declared consistently and fully translated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
