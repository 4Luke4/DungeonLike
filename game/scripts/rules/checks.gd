class_name Checks
extends RefCounted
## Twenty-sided resolution: attack rolls and saving throws.
##
## One die decides almost everything: roll a d20, add a modifier, compare to a
## target number. The two places that differ are the natural results — a natural
## twenty hits whatever the armour class is and scores a critical, a natural one
## misses whatever the bonus is — and both exist so that no opponent is ever
## unreachable and no attacker is ever certain.
##
## Advantage rolls twice and keeps the better result; disadvantage keeps the
## worse. When a combatant has both, they cancel and one die is rolled: not an
## approximation but the rule, and it matters here because the number of draws
## taken from a stream must be the same either way or a seed would not replay.

## How the two dice of an advantaged or disadvantaged roll are combined.
enum Bias { NONE, ADVANTAGE, DISADVANTAGE }


## The faces of the die every check is resolved on.
const DIE_SIDES := 20

## The outcome of one check, with enough detail for the combat log to explain it.
class Outcome:
	extends RefCounted

	## The face value kept, before any modifier.
	var natural: int

	## The kept face plus the modifier.
	var total: int

	## Whether the check met or beat its target.
	var succeeded: bool

	## A natural twenty. Always a success, and a critical hit on an attack.
	var critical: bool

	## A natural one. Always a failure.
	var fumbled: bool

	func _init(kept: int, modifier: int, target: int) -> void:
		natural = kept
		total = kept + modifier
		critical = kept == DIE_SIDES
		fumbled = kept == 1
		# Order matters: the natural results override the arithmetic entirely.
		if critical:
			succeeded = true
		elif fumbled:
			succeeded = false
		else:
			succeeded = total >= target


## Resolves a check against [param target] and reports how it went.
##
## [param bias] decides how many dice are drawn: one, or two of which the better
## or worse is kept. Advantage and disadvantage together cancel to a single die.
static func resolve(stream: String, modifier: int, target: int, bias: int = Bias.NONE) -> Outcome:
	var kept := 0
	if bias == Bias.NONE:
		kept = RngService.next_in_range(stream, 1, DIE_SIDES)
	else:
		var first := RngService.next_in_range(stream, 1, DIE_SIDES)
		var second := RngService.next_in_range(stream, 1, DIE_SIDES)
		kept = maxi(first, second) if bias == Bias.ADVANTAGE else mini(first, second)
	return Outcome.new(kept, modifier, target)


## Combines any number of advantage and disadvantage sources into one bias.
##
## Having three sources of advantage and one of disadvantage is not a net
## advantage of two: they cancel to nothing at all. Resolving this in one place
## keeps every caller from reinventing it differently.
static func combine_bias(has_advantage: bool, has_disadvantage: bool) -> int:
	if has_advantage == has_disadvantage:
		return Bias.NONE
	return Bias.ADVANTAGE if has_advantage else Bias.DISADVANTAGE
