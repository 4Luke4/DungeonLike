class_name EncounterBuilder
extends RefCounted
## Decides what is waiting in a room.
##
## The theme names an encounter table, the table is a weighted list of monster
## groups, and a group names a monster and how many of it. An elite room draws
## the same way and then adds one more of whatever it drew, which is a cheaper
## way to make a room harder than maintaining a second table of elite versions of
## every monster.
##
## Every draw is scoped to the room's own identifier, so the same room always
## holds the same monsters however the player reached it.

## How many monsters a single room may hold. A larger group turns a turn-based
## fight into a queue the player watches.
const MAX_MONSTERS := 6


## Builds the monster list for [param node].
##
## Returns an array of monster records, repeated by count, in draw order. The
## order is the order they are shown in and the order they roll initiative in,
## so it must come from the stream rather than from a later sort.
static func build(content: ContentDatabase, node: MapNode) -> Array[Dictionary]:
	var monsters: Array[Dictionary] = []
	var theme := content.by_id(node.theme_id)
	var table := content.by_id(String(theme.get("encounter_table", "")))
	if table.is_empty():
		push_error("Room %s has no encounter table." % node.id)
		return monsters

	var stream := RngService.stream_for(RngService.STREAM_ENCOUNTER, node.id)
	var entries: Array = table.get("entries", [])
	var entry := WeightedPick.record(stream, entries)
	if entry.is_empty():
		return monsters

	var groups: Array = entry.get("groups", [])
	for group: Dictionary in groups:
		var record := content.by_id(String(group.get("monster", "")))
		if record.is_empty():
			continue
		var count := _resolve_count(stream, group.get("count", 1))
		if node.kind == MapNode.KIND_ELITE:
			# One more of the first group, which is what makes an elite room
			# read as the same place with worse odds.
			count += 1
		for _index in range(count):
			if monsters.size() >= MAX_MONSTERS:
				return monsters
			monsters.append(record)

	return monsters


## A count is either a fixed number or a roll. Both are ordinary: a lone boss is
## written as 1, a pack of rats as "2d3".
static func _resolve_count(stream: String, declared: Variant) -> int:
	if typeof(declared) == TYPE_STRING:
		return maxi(1, Dice.roll(stream, String(declared)))
	return maxi(1, int(declared))
