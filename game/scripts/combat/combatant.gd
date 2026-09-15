class_name Combatant
extends RefCounted
## One participant in a fight, player or monster.
##
## Built from a monster record or from the player's current state, so that the
## resolver has one shape to work with and does not branch on which side a
## combatant is. The differences that remain — who chooses the action, who keeps
## their equipment afterwards — live above this class, not in it.

## Stable identifier within the encounter. Two giant rats are distinct
## combatants, so this is not the content identifier.
var id: String

## What to call this combatant on screen.
var name_key: String

## Whether the player controls it.
var is_player := false

var abilities: Abilities
var armour_class: int
var proficiency_bonus: int
var max_hit_points: int
var hit_points: int

## Which ability its attacks add. Monsters carry an explicit attack bonus
## instead, so this is only read for the player.
var attack_ability := "str"

var damage_resistances := PackedStringArray()
var damage_immunities := PackedStringArray()
var damage_vulnerabilities := PackedStringArray()
var condition_immunities := PackedStringArray()

var conditions: Conditions

## Attack records, as declared by content.
var attacks: Array[Dictionary] = []

## Extra damage the equipment adds to every hit, as content damage records.
var bonus_damage: Array[Dictionary] = []

## Extra conditions the equipment applies on a hit, as content effect records.
var on_hit_conditions: Array[Dictionary] = []

## A flat bonus applied to every attack roll, from equipment.
var attack_bonus := 0

## Set while defending, which the resolver reads when it is attacked.
var defending := false


func _init(combatant_id: String) -> void:
	id = combatant_id
	abilities = Abilities.new()
	conditions = Conditions.new()


## Whether the combatant is still standing.
func is_alive() -> bool:
	return hit_points > 0


## Applies [param amount] of damage, never below zero hit points.
func take_damage(amount: int) -> void:
	hit_points = maxi(0, hit_points - amount)


## Restores [param amount] of hit points, never above the maximum.
func heal(amount: int) -> int:
	var before := hit_points
	hit_points = mini(max_hit_points, hit_points + amount)
	return hit_points - before


## Applies [param condition] unless the combatant is immune to it.
##
## Returns whether it took hold, so the log can stay quiet about an immunity
## that was never going to matter.
func apply_condition(condition: String, rounds: int) -> bool:
	if condition in condition_immunities:
		return false
	conditions.apply(condition, rounds)
	return true


## The armour class an attacker must beat, including a defensive stance.
##
## Defending is the action available to a player who has nothing better to do,
## and it has to be worth taking: two points is enough to matter against the
## armour classes in this content and not enough to make defending a strategy.
func effective_armour_class() -> int:
	return armour_class + (2 if defending else 0)


## Builds a combatant from a monster record.
static func from_monster(record: Dictionary, combatant_id: String) -> Combatant:
	var combatant := Combatant.new(combatant_id)
	combatant.name_key = String(record.get("name_key", ""))
	combatant.abilities = Abilities.new(record.get("abilities", {}))
	combatant.armour_class = int(record.get("armour_class", 10))
	combatant.proficiency_bonus = int(record.get("proficiency_bonus", 2))
	combatant.damage_resistances = _strings(record.get("damage_resistances", []))
	combatant.damage_immunities = _strings(record.get("damage_immunities", []))
	combatant.damage_vulnerabilities = _strings(record.get("damage_vulnerabilities", []))
	combatant.condition_immunities = _strings(record.get("condition_immunities", []))
	var actions: Array = record.get("actions", [])
	for action: Dictionary in actions:
		combatant.attacks.append(action)
	return combatant


## Rolls a monster's hit points from its hit dice.
##
## Rolled rather than averaged so that two of the same monster in one room are
## not identical, and drawn from the encounter's own scoped stream so the result
## is still the same every time that room is entered.
func roll_hit_points(stream: String, hit_dice: String) -> void:
	max_hit_points = maxi(1, Dice.roll(stream, hit_dice))
	hit_points = max_hit_points


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name_key": name_key,
		"is_player": is_player,
		"abilities": abilities.to_dict(),
		"armour_class": armour_class,
		"proficiency_bonus": proficiency_bonus,
		"max_hit_points": max_hit_points,
		"hit_points": hit_points,
		"attack_ability": attack_ability,
		"conditions": conditions.to_dict(),
	}


static func _strings(values: Array) -> PackedStringArray:
	var converted := PackedStringArray()
	for value: Variant in values:
		converted.append(String(value))
	return converted
