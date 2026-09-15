class_name Dice
extends RefCounted
## Dice expressions, and the rolls they describe.
##
## Content declares damage, healing and counts as strings such as
## [code]"2d6+3"[/code], so that tuning a monster is a data edit rather than a
## code change. This class is the only thing that reads them.
##
## Every roll goes through [RngService] on a named stream, because an expression
## is rolled during generation and during combat alike and both must replay from
## the run seed. Parsing is deliberately strict: a malformed expression is
## rejected rather than coerced, since a silent zero would read in play as a
## monster that does no damage.


## The parsed form of an expression: how many dice, of how many sides, plus a
## flat modifier that may be negative or absent.
class Parsed:
	extends RefCounted

	var count: int
	var sides: int
	var modifier: int

	func _init(die_count: int, die_sides: int, flat_modifier: int) -> void:
		count = die_count
		sides = die_sides
		modifier = flat_modifier


## Parses [param expression], or returns null if it is not well formed.
##
## Returning null rather than a zeroed result forces every caller to decide what
## to do about a bad expression instead of quietly rolling nothing.
static func parse(expression: String) -> Parsed:
	var text := expression.strip_edges()
	var separator := text.find("d")
	if separator <= 0:
		return null

	var count_text := text.substr(0, separator)
	var remainder := text.substr(separator + 1)
	if not count_text.is_valid_int():
		return null

	var modifier := 0
	var sides_text := remainder
	for index in range(remainder.length()):
		var character := remainder[index]
		if character == "+" or character == "-":
			sides_text = remainder.substr(0, index)
			var modifier_text := remainder.substr(index)
			if not modifier_text.is_valid_int():
				return null
			modifier = modifier_text.to_int()
			break

	if not sides_text.is_valid_int():
		return null

	var count := count_text.to_int()
	var sides := sides_text.to_int()
	if count < 1 or sides < 2:
		return null
	return Parsed.new(count, sides, modifier)


## Whether [param expression] is a well-formed dice expression.
static func is_valid(expression: String) -> bool:
	return parse(expression) != null


## Rolls [param expression] on [param stream] and returns the total.
##
## The total is floored at zero: a large negative modifier on a small die could
## otherwise heal the target it was meant to hurt.
static func roll(stream: String, expression: String) -> int:
	var parsed := parse(expression)
	if parsed == null:
		push_error("Malformed dice expression: %s" % expression)
		return 0
	return maxi(0, RngService.roll(stream, parsed.count, parsed.sides) + parsed.modifier)


## Rolls [param expression] with its dice doubled and its modifier applied once.
##
## This is what a critical hit does: the dice are rolled twice over, the flat
## bonus is not doubled with them.
static func roll_critical(stream: String, expression: String) -> int:
	var parsed := parse(expression)
	if parsed == null:
		push_error("Malformed dice expression: %s" % expression)
		return 0
	var total := RngService.roll(stream, parsed.count * 2, parsed.sides)
	return maxi(0, total + parsed.modifier)


## The lowest total [param expression] can produce, floored at zero.
static func minimum(expression: String) -> int:
	var parsed := parse(expression)
	if parsed == null:
		return 0
	return maxi(0, parsed.count + parsed.modifier)


## The highest total [param expression] can produce.
static func maximum(expression: String) -> int:
	var parsed := parse(expression)
	if parsed == null:
		return 0
	return maxi(0, parsed.count * parsed.sides + parsed.modifier)
