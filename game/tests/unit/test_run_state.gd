extends GutTest
## Tests that a run survives being written to disk and read back.
##
## Resuming is the reason the save exists, and the reason it can be this simple
## is that no generator state is stored: a room's contents are derived from the
## run seed and the room's identifier, so restoring a run re-seeds and replays
## nothing. These tests pin both halves of that — the round trip, and the fact
## that a restored run generates the same rooms as the run it came from.

var _content: ContentDatabase


func before_each() -> void:
	_content = ContentDatabase.new()
	RngService.begin_run_with_seed(_seed(0x5e))


func test_a_run_survives_a_round_trip() -> void:
	var controller := RunController.new(_content)
	controller.start_new_run("shadow")
	var original := controller.state.to_dict()

	var restored := RunState.from_dict(original)
	assert_not_null(restored, "a run written by this build must be readable by it")
	assert_eq(JSON.stringify(restored.to_dict()), JSON.stringify(original))


func test_a_save_of_another_format_is_refused() -> void:
	# Refusing is better than reading half of it and playing on with a run that
	# is subtly wrong in ways nothing would report.
	var controller := RunController.new(_content)
	controller.start_new_run("vanguard")
	var stored := controller.state.to_dict()
	stored["format"] = RunState.FORMAT_VERSION + 1
	assert_null(RunState.from_dict(stored), "a future format must be refused")


func test_a_resumed_run_generates_the_same_rooms() -> void:
	# The property the whole save design rests on. If per-room stream scoping
	# were wrong, this is the test that would catch it.
	var controller := RunController.new(_content)
	controller.start_new_run("runecaster")
	var node_id := controller.available_exits()[0].id
	var node := controller.state.graph.node(node_id)
	var before := LootGenerator.generate(_content, node, node.depth).to_dict()

	var resumed := RunController.new(_content)
	resumed.resume(RunState.from_dict(controller.state.to_dict()))
	var after := LootGenerator.generate(_content, node, node.depth).to_dict()

	assert_eq(JSON.stringify(after), JSON.stringify(before), "a resumed run must not reroll")


func test_equipment_survives_the_round_trip() -> void:
	var controller := RunController.new(_content)
	controller.start_new_run("vanguard")
	var restored := RunState.from_dict(controller.state.to_dict())
	for slot: String in controller.state.equipment:
		assert_not_null(restored.equipped(slot), "%s was lost in the save" % slot)
		assert_eq(restored.equipped(slot).base_id, controller.state.equipped(slot).base_id)


func test_the_finest_find_is_remembered() -> void:
	var state := RunState.new()
	var common := Item.new("dagger")
	var rare := Item.new("longsword")
	rare.rarity = Item.RARITY_RARE
	state.equip(common, "main_hand")
	state.equip(rare, "main_hand")
	assert_eq(state.best_item.rarity, Item.RARITY_RARE)

	# And it must not be forgotten when something worse is picked up later.
	state.equip(Item.new("shortsword"), "main_hand")
	assert_eq(state.best_item.rarity, Item.RARITY_RARE, "a worse item must not displace it")


func test_a_new_run_starts_playable() -> void:
	for archetype: Dictionary in _content.all("archetypes"):
		var controller := RunController.new(_content)
		controller.start_new_run(String(archetype["id"]))
		var state := controller.state
		assert_gt(state.hit_points, 0, "%s starts dead" % archetype["id"])
		assert_eq(state.hit_points, state.max_hit_points, "a run starts at full health")
		assert_ne(state.seed_hex, "", "a run must record its seed")
		assert_gt(controller.available_exits().size(), 0, "there must be somewhere to go")


func _seed(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(RngService.SEED_LENGTH)
	bytes.fill(value)
	return bytes
