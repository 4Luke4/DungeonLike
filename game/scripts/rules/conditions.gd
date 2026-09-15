class_name Conditions
extends RefCounted
## The conditions a combatant can be under, and what each one does.
##
## A condition is a named state with a duration in rounds. What makes them worth
## a class of their own is that their effects are read from three different
## places — when the sufferer attacks, when something attacks the sufferer, and
## when the sufferer's turn comes round — and scattering that across the
## resolver would mean each new condition had to be remembered in three places.
##
## Only conditions the resolver actually implements are listed. A condition that
## content could name but nothing applied would be a silent no-op, so
## tools/scripts/check_content.py validates against exactly this set.

const BLINDED := "blinded"
const FRIGHTENED := "frightened"
const INCAPACITATED := "incapacitated"
const INVISIBLE := "invisible"
const PARALYSED := "paralysed"
const POISONED := "poisoned"
const PRONE := "prone"
const RESTRAINED := "restrained"
const STUNNED := "stunned"
const UNCONSCIOUS := "unconscious"

const ALL: PackedStringArray = [
	BLINDED,
	FRIGHTENED,
	INCAPACITATED,
	INVISIBLE,
	PARALYSED,
	POISONED,
	PRONE,
	RESTRAINED,
	STUNNED,
	UNCONSCIOUS,
]

## Conditions that stop a combatant acting at all on their turn.
const PREVENTS_ACTING: PackedStringArray = [
	INCAPACITATED,
	PARALYSED,
	STUNNED,
	UNCONSCIOUS,
]

## Conditions that make the sufferer's own attacks and checks worse.
const SUFFERER_HAS_DISADVANTAGE: PackedStringArray = [
	BLINDED,
	FRIGHTENED,
	POISONED,
	PRONE,
	RESTRAINED,
]

## Conditions that make attacks against the sufferer easier.
const ATTACKERS_HAVE_ADVANTAGE: PackedStringArray = [
	PARALYSED,
	PRONE,
	RESTRAINED,
	STUNNED,
	UNCONSCIOUS,
]

## Conditions that make attacks against the sufferer harder.
const ATTACKERS_HAVE_DISADVANTAGE: PackedStringArray = [
	INVISIBLE,
]

# Condition name to rounds remaining.
var _active: Dictionary = {}


## Applies [param condition] for [param rounds], or extends it if the new
## duration is longer.
##
## Extending rather than replacing means a second dose of poison cannot shorten
## the first, which is what a plain assignment would do.
func apply(condition: String, rounds: int) -> void:
	if not is_known(condition):
		push_error("Unknown condition: %s" % condition)
		return
	_active[condition] = maxi(int(_active.get(condition, 0)), rounds)


## Whether [param condition] is one this project implements.
##
## Content cannot introduce an unknown one — tools/scripts/check_content.py
## validates every condition name against the same set — so a name that fails
## here came from code, which is why [method apply] reports it rather than
## ignoring it quietly.
static func is_known(condition: String) -> bool:
	return condition in ALL


## Removes [param condition] outright.
func clear(condition: String) -> void:
	_active.erase(condition)


## Whether [param condition] is currently in force.
func has(condition: String) -> bool:
	return _active.has(condition)


## Every condition in force, in the order [constant ALL] declares, so that the
## interface never reorders them between frames.
func active() -> PackedStringArray:
	var present := PackedStringArray()
	for condition in ALL:
		if _active.has(condition):
			present.append(condition)
	return present


## Whether any condition prevents its sufferer from acting.
func prevents_acting() -> bool:
	return _any_of(PREVENTS_ACTING)


## Whether the sufferer's own rolls are made with disadvantage.
func gives_sufferer_disadvantage() -> bool:
	return _any_of(SUFFERER_HAS_DISADVANTAGE)


## Whether attacks against the sufferer are made with advantage.
func gives_attackers_advantage() -> bool:
	return _any_of(ATTACKERS_HAVE_ADVANTAGE)


## Whether attacks against the sufferer are made with disadvantage.
func gives_attackers_disadvantage() -> bool:
	return _any_of(ATTACKERS_HAVE_DISADVANTAGE)


## Counts down every condition by one round and returns those that ended.
##
## Called once at the end of the sufferer's turn. Returning the expired names
## rather than logging them here keeps this class free of the interface.
func advance_round() -> PackedStringArray:
	var ended := PackedStringArray()
	for condition in active():
		var remaining := int(_active[condition]) - 1
		if remaining <= 0:
			_active.erase(condition)
			ended.append(condition)
		else:
			_active[condition] = remaining
	return ended


## The conditions and their remaining rounds, for serialisation.
func to_dict() -> Dictionary:
	return _active.duplicate()


## Restores from [method to_dict].
func from_dict(stored: Dictionary) -> void:
	_active.clear()
	for condition: String in stored:
		if condition in ALL:
			_active[condition] = int(stored[condition])


## The localisation key naming [param condition] to the player.
static func name_key(condition: String) -> String:
	return "CONDITION_" + condition.to_upper()


func _any_of(group: PackedStringArray) -> bool:
	for condition in group:
		if _active.has(condition):
			return true
	return false
