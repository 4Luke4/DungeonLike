class_name Abilities
extends RefCounted
## The six ability scores, their modifiers and proficiency.
##
## Scores are stored; modifiers are derived. Keeping the score as the stored
## value and the modifier as a function of it is what lets an item grant "+2
## Dexterity" and have initiative, armour class and attack rolls all follow
## without any of them being told about the item.


## The six abilities, in their conventional order. The order is load-bearing
## only for display; lookups are by key.
const ORDER: PackedStringArray = ["str", "dex", "con", "int", "wis", "cha"]

## Localisation key prefixes for an ability's full name and its abbreviation.
const NAME_KEY_PREFIX := "ABILITY_"

var _scores: Dictionary = {}


func _init(scores: Dictionary = {}) -> void:
	for ability in ORDER:
		_scores[ability] = int(scores.get(ability, 10))


## The stored score for [param ability].
func score(ability: String) -> int:
	return int(_scores.get(ability, 10))


## Sets [param ability] to [param value], clamped to the range scores may take.
func set_score(ability: String, value: int) -> void:
	if not _scores.has(ability):
		push_error("Unknown ability: %s" % ability)
		return
	_scores[ability] = clampi(value, 1, 30)


## Adds [param amount] to [param ability]. Used by item modifiers.
func add(ability: String, amount: int) -> void:
	set_score(ability, score(ability) + amount)


## The modifier derived from [param ability].
##
## Floor division rather than truncation: a score of 8 gives -1, and integer
## division towards zero in GDScript would give 0 for the same input.
func modifier(ability: String) -> int:
	return floori(float(score(ability) - 10) / 2.0)


## A copy, so that a combatant's scores cannot be mutated through a reference
## held by whatever produced them.
func duplicated() -> Abilities:
	return Abilities.new(_scores.duplicate())


## The scores as a plain dictionary, for serialisation.
func to_dict() -> Dictionary:
	return _scores.duplicate()


## The localisation key for an ability's full name.
static func name_key(ability: String) -> String:
	return NAME_KEY_PREFIX + ability.to_upper()


## The localisation key for an ability's abbreviation.
static func short_name_key(ability: String) -> String:
	return NAME_KEY_PREFIX + ability.to_upper() + "_SHORT"
