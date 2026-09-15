extends GutTest
## Tests that a generated item has a readable name in every shipped language.
##
## This is the suite that guards the hardest part of the localisation: a name is
## assembled from a base noun, an adjective that must agree with it, and a
## phrase, and the five languages disagree about order and about inflection. A
## mistake here does not crash — it puts a raw AFFIX_FLAMING_FS on screen, or
## silently prints the masculine form of an adjective beside a feminine noun,
## and only a speaker of that language would ever notice.

var _content: ContentDatabase
var _original_locale := ""


func before_each() -> void:
	_content = ContentDatabase.new()
	_original_locale = LocaleService.current_locale()
	RngService.begin_run_with_seed(_seed(0x77))


func after_each() -> void:
	# The locale is global engine state; leaving a test's choice in place would
	# make every later test depend on the order it ran in.
	LocaleService.apply_locale(_original_locale)


func test_every_generated_name_is_readable_in_every_language() -> void:
	for locale in LocaleService.SUPPORTED_LOCALES:
		LocaleService.apply_locale(locale)
		for index in range(120):
			var node := MapNode.new("name-%d" % index, 5, 0)
			var item := LootGenerator.generate(_content, node, 5)
			if item == null:
				continue
			var name := ItemNaming.display_name(item, _content)
			assert_false(name.strip_edges().is_empty(), "empty name in %s" % locale)
			assert_false(
				name.contains("AFFIX_") or name.contains("ITEM_BASE_") or name.contains("UNIQUE_"),
				"untranslated key reached the player in %s: %s" % [locale, name]
			)
			assert_false(name.contains("  "), "doubled space in %s: '%s'" % [locale, name])
			assert_eq(name, name.strip_edges(), "stray whitespace in %s: '%s'" % [locale, name])


func test_every_inflected_affix_has_all_three_forms_in_every_language() -> void:
	for locale in LocaleService.SUPPORTED_LOCALES:
		LocaleService.apply_locale(locale)
		for affix: Dictionary in _content.all("affixes"):
			if not bool(affix.get("inflected", false)):
				continue
			for form in ["MS", "FS", "NS"]:
				var key := "%s_%s" % [String(affix["name_key"]), form]
				assert_ne(tr(key), key, "%s is missing in %s" % [key, locale])


func test_every_base_declares_a_gender_in_every_language() -> void:
	for locale in LocaleService.SUPPORTED_LOCALES:
		LocaleService.apply_locale(locale)
		for base: Dictionary in _content.all("item_bases"):
			var key := String(base["name_key"]) + "_GRAMMAR"
			var tag := tr(key)
			assert_ne(tag, key, "%s is missing in %s" % [key, locale])
			assert_true(
				tag in ["ms", "fs", "ns", "mp", "fp", "np"],
				"%s is '%s' in %s, which is not a grammar tag" % [key, tag, locale]
			)


func test_the_adjective_agrees_with_a_feminine_noun() -> void:
	# A longsword is feminine in Italian and neuter in German, so the same affix
	# must produce a different word in each. If the gender lookup were ignored,
	# both would take the masculine form and this would fail.
	LocaleService.apply_locale("it")
	var feminine := _named("longsword", "flaming")
	var masculine := _named("quarterstaff", "flaming")
	assert_ne(feminine, masculine, "Italian must inflect the adjective for gender")


func test_word_order_differs_between_languages() -> void:
	# English puts the adjective first, Italian puts it last. Both read from the
	# same pattern row, so if the pattern were ignored these would match.
	# Each expectation is read while its own locale is active. Reading both at
	# the end would compare the English name against the Italian adjective,
	# because tr() answers for whichever locale is current when it is called.
	LocaleService.apply_locale("en")
	var english := _named("longsword", "flaming")
	var english_adjective := tr("AFFIX_FLAMING_NS")

	LocaleService.apply_locale("it")
	var italian := _named("longsword", "flaming")
	var italian_adjective := tr("AFFIX_FLAMING_FS")

	assert_true(english.begins_with(english_adjective), "English preposes the adjective")
	assert_false(italian.begins_with(italian_adjective), "Italian postposes the adjective")


func test_a_unique_uses_its_own_name_and_no_pattern() -> void:
	var item := Item.new("dagger")
	item.unique_id = "emberfang"
	for locale in LocaleService.SUPPORTED_LOCALES:
		LocaleService.apply_locale(locale)
		assert_eq(ItemNaming.display_name(item, _content), tr("UNIQUE_EMBERFANG"))


func _named(base_id: String, prefix_id: String) -> String:
	var item := Item.new(base_id)
	item.prefix_id = prefix_id
	return ItemNaming.display_name(item, _content)


func _seed(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(RngService.SEED_LENGTH)
	bytes.fill(value)
	return bytes
