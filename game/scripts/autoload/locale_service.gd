extends Node
## Language selection.
##
## The game ships in five languages and the player may want one that is not the
## device language, so the choice is stored per player rather than read from the
## system on every launch. Until they choose, the device language decides, and
## anything unsupported falls back to English.

## Emitted after the locale changes, so open screens can re-read their text.
signal locale_changed(locale: String)

## Locales the game ships. Must stay in step with `game/localization/ui.csv`,
## with the Android host's `res/values-*` directories and with
## `res/xml/locales_config.xml`; `tools/scripts/check_locales.py` enforces that.
const SUPPORTED_LOCALES: PackedStringArray = ["en", "it", "es", "fr", "de"]

## Used when the device language is not one the game ships.
const FALLBACK_LOCALE := "en"

const SETTING_SECTION := "language"
const SETTING_KEY := "locale"


func _ready() -> void:
	apply_locale(_stored_or_device_locale())


## Locales the player can choose between.
func available_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES


## The locale in force, as a two-letter code.
func current_locale() -> String:
	return TranslationServer.get_locale().substr(0, 2)


## Applies [param locale], falling back to English if it is not shipped, and
## remembers the choice.
func apply_locale(locale: String) -> void:
	var resolved := locale if locale in SUPPORTED_LOCALES else FALLBACK_LOCALE
	TranslationServer.set_locale(resolved)
	SettingsService.set_value(SETTING_SECTION, SETTING_KEY, resolved)
	locale_changed.emit(resolved)


## The player's stored choice, or the device language, or English.
##
## [method OS.get_locale_language] returns the language part only, which is what
## is wanted here: a Swiss French device should get French, not fall through to
## English because the region differs.
func _stored_or_device_locale() -> String:
	var stored: String = SettingsService.get_value(SETTING_SECTION, SETTING_KEY, "")
	if stored in SUPPORTED_LOCALES:
		return stored
	return OS.get_locale_language()
