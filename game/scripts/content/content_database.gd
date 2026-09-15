class_name ContentDatabase
extends RefCounted
## Everything the game is made of, read once from game/data.
##
## The files are validated in continuous integration by
## tools/scripts/check_content.py, which proves that every identifier is unique,
## every cross-reference resolves and every localisation key exists. This class
## therefore trusts the shape of what it reads and concerns itself with indexing
## and lookup instead of with re-validating. What it does still check is that
## the files are [i]there[/i]: an export that dropped them would otherwise
## surface as a run that generates nothing.
##
## It is a plain object rather than an autoload, and it takes the directory to
## read as a parameter. That is what lets a test build one over a fixture
## directory and get a hermetic failure, instead of every test in the suite
## sharing one global and having to put it back afterwards.
##
## The files are read with [method FileAccess.get_file_as_string] rather than
## with [method @GDScript.load]. JSON is not an engine resource type, and the
## export preset carries an explicit include filter to put these files in the
## pack at all; reading them as plain text is the access that matches.

## Where the shipped content lives.
const DEFAULT_ROOT := "res://data"

## Each file, and the array inside it that holds the records.
const FILES := {
	"monsters": "monsters.json",
	"item_bases": "item_bases.json",
	"affixes": "affixes.json",
	"uniques": "uniques.json",
	"powers": "powers.json",
	"archetypes": "archetypes.json",
	"encounter_tables": "encounter_tables.json",
	"dungeon_themes": "themes.json",
}

var _root: String
var _by_collection: Dictionary = {}
var _by_id: Dictionary = {}
var _failures: PackedStringArray = PackedStringArray()


func _init(root: String = DEFAULT_ROOT) -> void:
	_root = root
	for collection: String in FILES:
		_load_collection(collection, FILES[collection])


## Whether every file loaded. False means the game cannot start a run.
func is_loaded() -> bool:
	return _failures.is_empty()


## Why loading failed, for the boot screen to report.
func failures() -> PackedStringArray:
	return _failures


## Every record in [param collection], in file order.
##
## File order is the draw order, and it must stay stable: a weighted pick walks
## this array, so reordering the file would change what an existing seed
## generates. Arrays rather than dictionaries for exactly that reason.
func all(collection: String) -> Array:
	return _by_collection.get(collection, [])


## One record by its identifier, or an empty dictionary if there is none.
func by_id(identifier: String) -> Dictionary:
	return _by_id.get(identifier, {})


## Whether [param identifier] names a record.
func has(identifier: String) -> bool:
	return _by_id.has(identifier)


## Every record in [param collection] for which [param predicate] returns true,
## preserving file order.
func filtered(collection: String, predicate: Callable) -> Array:
	var matches: Array = []
	for record: Dictionary in all(collection):
		if predicate.call(record):
			matches.append(record)
	return matches


## The dungeon theme covering [param depth], or an empty dictionary.
func theme_for_depth(depth: int) -> Dictionary:
	for theme: Dictionary in all("dungeon_themes"):
		var range_bounds: Array = theme.get("depth_range", [])
		if (
			range_bounds.size() == 2
			and depth >= int(range_bounds[0])
			and depth <= int(range_bounds[1])
		):
			return theme
	return {}


## The deepest depth any theme covers, which is where the descent ends.
func deepest_depth() -> int:
	var deepest := 0
	for theme: Dictionary in all("dungeon_themes"):
		var range_bounds: Array = theme.get("depth_range", [])
		if range_bounds.size() == 2:
			deepest = maxi(deepest, int(range_bounds[1]))
	return deepest


func _load_collection(collection: String, file_name: String) -> void:
	var path := _root.path_join(file_name)
	if not FileAccess.file_exists(path):
		_failures.append("%s is missing" % path)
		return

	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_failures.append("%s is empty" % path)
		return

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s is not a JSON object" % path)
		return

	var document: Dictionary = parsed
	var records: Variant = document.get(collection)
	if typeof(records) != TYPE_ARRAY:
		_failures.append("%s has no '%s' array" % [path, collection])
		return

	var typed_records: Array = []
	for record: Variant in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = record
		typed_records.append(entry)
		var identifier := String(entry.get("id", ""))
		if not identifier.is_empty():
			_by_id[identifier] = entry
	_by_collection[collection] = typed_records
