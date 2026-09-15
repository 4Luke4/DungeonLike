class_name DungeonBuilder
extends RefCounted
## Builds the branching map a run is played across.
##
## The shape is a column per depth: one start, one boss, and two to four rooms
## at every depth between them. Edges only ever join a column to the one below,
## so the map always flows downward and a path once taken cannot be retraced.
##
## Two properties are guaranteed rather than hoped for, and both are asserted by
## game/tests/unit/test_dungeon_builder.gd:
##
## [b]Every room is reachable.[/b] A room the player can see and cannot enter
## reads as a bug however deliberate it might be.
##
## [b]The boss is reachable from the start.[/b] A descent that cannot be
## finished is worse than one that is hard.
##
## Every draw is taken from the [code]map[/code] stream except the presentation
## variant of each room, which is drawn from [code]cosmetic[/code]. That split is
## what lets the look of the dungeon change without moving a single gameplay
## draw.

## How many rooms a depth may hold, outside the start and the boss.
const MIN_WIDTH := 2
const MAX_WIDTH := 4


## Builds the whole map for a run.
static func build(content: ContentDatabase) -> DungeonGraph:
	var graph := DungeonGraph.new()
	var deepest := content.deepest_depth()
	if deepest < 1:
		push_error("No dungeon themes are declared; the map cannot be built.")
		return graph

	var map_stream := RngService.STREAM_MAP
	var cosmetic_stream := RngService.STREAM_COSMETIC

	# Depth zero: where the player starts, already behind them.
	var start := MapNode.new("node-0-0", 0, 0)
	start.kind = MapNode.KIND_START
	start.theme_id = String(content.theme_for_depth(1).get("id", ""))
	start.resolved = true
	graph.add_node(start)
	graph.set_entry(start.id)

	var previous: Array[MapNode] = [start]

	for depth in range(1, deepest + 1):
		var theme := content.theme_for_depth(depth)
		var is_final := depth == deepest
		var width := 1 if is_final else RngService.next_in_range(map_stream, MIN_WIDTH, MAX_WIDTH)

		var current: Array[MapNode] = []
		for column in range(width):
			var node := MapNode.new("node-%d-%d" % [depth, column], depth, column)
			node.theme_id = String(theme.get("id", ""))
			node.kind = (
				MapNode.KIND_BOSS if is_final else _draw_kind(map_stream, theme)
			)
			var variants: int = maxi(1, int(theme.get("cosmetic_variants", 1)))
			node.cosmetic_variant = RngService.next_below(cosmetic_stream, variants)
			graph.add_node(node)
			current.append(node)

		_join(map_stream, previous, current)
		previous = current

		if is_final:
			graph.set_boss(current[0].id)

	return graph


## Draws a room kind from the theme's weights.
static func _draw_kind(stream: String, theme: Dictionary) -> String:
	var weights_by_kind: Dictionary = theme.get("room_weights", {})
	var kinds := PackedStringArray()
	var weights := PackedInt32Array()
	# Walked in the order MapNode declares rather than the dictionary's, so the
	# draw does not depend on how the JSON happened to be written.
	for kind in MapNode.KINDS:
		if weights_by_kind.has(kind):
			kinds.append(kind)
			weights.append(int(weights_by_kind[kind]))

	var chosen := WeightedPick.index(stream, weights)
	return kinds[chosen] if chosen >= 0 else MapNode.KIND_ENCOUNTER


## Joins one depth to the next so that both are fully connected.
##
## Each room above is given an exit to the room below it in proportion, and
## sometimes a second to its neighbour, which is what produces branches. Any room
## below still without a way in is then joined to the nearest room above. Doing
## it in that order is what guarantees no room is stranded without needing to
## search the graph afterwards.
static func _join(stream: String, above: Array[MapNode], below: Array[MapNode]) -> void:
	if above.is_empty() or below.is_empty():
		return

	for index in range(above.size()):
		var target := 0
		if above.size() > 1:
			# Spread the upper row across the lower one rather than sending
			# everything to the middle.
			target = int(floor(float(index) * float(below.size()) / float(above.size())))
		target = clampi(target, 0, below.size() - 1)
		above[index].exits.append(below[target].id)

		# A second exit, where there is a neighbour to take it, is what makes the
		# map a choice rather than a corridor.
		if below.size() > 1 and RngService.next_below(stream, 100) < 45:
			var neighbour := clampi(target + 1, 0, below.size() - 1)
			if neighbour != target:
				above[index].exits.append(below[neighbour].id)

	var entered := PackedStringArray()
	for node in above:
		for exit_id in node.exits:
			if not exit_id in entered:
				entered.append(exit_id)

	for index in range(below.size()):
		if below[index].id in entered:
			continue
		var nearest := 0
		if below.size() > 1:
			nearest = int(floor(float(index) * float(above.size()) / float(below.size())))
		nearest = clampi(nearest, 0, above.size() - 1)
		above[nearest].exits.append(below[index].id)
