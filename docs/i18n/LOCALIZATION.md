# Localisation

DungeonLike ships in English, Italian, Spanish, French and German. English is
the source language and the fallback.

## Where strings live

| Layer | File | Holds |
| --- | --- | --- |
| Game | `game/localization/ui.csv` | Interface wording: screens, buttons, messages |
| Game | `game/localization/rules.csv` | Rules vocabulary and the combat log |
| Game | `game/localization/content.csv` | Monsters, items, affixes, archetypes, themes |
| Host | `app/src/main/res/values*/strings.xml` | The launcher label, pre-engine errors, accessibility labels |
| Host | `app/src/main/res/xml/locales_config.xml` | The shipped language list, for the per-app language picker |

The game's strings are split across three tables because they are reviewed by
different people for different qualities: interface wording should read
naturally, rules vocabulary must match the official localised editions, and
content is flavour that has to be written rather than translated. One file of
several hundred rows cannot be reviewed for any of them. The engine merges the
tables into a single lookup, and `check_locales.py` fails the build if a key is
declared in two of them, which would otherwise shadow one silently.

Almost all text belongs in the game's tables. The host owns only what must exist
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

## Generated names

Item names are assembled from parts — a base noun, an adjective before or after
it, and a phrase after that — and the five shipped languages agree about none of
it. English and German put the adjective first; Italian, Spanish and French put
it last. Italian, Spanish and French inflect it for the noun's gender; German
inflects it too, with different endings; English does not inflect it at all.

None of that is decided in code. Three things in the tables decide it, so a
wrong name is fixed by a translator rather than by a programmer:

**Word order** is an `ITEM_NAME_*` row per language. `{0}` is always the base
noun, `{1}` the prefix, `{2}` the suffix:

| key | en | it |
| --- | --- | --- |
| `ITEM_NAME_PREFIX_SUFFIX` | `{1} {0} {2}` | `{0} {1} {2}` |

**Gender** is a `_GRAMMAR` row beside each base noun, holding a tag such as `ms`,
`fs` or `ns`. It belongs to the *translation*, not to the item: a longsword is
feminine in Italian and neuter in German, so the tag differs per language just
as the noun does.

**Inflection** is three rows per prefix adjective, one per gender form, suffixed
`_MS`, `_FS` and `_NS`. English repeats itself across all three, which costs
nothing and keeps the lookup uniform. German's three are the strong-declension
nominative endings.

**Suffixes are complete noun phrases** — `of the Bear`, `dell'Orso`, `des Bären`
— and never agree with anything. That is a constraint on the content rather than
a limitation of the code, and it is what keeps French elision and the Italian
and Spanish article contractions in a translator's hands instead of in a runtime
grammar engine. There is no runtime grammar engine, and there should not be one.

`tools/scripts/check_content.py` enforces the two conventions against each
other: an affix declared `inflected` must have all three forms and no plain row,
and one declared not inflected must have the plain row and none of the forms.

## Practicalities

**Placeholders.** The two stacks do not share a convention, and using the wrong
one fails silently rather than loudly.

The **game tables** use `{0}`, `{1}` and so on, applied with
`String.format()`:

```gdscript
tr("LOG_ATTACK_HIT").format([attacker, defender, amount])
```

The numbers are indices into the array, so a language may use them in any order
— which is the whole point, and the reason a single-value row may still be
written with a plain `%s` and applied with `%`.

GDScript's `%` operator has **no positional specifiers**. A row written `%1$s`
is not an error: `%` leaves it exactly as it found it, and the player reads
`%1$s` in the middle of a sentence. `tools/scripts/check_locales.py` cannot see
this, so `game/tests/unit/test_localisation_placeholders.gd` renders every row
in every language and fails on any placeholder left unfilled.

The **Android host** resources in `res/values*/strings.xml` keep the platform's
own positional form, `%1$s` and `%2$s`, because that is what Android's resource
formatting expects. Do not carry either convention across to the other stack.

**Length.** German and French run visibly longer than English. Layouts use
containers and wrapping rather than fixed widths, and a new screen should be
checked in German before it is considered done.

**Fallback.** A device set to a language the game does not ship gets English.
`LocaleService` applies this, and the player can override it from the settings
screen or through the system's per-application language picker.

## Adding a language

1. Add the column to every table in `game/localization/`.
2. Add `app/src/main/res/values-<code>/strings.xml`.
3. Add the locale to `app/src/main/res/xml/locales_config.xml`.
4. Add each table's translation file to `locale/translations` in
   `game/project.godot`.
5. Add the code to `SUPPORTED_LOCALES` in
   `game/scripts/autoload/locale_service.gd`.
6. Add it to `localeFilters` in `app/build.gradle.kts`.

`tools/scripts/check_locales.py` verifies the first five; the sixth keeps the
other languages' resources from being stripped out of the shipped bundle.
