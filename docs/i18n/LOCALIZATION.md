# Localisation

DungeonLike ships in English, Italian, Spanish, French and German. English is
the source language and the fallback.

## Where strings live

| Layer | File | Holds |
| --- | --- | --- |
| Game | `game/localization/ui.csv` | Everything the player reads during play |
| Host | `app/src/main/res/values*/strings.xml` | The launcher label, pre-engine errors, accessibility labels |
| Host | `app/src/main/res/xml/locales_config.xml` | The shipped language list, for the per-app language picker |

Almost all text belongs in the game's table. The host owns only what must exist
before the engine runs, which keeps wording changes out of the store-release
path.

## The rules

**All five languages in the same commit.** A string added in English alone will
not fail to build, it will simply ship as English to four fifths of the
audience. `tools/scripts/check_locales.py` fails the build on a missing or empty
translation, and on any disagreement between the five places the language list
is declared.

**Rules terminology follows the official localised editions.** The game's rules
vocabulary derives from the System Reference Document 5.2.1, which is published
in Italian, Spanish, French and German as well as English. Those editions are
the authority for how a rules term is rendered: a player who knows the game in
their language should meet the words they already know. Do not machine-translate
a rules term, and do not invent one when the official edition has an answer.

The documents are not redistributed here; `srd/` is untracked. Obtain them
yourself and keep them out of commits.

**Interface language is not rules language.** Ordinary interface wording —
buttons, settings, error messages — should read naturally in each language
rather than being a literal rendering of the English.

**Some strings are identical in every language on purpose.** The product name
is not translated, and the attribution statement in the credits is reproduced
verbatim in every language because the licence it comes under requires exactly
that wording. Those keys are listed in `UNTRANSLATED_KEYS` in
`tools/scripts/check_locales.py`; the check otherwise treats an untranslated row
as a mistake.

## Practicalities

**Placeholders.** The table uses `%s`-style placeholders, and their order must
be preserved. Where a language needs a different word order, use the positional
form (`%1$s`, `%2$s`) in every language for that key, not only the one that
needs it.

**Length.** German and French run visibly longer than English. Layouts use
containers and wrapping rather than fixed widths, and a new screen should be
checked in German before it is considered done.

**Fallback.** A device set to a language the game does not ship gets English.
`LocaleService` applies this, and the player can override it from the settings
screen or through the system's per-application language picker.

## Adding a language

1. Add the column to `game/localization/ui.csv`.
2. Add `app/src/main/res/values-<code>/strings.xml`.
3. Add the locale to `app/src/main/res/xml/locales_config.xml`.
4. Add the translation file to `locale/translations` in `game/project.godot`.
5. Add the code to `SUPPORTED_LOCALES` in
   `game/scripts/autoload/locale_service.gd`.
6. Add it to `localeFilters` in `app/build.gradle.kts`.

`tools/scripts/check_locales.py` verifies the first five; the sixth keeps the
other languages' resources from being stripped out of the shipped bundle.
