extends GutTest
## Tests for language selection.

var _original_locale := ""


func before_each() -> void:
	_original_locale = LocaleService.current_locale()


func after_each() -> void:
	# The locale is global engine state; leaving a test's choice in place would
	# make later tests depend on the order they ran in.
	LocaleService.apply_locale(_original_locale)


func test_ships_exactly_the_five_supported_languages() -> void:
	# Must stay in step with app/src/main/res/values-*/ and
	# game/localization/ui.csv; tools/scripts/check_locales.py enforces the rest.
	assert_eq(
		Array(LocaleService.available_locales()),
		["en", "it", "es", "fr", "de"]
	)


func test_a_supported_locale_is_applied() -> void:
	LocaleService.apply_locale("de")
	assert_eq(LocaleService.current_locale(), "de")


func test_an_unsupported_locale_falls_back_to_english() -> void:
	# A device set to a language the game does not ship must still be playable.
	LocaleService.apply_locale("ja")
	assert_eq(LocaleService.current_locale(), LocaleService.FALLBACK_LOCALE)


func test_the_chosen_locale_is_remembered() -> void:
	LocaleService.apply_locale("fr")
	assert_eq(
		SettingsService.get_value(LocaleService.SETTING_SECTION, LocaleService.SETTING_KEY, ""),
		"fr"
	)
