extends GutTest
## Tests that the shipped content loads and hangs together.
##
## tools/scripts/check_content.py already proves the files are well formed, and
## proves it without an engine. What it cannot prove is that the engine can read
## them from where they actually live — which is the failure an export filter
## mistake would produce, and one that would otherwise surface only on a device.

var _content: ContentDatabase


func before_each() -> void:
	_content = ContentDatabase.new()


func test_every_content_file_loads() -> void:
	assert_true(_content.is_loaded(), "content failed to load: %s" % ", ".join(_content.failures()))


func test_each_collection_holds_records() -> void:
	for collection: String in ContentDatabase.FILES:
		assert_gt(_content.all(collection).size(), 0, "%s is empty" % collection)


func test_records_are_reachable_by_identifier() -> void:
	for monster: Dictionary in _content.all("monsters"):
		assert_true(_content.has(String(monster["id"])), "%s is not indexed" % monster["id"])


func test_every_depth_has_a_theme() -> void:
	# A gap here would strand a run mid-descent at a depth with nothing to
	# generate from.
	for depth in range(1, _content.deepest_depth() + 1):
		assert_false(_content.theme_for_depth(depth).is_empty(), "no theme covers depth %d" % depth)


func test_a_missing_directory_is_reported_rather_than_crashing() -> void:
	# The editor and a device disagree about what is present far more often than
	# anything else, so an absent file must be a reported failure.
	var absent := ContentDatabase.new("res://data/does_not_exist")
	assert_false(absent.is_loaded())
	assert_gt(absent.failures().size(), 0, "a failure must say what is missing")


func test_an_unknown_identifier_returns_nothing_rather_than_failing() -> void:
	assert_true(_content.by_id("no_such_thing").is_empty())
