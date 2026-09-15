extends GutTest
## Tests for generated loot.
##
## The budget and the exclusivity rules are what keep generation from producing
## an item with four stacked versions of the same bonus. They are enforced while
## drawing, so nothing downstream would notice if they stopped working; these
## assertions are the only thing that would.

var _content: ContentDatabase
var _node: MapNode


func before_each() -> void:
	_content = ContentDatabase.new()
	RngService.begin_run_with_seed(_seed(0x63))
	_node = MapNode.new("node-3-1", 3, 1)
	_node.kind = MapNode.KIND_TREASURE


func test_an_item_is_generated() -> void:
	var item := LootGenerator.generate(_content, _node, 3)
	assert_not_null(item, "a treasure room must produce something")
	assert_true(_content.has(item.base_id), "the base must be a declared item")


func test_the_same_room_always_holds_the_same_item() -> void:
	# The property per-room stream scoping exists for: entering a room after a
	# reload must not reroll what is in it.
	RngService.begin_run_with_seed(_seed(0x63))
	var first := LootGenerator.generate(_content, _node, 3).to_dict()
	RngService.begin_run_with_seed(_seed(0x63))
	var second := LootGenerator.generate(_content, _node, 3).to_dict()
	assert_eq(JSON.stringify(first), JSON.stringify(second))


func test_two_rooms_hold_different_items() -> void:
	var other := MapNode.new("node-3-2", 3, 2)
	var first := LootGenerator.generate(_content, _node, 3)
	var second := LootGenerator.generate(_content, other, 3)
	assert_ne(
		JSON.stringify(first.to_dict()),
		JSON.stringify(second.to_dict()),
		"two rooms scoped separately must not produce identical loot"
	)


func test_affix_count_never_exceeds_what_rarity_allows() -> void:
	for index in range(150):
		var node := MapNode.new("loot-%d" % index, 4, 0)
		var item := LootGenerator.generate(_content, node, 4)
		if item == null or item.is_unique():
			continue
		var affixes := 0
		if not item.prefix_id.is_empty():
			affixes += 1
		if not item.suffix_id.is_empty():
			affixes += 1
		var allowed := int(LootGenerator.RARITY_RULES[item.rarity]["affixes"])
		assert_lte(affixes, allowed, "%s carries more affixes than its rarity allows" % item.rarity)


func test_a_common_item_carries_no_affixes() -> void:
	for index in range(150):
		var node := MapNode.new("common-%d" % index, 2, 0)
		var item := LootGenerator.generate(_content, node, 2)
		if item == null or item.is_unique() or item.rarity != Item.RARITY_COMMON:
			continue
		assert_eq(item.prefix_id, "", "a common item has no prefix")
		assert_eq(item.suffix_id, "", "a common item has no suffix")


func test_no_affix_lands_on_an_item_it_does_not_fit() -> void:
	for index in range(150):
		var node := MapNode.new("fit-%d" % index, 5, 0)
		var item := LootGenerator.generate(_content, node, 5)
		if item == null or item.is_unique():
			continue
		var groups: Array = _content.by_id(item.base_id).get("affix_groups", [])
		for affix_id in [item.prefix_id, item.suffix_id]:
			if String(affix_id).is_empty():
				continue
			var affix := _content.by_id(String(affix_id))
			var shares := false
			for group: Variant in affix.get("affix_groups", []):
				if String(group) in groups:
					shares = true
			assert_true(shares, "%s cannot legally roll on %s" % [affix_id, item.base_id])
			assert_lte(
				int(affix.get("min_item_level", 1)),
				item.item_level,
				"%s rolled below its level requirement" % affix_id
			)


func test_no_unique_appears_below_its_depth() -> void:
	# Collected and asserted as a whole rather than asserted inside the loop:
	# at depth one there may legitimately be no unique at all, and a loop whose
	# body never runs is a test that passes without checking anything.
	var too_shallow: Array[String] = []
	for index in range(200):
		var node := MapNode.new("shallow-%d" % index, 1, 0)
		var item := LootGenerator.generate(_content, node, 1)
		if item == null or not item.is_unique():
			continue
		if int(_content.by_id(item.unique_id).get("min_depth", 1)) > 1:
			too_shallow.append(item.unique_id)
	assert_eq(too_shallow, [], "a unique dropped shallower than its declared depth")


func test_rarity_frequencies_are_close_to_their_weights() -> void:
	# Statistical but not flaky: the seed is fixed, so this is a deterministic
	# value. The tolerance guards against a biased implementation and against
	# content tuning, not against sampling noise — a failure here is always a
	# real regression.
	var counts := {}
	var generated := 0
	for index in range(600):
		var node := MapNode.new("dist-%d" % index, 4, 0)
		var item := LootGenerator.generate(_content, node, 4)
		if item == null or item.is_unique():
			continue
		counts[item.rarity] = int(counts.get(item.rarity, 0)) + 1
		generated += 1

	assert_gt(generated, 400, "the sample must be large enough to mean anything")
	for rarity in Item.RARITY_ORDER:
		var expected := float(LootGenerator.RARITY_RULES[rarity]["weight"]) / 100.0
		var actual := float(int(counts.get(rarity, 0))) / float(generated)
		assert_almost_eq(actual, expected, 0.08, "%s is drawn at the wrong rate" % rarity)


func _seed(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(RngService.SEED_LENGTH)
	bytes.fill(value)
	return bytes
