class_name RunState
extends RefCounted
## Everything about a run in progress, and nothing else.
##
## Plain data: no node, no signal, no reference to a scene. That is what lets it
## be written to a save file, compared in a test, and restored without the rest
## of the game having to exist.
##
## What it does [i]not[/i] hold is any generator state. A node's contents are a
## pure function of the run seed and the node's identifier — see
## [method RngService.stream_for] — so resuming a run re-seeds from the recorded
## seed and replays nothing. Without that, this file would have to carry the
## internal state of a cryptographic generator, and the save format would be
## coupled to how randomness happens to be implemented.

## Bumped when the shape of a save changes in a way an older one cannot be read
## into. A save of a different format is refused rather than misread.
const FORMAT_VERSION := 1

var seed_hex := ""
var archetype_id := ""

var graph: DungeonGraph
var current_node_id := ""

## Where the player is, which is the depth of the node they last resolved.
var depth := 0

## Equipment slot to the item in it.
var equipment: Dictionary = {}

var max_hit_points := 1
var hit_points := 1

var enemies_defeated := 0

## The best thing found this run, for the summary to name.
var best_item: Item = null

## Set once the run is over, so the summary knows which ending to show.
var finished := false
var victorious := false

## True when the run was restored from a save with no device signature. The
## interface says so rather than hiding it.
var integrity_unverified := false


func _init() -> void:
	graph = DungeonGraph.new()


## The item in [param slot], or null.
func equipped(slot: String) -> Item:
	return equipment.get(slot, null)


## Puts [param item] in its slot and returns whatever it replaced.
func equip(item: Item, slot: String) -> Item:
	var replaced: Item = equipment.get(slot, null)
	equipment[slot] = item
	_remember_best(item)
	return replaced


## Records [param item] as the finest find if it beats the current one.
func _remember_best(item: Item) -> void:
	if item == null:
		return
	if best_item == null or item.rarity_rank() > best_item.rarity_rank():
		best_item = item


## Whether the player can still act.
func is_alive() -> bool:
	return hit_points > 0


func to_dict() -> Dictionary:
	var stored_equipment: Dictionary = {}
	for slot: String in equipment:
		var item: Item = equipment[slot]
		if item != null:
			stored_equipment[slot] = item.to_dict()

	return {
		"format": FORMAT_VERSION,
		"seed_hex": seed_hex,
		"archetype_id": archetype_id,
		"graph": graph.to_dict(),
		"current_node_id": current_node_id,
		"depth": depth,
		"equipment": stored_equipment,
		"max_hit_points": max_hit_points,
		"hit_points": hit_points,
		"enemies_defeated": enemies_defeated,
		"best_item": best_item.to_dict() if best_item != null else {},
		"finished": finished,
		"victorious": victorious,
	}


## Restores a run, or returns null if the save is of a format this build cannot
## read. Refusing is better than reading half of it and playing on.
static func from_dict(stored: Dictionary) -> RunState:
	if int(stored.get("format", 0)) != FORMAT_VERSION:
		return null

	var state := RunState.new()
	state.seed_hex = String(stored.get("seed_hex", ""))
	state.archetype_id = String(stored.get("archetype_id", ""))
	state.graph = DungeonGraph.from_dict(stored.get("graph", {}))
	state.current_node_id = String(stored.get("current_node_id", ""))
	state.depth = int(stored.get("depth", 0))
	state.max_hit_points = int(stored.get("max_hit_points", 1))
	state.hit_points = int(stored.get("hit_points", 1))
	state.enemies_defeated = int(stored.get("enemies_defeated", 0))
	state.finished = bool(stored.get("finished", false))
	state.victorious = bool(stored.get("victorious", false))

	var stored_equipment: Dictionary = stored.get("equipment", {})
	for slot: String in stored_equipment:
		state.equipment[slot] = Item.from_dict(stored_equipment[slot])

	var stored_best: Dictionary = stored.get("best_item", {})
	if not stored_best.is_empty():
		state.best_item = Item.from_dict(stored_best)

	return state
