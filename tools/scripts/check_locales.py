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
* every key in the translation table has a non-empty value in every language;
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
TRANSLATION_TABLE = REPOSITORY_ROOT / "game" / "localization" / "ui.csv"
GODOT_PROJECT = REPOSITORY_ROOT / "game" / "project.godot"
LOCALE_SERVICE = REPOSITORY_ROOT / "game" / "scripts" / "autoload" / "locale_service.gd"

# The Android default resource directory holds the untranslated language.
DEFAULT_LOCALE = "en"

# Keys whose value is intentionally identical in every language. The attribution
# statement is reproduced verbatim under the terms of the licence it comes with,
# so translating it would be a licence violation rather than a courtesy.
UNTRANSLATED_KEYS = frozenset({"CREDITS_SRD_ATTRIBUTION", "MENU_TITLE", "CREDITS_GAME_HEADING"})


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


def declared_in_translation_table() -> list[str]:
    with TRANSLATION_TABLE.open(encoding="utf-8", newline="") as handle:
        header = next(csv.reader(handle))
    return header[1:]


def declared_in_godot_project() -> list[str]:
    text = GODOT_PROJECT.read_text(encoding="utf-8")
    match = re.search(r"^locale/translations=PackedStringArray\((.*)\)$", text, re.MULTILINE)
    if match is None:
        return []
    return re.findall(r"ui\.([a-z]{2})\.translation", match.group(1))


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
        "game/localization/ui.csv": declared_in_translation_table(),
        "game/project.godot": declared_in_godot_project(),
        "game/scripts/autoload/locale_service.gd": declared_in_locale_service(),
    }
    for name, declared in sites.items():
        if sorted(declared) != sorted(expected):
            problems.append(
                f"{name} declares {sorted(declared)} but locales_config.xml declares {sorted(expected)}."
            )

    with TRANSLATION_TABLE.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))

    for row in rows:
        key = (row.get("keys") or "").strip()
        if not key:
            problems.append("game/localization/ui.csv contains a row with no key.")
            continue
        for locale in expected:
            value = (row.get(locale) or "").strip()
            if not value:
                problems.append(f"ui.csv: key '{key}' has no {locale} translation.")
        if key not in UNTRANSLATED_KEYS:
            values = {(row.get(locale) or "").strip() for locale in expected}
            if len(values) == 1 and len(expected) > 1:
                problems.append(
                    f"ui.csv: key '{key}' is identical in every language. If that is intended, "
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
