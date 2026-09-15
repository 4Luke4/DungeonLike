extends GutTest
## Tests for the generated map.
##
## Two of these are the properties the generator promises rather than hopes for.
## A room the player can see and cannot reach reads as a bug however deliberate
## it might be, and a descent that cannot be finished is worse than a hard one.
## Both are easy to break with a small change to how columns are joined, and
## neither would fail loudly at runtime.

var _content: ContentDatabase


func before_each() -> void:
	_content = ContentDatabase.new()
	RngService.begin_run_with_seed(_seed(0x31))


func test_the_map_runs_from_a_start_to_a_boss() -> void:
	var graph := DungeonBuilder.build(_content)
	assert_ne(graph.entry_id(), "", "the map needs somewhere to start")
	assert_ne(graph.boss_id(), "", "the map needs somewhere to end")
	assert_eq(graph.node(graph.entry_id()).kind, MapNode.KIND_START)
	assert_eq(graph.node(graph.boss_id()).kind, MapNode.KIND_BOSS)


func test_every_room_is_reachable_from_the_start() -> void:
	for seed_byte in [0x01, 0x40, 0x7f, 0xc0, 0xfe]:
		RngService.begin_run_with_seed(_seed(seed_byte))
		var graph := DungeonBuilder.build(_content)
		var reachable := graph.reachable_from_entry()
		for node in graph.nodes():
			assert_has(
				Array(reachable), node.id, "%s is stranded with seed %d" % [node.id, seed_byte]
			)


func test_the_boss_is_reachable_from_the_start() -> void:
	for seed_byte in [0x01, 0x40, 0x7f, 0xc0, 0xfe]:
		RngService.begin_run_with_seed(_seed(seed_byte))
		var graph := DungeonBuilder.build(_content)
		assert_has(
			Array(graph.reachable_from_entry()),
			graph.boss_id(),
			"the descent cannot be finished with seed %d" % seed_byte
		)


func test_rooms_only_ever_lead_downward() -> void:
	# What makes the map a series of decisions rather than somewhere to wander
	# back and grind.
	var graph := DungeonBuilder.build(_content)
	for node in graph.nodes():
		for exit_id in node.exits:
			assert_eq(
				graph.node(exit_id).depth, node.depth + 1, "an exit must lead one depth down"
			)


func test_each_depth_is_within_its_declared_width() -> void:
	var graph := DungeonBuilder.build(_content)
	var deepest := graph.deepest_depth()
	for depth in range(1, deepest):
		var width := graph.nodes_at_depth(depth).size()
		assert_between(width, DungeonBuilder.MIN_WIDTH, DungeonBuilder.MAX_WIDTH)
	assert_eq(graph.nodes_at_depth(deepest).size(), 1, "the boss stands alone")


func test_the_same_seed_builds_the_same_map() -> void:
	RngService.begin_run_with_seed(_seed(0x55))
	var first := DungeonBuilder.build(_content).to_dict()
	RngService.begin_run_with_seed(_seed(0x55))
	var second := DungeonBuilder.build(_content).to_dict()
	assert_eq(JSON.stringify(first), JSON.stringify(second), "a seed must rebuild its map exactly")


func test_different_seeds_build_different_maps() -> void:
	# Guards against a stream that silently stopped advancing, which every
	# other test here would pass.
	RngService.begin_run_with_seed(_seed(0x11))
	var first := JSON.stringify(DungeonBuilder.build(_content).to_dict())
	RngService.begin_run_with_seed(_seed(0x99))
	var second := JSON.stringify(DungeonBuilder.build(_content).to_dict())
	assert_ne(first, second, "two seeds must not produce the same dungeon")


func test_a_map_survives_a_round_trip() -> void:
	var original := DungeonBuilder.build(_content)
	var restored := DungeonGraph.from_dict(original.to_dict())
	assert_eq(JSON.stringify(restored.to_dict()), JSON.stringify(original.to_dict()))


func _seed(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(RngService.SEED_LENGTH)
	bytes.fill(value)
	return bytes
