class_name DungeonGraph
extends RefCounted
## The branching map of one run.
##
## Rooms are laid out in columns by depth and joined only to the column below,
## so the map is a directed acyclic graph that always flows downward. That shape
## is what makes "choose your path" a real decision with no way to wander back
## and grind, and it is what lets the interface lay the map out without a
## general graph drawing algorithm.

var _nodes: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _entry_id: String
var _boss_id: String


## Adds [param node]. Insertion order is preserved and is the order the
## interface draws in.
func add_node(node: MapNode) -> void:
	_nodes[node.id] = node
	_order.append(node.id)


## Records which node the run starts at.
func set_entry(node_id: String) -> void:
	_entry_id = node_id


## Records which node ends the run.
func set_boss(node_id: String) -> void:
	_boss_id = node_id


func entry_id() -> String:
	return _entry_id


func boss_id() -> String:
	return _boss_id


## One node by identifier, or null.
func node(node_id: String) -> MapNode:
	return _nodes.get(node_id, null)


## Every node, in the order it was added.
func nodes() -> Array[MapNode]:
	var ordered: Array[MapNode] = []
	for node_id in _order:
		ordered.append(_nodes[node_id])
	return ordered


## Every node at [param depth], left to right.
func nodes_at_depth(depth: int) -> Array[MapNode]:
	var matches: Array[MapNode] = []
	for node in nodes():
		if node.depth == depth:
			matches.append(node)
	return matches


## The deepest depth in the graph.
func deepest_depth() -> int:
	var deepest := 0
	for node in nodes():
		deepest = maxi(deepest, node.depth)
	return deepest


## Whether [param to_id] can be entered directly from [param from_id].
func is_reachable_from(from_id: String, to_id: String) -> bool:
	var source := node(from_id)
	return source != null and to_id in source.exits


## Every node reachable from the entry, by following exits.
##
## Used by the test suite to prove the generator never strands a room, which is
## the failure a player would experience as a map with a dead end they can see
## and cannot reach.
func reachable_from_entry() -> PackedStringArray:
	var seen := PackedStringArray()
	var pending: Array[String] = [_entry_id]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		if current.is_empty() or current in seen:
			continue
		seen.append(current)
		var node_here := node(current)
		if node_here != null:
			for exit_id in node_here.exits:
				pending.append(exit_id)
	return seen


func to_dict() -> Dictionary:
	var stored_nodes: Array = []
	for node in nodes():
		stored_nodes.append(node.to_dict())
	return {"entry": _entry_id, "boss": _boss_id, "nodes": stored_nodes}


static func from_dict(stored: Dictionary) -> DungeonGraph:
	var graph := DungeonGraph.new()
	var stored_nodes: Array = stored.get("nodes", [])
	for entry: Variant in stored_nodes:
		if typeof(entry) == TYPE_DICTIONARY:
			graph.add_node(MapNode.from_dict(entry))
	graph.set_entry(String(stored.get("entry", "")))
	graph.set_boss(String(stored.get("boss", "")))
	return graph
