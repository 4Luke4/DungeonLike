class_name MapNode
extends RefCounted
## One room on the dungeon map.
##
## A node knows what it is and where it sits, and nothing about what it
## contains. Its contents are generated when the player enters it, from a stream
## scoped to its own identifier, so that the same node always produces the same
## encounter however the player reached it and whenever they arrive.

const KIND_START := "start"
const KIND_ENCOUNTER := "encounter"
const KIND_ELITE := "elite"
const KIND_TREASURE := "treasure"
const KIND_REST := "rest"
const KIND_BOSS := "boss"

## Every kind, for validation and for the interface's legend.
const KINDS: PackedStringArray = [
	KIND_START,
	KIND_ENCOUNTER,
	KIND_ELITE,
	KIND_TREASURE,
	KIND_REST,
	KIND_BOSS,
]

## Kinds that are resolved by fighting something.
const FIGHTING_KINDS: PackedStringArray = [KIND_ENCOUNTER, KIND_ELITE, KIND_BOSS]

## Stable identifier, unique within the run. Used as the RNG scope, so it must
## never be reassigned once the graph is built.
var id: String

## How deep the node sits. The start is zero.
var depth: int

## One of [constant KINDS].
var kind: String

## Which dungeon theme the node belongs to.
var theme_id: String

## Which presentation variant to draw, drawn once from the cosmetic stream when
## the graph is built. It is stored rather than derived at draw time so that no
## interface code ever needs to touch a generator.
var cosmetic_variant: int

## Position within its depth column, for layout and for keyboard navigation.
var column: int

## Identifiers of the nodes reachable from here, one depth further down.
var exits: PackedStringArray = PackedStringArray()

## Whether the player has finished with this node.
var resolved := false


func _init(node_id: String, node_depth: int, node_column: int) -> void:
	id = node_id
	depth = node_depth
	column = node_column


## Whether entering this node starts a fight.
func is_fight() -> bool:
	return kind in FIGHTING_KINDS


## The localisation key naming this node's kind to the player.
func kind_name_key() -> String:
	return "MAP_ROOM_" + kind.to_upper()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"depth": depth,
		"kind": kind,
		"theme_id": theme_id,
		"cosmetic_variant": cosmetic_variant,
		"column": column,
		"exits": exits,
		"resolved": resolved,
	}


static func from_dict(stored: Dictionary) -> MapNode:
	var node := MapNode.new(
		String(stored.get("id", "")), int(stored.get("depth", 0)), int(stored.get("column", 0))
	)
	node.kind = String(stored.get("kind", KIND_ENCOUNTER))
	node.theme_id = String(stored.get("theme_id", ""))
	node.cosmetic_variant = int(stored.get("cosmetic_variant", 0))
	node.resolved = bool(stored.get("resolved", false))
	var stored_exits: Array = stored.get("exits", [])
	for exit_id: Variant in stored_exits:
		node.exits.append(String(exit_id))
	return node
