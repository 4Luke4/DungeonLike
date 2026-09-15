class_name RunController
extends RefCounted
## The only thing allowed to change a run.
##
## Every method here corresponds to one decision a player makes, and each one
## resolves completely before it returns. The interface calls a method and then
## renders what changed; it never computes an outcome and it never draws from a
## gameplay stream. That division is what makes a run a pure function of its
## seed, its archetype and the ordered list of decisions taken — and therefore
## what makes a recorded seed reproduce a reported bug.
##
## A seed alone does not reproduce a run. The archetype is a decision, not a
## draw, so the summary screen shows both and a bug report needs both.

var state: RunState
var content: ContentDatabase

## The fight in progress, or null between rooms.
var encounter: CombatResolver = null

## What the last entered room produced, for the interface to pick a view.
var pending_item: Item = null


func _init(database: ContentDatabase) -> void:
	content = database


## Starts a fresh run as [param archetype_id].
##
## The run is seeded here rather than in the main menu, because the archetype is
## chosen first and a seed drawn before that decision would imply the choice
## could not affect what follows.
func start_new_run(archetype_id: String) -> void:
	var archetype := content.by_id(archetype_id)
	if archetype.is_empty():
		push_error("Unknown archetype: %s" % archetype_id)
		return

	var seed_bytes := RngService.begin_run()
	state = RunState.new()
	state.seed_hex = seed_bytes.hex_encode()
	state.archetype_id = archetype_id
	state.max_hit_points = PlayerBuilder.starting_hit_points(archetype)
	state.hit_points = state.max_hit_points

	for item_id: Variant in archetype.get("starting_items", []):
		var base := content.by_id(String(item_id))
		var item := Item.new(String(item_id))
		item.item_level = 1
		state.equip(item, String(base.get("slot", "trinket")))

	state.graph = DungeonBuilder.build(content)
	state.current_node_id = state.graph.entry_id()


## Restores a run from a loaded [param restored] state.
##
## Re-seeding is all that is needed: because every room's contents are derived
## from the run seed and the room's identifier, nothing has to be replayed and
## no generator state is carried in the save.
func resume(restored: RunState) -> void:
	state = restored
	var seed_bytes := PackedByteArray(Array(state.seed_hex.hex_decode()))
	if seed_bytes.size() == RngService.SEED_LENGTH:
		RngService.begin_run_with_seed(seed_bytes)


## The rooms the player may enter from where they stand.
func available_exits() -> Array[MapNode]:
	var here := state.graph.node(state.current_node_id)
	var exits: Array[MapNode] = []
	if here == null:
		return exits
	for exit_id in here.exits:
		var node := state.graph.node(exit_id)
		if node != null:
			exits.append(node)
	return exits


## Enters [param node_id], resolving whatever the room holds.
##
## A fight leaves an encounter in progress for the interface to drive; a
## treasure room leaves an item pending; a rest room resolves immediately.
func enter_node(node_id: String) -> void:
	if not state.graph.is_reachable_from(state.current_node_id, node_id):
		return
	var node := state.graph.node(node_id)
	if node == null or node.resolved:
		return

	state.current_node_id = node_id
	state.depth = node.depth
	pending_item = null

	if node.is_fight():
		_begin_fight(node)
	elif node.kind == MapNode.KIND_TREASURE:
		pending_item = LootGenerator.generate(content, node, node.depth)
		node.resolved = true
	else:
		node.resolved = true


## Applies the outcome of a finished fight to the run.
##
## Called by the interface once it has animated the last event, so that the
## player sees the killing blow before the screen changes.
func conclude_fight() -> void:
	if encounter == null or encounter.state != CombatResolver.State.FINISHED:
		return

	var node := state.graph.node(state.current_node_id)
	if encounter.outcome == CombatResolver.Outcome.PLAYER_DIED:
		state.hit_points = 0
		state.finished = true
		state.victorious = false
	else:
		state.hit_points = maxi(1, _player_hit_points())
		state.enemies_defeated += encounter.initiative_order().size() - 1
		if node != null:
			node.resolved = true
			pending_item = LootGenerator.generate(content, node, node.depth)
			if node.kind == MapNode.KIND_BOSS:
				state.finished = true
				state.victorious = true

	# The room is finished with, so its generator state can go. The contents are
	# derived from the seed, so forgetting costs nothing if it is asked again.
	if node != null:
		RngService.forget_stream(RngService.stream_for(RngService.STREAM_ENCOUNTER, node.id))
	encounter = null


## Takes the pending item, equipping it and returning what it replaced.
func take_pending_item() -> Item:
	if pending_item == null:
		return null
	var base := content.by_id(pending_item.base_id)
	var replaced := state.equip(pending_item, String(base.get("slot", "trinket")))
	_refresh_hit_point_maximum()
	pending_item = null
	return replaced


## Declines the pending item.
func leave_pending_item() -> void:
	pending_item = null


## Rests, recovering hit points, and returns how many were restored.
func rest() -> int:
	var node := state.graph.node(state.current_node_id)
	if node == null or node.kind != MapNode.KIND_REST:
		return 0
	# A quarter of the maximum, rounded up: enough to matter after a bad fight,
	# not enough to make resting always the right choice.
	var restored := mini(
		state.max_hit_points - state.hit_points, int(ceil(float(state.max_hit_points) / 4.0))
	)
	state.hit_points += restored
	return restored


## Abandons the run without finishing it.
func abandon() -> void:
	state.finished = true
	state.victorious = false


func _begin_fight(node: MapNode) -> void:
	var player := PlayerBuilder.build(state, content)
	encounter = CombatResolver.new()
	encounter.start(content, node, player)
	encounter.grant_powers(_archetype_powers())


func _archetype_powers() -> PackedStringArray:
	var powers := PackedStringArray()
	for power_id: Variant in content.by_id(state.archetype_id).get("powers", []):
		powers.append(String(power_id))
	return powers


func _player_hit_points() -> int:
	for combatant in encounter.initiative_order():
		if combatant.is_player:
			return combatant.hit_points
	return state.hit_points


## Recomputes the hit point maximum after equipment changed.
##
## Current hit points follow the maximum upward but are never raised above it,
## so putting on an item that grants vitality heals by exactly what it grants
## and taking it off cannot kill.
func _refresh_hit_point_maximum() -> void:
	var archetype := content.by_id(state.archetype_id)
	var base_maximum := PlayerBuilder.starting_hit_points(archetype)
	var granted := 0
	for slot: String in state.equipment:
		var item: Item = state.equipment[slot]
		if item == null:
			continue
		var effects := PlayerBuilder.effects_of(item, content)
		for index in range(effects.size()):
			var effect := effects[index]
			if String(effect.get("kind", "")) != "max_hit_points":
				continue
			var key := "%s:%d" % [_effect_source(item), index]
			granted += int(item.rolled_values.get(key, 0))

	var previous := state.max_hit_points
	state.max_hit_points = maxi(1, base_maximum + granted)
	state.hit_points = clampi(
		state.hit_points + maxi(0, state.max_hit_points - previous), 1, state.max_hit_points
	)


## Which record an item's rolled values were keyed under.
func _effect_source(item: Item) -> String:
	if item.is_unique():
		return item.unique_id
	return item.prefix_id if not item.prefix_id.is_empty() else item.suffix_id
