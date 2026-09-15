extends GutTest
## Tests that every placeholder in every translation table is substituted.
##
## This suite exists because a placeholder that is never filled in does not
## crash, does not log, and does not fail any other test: it reaches the player
## as literal text in the middle of a sentence. That is exactly what happened
## when these tables were first written with the Android convention — GDScript's
## % operator has no positional specifiers, so every row carrying more than one
## value rendered as its own template.
##
## The tables are read from disk rather than listed here, so a row added later
## is covered without anyone remembering to add it.

## Where the tables live, relative to the project.
const TABLE_DIRECTORY := "res://localization"

var _original_locale := ""


func before_each() -> void:
	_original_locale = LocaleService.current_locale()


func after_each() -> void:
	LocaleService.apply_locale(_original_locale)


func test_every_placeholder_is_substituted_in_every_language() -> void:
	var keys := _keys_with_placeholders()
	assert_gt(keys.size(), 0, "no rows with placeholders were found; is the path right?")

	for locale in LocaleService.SUPPORTED_LOCALES:
		LocaleService.apply_locale(locale)
		for key: String in keys:
			var template := tr(key)
			var filled := template.format(_arguments_for(int(keys[key])))
			assert_false(
				filled.contains("{"),
				"%s leaves a placeholder unfilled in %s: '%s'" % [key, locale, filled]
			)


func test_a_row_uses_the_same_placeholders_in_every_language() -> void:
	# A translator who drops a placeholder loses the value it carried, and one
	# who adds a number nothing supplies leaves braces on screen. Neither fails
	# anything else.
	for key: String in _keys_with_placeholders():
		var counts := {}
		for locale in LocaleService.SUPPORTED_LOCALES:
			LocaleService.apply_locale(locale)
			counts[locale] = _placeholder_count(tr(key))
		var distinct := {}
		for locale: String in counts:
			distinct[counts[locale]] = true
		assert_eq(
			distinct.size(), 1, "%s uses a different number of placeholders per language" % key
		)


## Every key that carries at least one placeholder, mapped to how many.
##
## Read from the English column of each table, which is the source language.
func _keys_with_placeholders() -> Dictionary:
	var found := {}
	for file_name in DirAccess.get_files_at(TABLE_DIRECTORY):
		if not file_name.ends_with(".csv"):
			continue
		var handle := FileAccess.open(TABLE_DIRECTORY.path_join(file_name), FileAccess.READ)
		if handle == null:
			continue
		var header := handle.get_csv_line()
		var english := Array(header).find("en")
		while not handle.eof_reached():
			var row := handle.get_csv_line()
			if row.size() <= english or String(row[0]).is_empty():
				continue
			var count := _placeholder_count(String(row[english]))
			if count > 0:
				found[String(row[0])] = count
		handle.close()
	return found


## How many arguments a template needs, which is its highest index plus one.
##
## Counting a consecutive run from zero would be wrong: a row may legitimately
## skip an index. ITEM_NAME_SUFFIX is "{0} {2}", because the caller always
## passes base, prefix and suffix in that order and this row wants the first and
## the third.
func _placeholder_count(template: String) -> int:
	var highest := -1
	for index in range(10):
		if template.contains("{%d}" % index):
			highest = index
	return highest + 1


func _arguments_for(count: int) -> Array:
	var values: Array = []
	for index in range(count):
		values.append("value%d" % index)
	return values
