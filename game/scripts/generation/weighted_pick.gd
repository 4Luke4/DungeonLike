class_name WeightedPick
extends RefCounted
## Choosing one of several options, some likelier than others.
##
## Weights are integers and are summed in the order the array is given, and the
## draw is a single [method RngService.next_below] over that sum. Both details
## are deliberate.
##
## Integers rather than floats because floating-point addition is not
## associative: summing the same weights in a different order can land on a
## different total in the last bit, which would make a seed replay differently
## on a different processor. Nothing about loot needs fractional weights.
##
## One draw rather than a draw per candidate because the number of values taken
## from a stream is part of what a seed reproduces. A rejection loop over
## candidates would take a different number of draws depending on the content,
## so adding a monster to a table would change every later roll in that stream.


## Returns the index chosen from [param weights], or -1 if nothing can be drawn.
##
## A total of zero means every option was filtered out, which is a content
## problem the caller has to handle rather than a draw that can be made.
static func index(stream: String, weights: PackedInt32Array) -> int:
	var total := 0
	for weight in weights:
		if weight > 0:
			total += weight
	if total <= 0:
		return -1

	var roll := RngService.next_below(stream, total)
	var running := 0
	for candidate in range(weights.size()):
		if weights[candidate] <= 0:
			continue
		running += weights[candidate]
		if roll < running:
			return candidate

	# Unreachable while the weights do not change between summing and walking.
	return -1


## Returns the record chosen from [param records], reading each one's weight
## from [param weight_field], or an empty dictionary if none can be drawn.
static func record(stream: String, records: Array, weight_field: String = "weight") -> Dictionary:
	var weights := PackedInt32Array()
	for entry: Dictionary in records:
		weights.append(int(entry.get(weight_field, 0)))
	var chosen := index(stream, weights)
	return records[chosen] if chosen >= 0 else {}
