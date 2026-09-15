class_name PlayerBuilder
extends RefCounted
## Turns an archetype and a set of equipment into a combatant.
##
## The player's numbers are derived, never stored: ability scores come from the
## archetype and are then raised by whatever is equipped, armour class is
## computed from the armour and the resulting Dexterity, and the weapon decides
## the damage. Deriving rather than storing is what lets an item be equipped
## mid-run and have everything follow from it at once, with nothing to keep in
## step by hand.
##
## Hit points are the exception. They are stored in [RunState], because damage
## taken has to survive leaving a room, and a maximum that changed when armour
## changed would either heal or kill the player for putting on a hat.

## Armour class with no armour at all.
const UNARMOURED_BASE := 10


## Builds the player's combatant for a fight.
static func build(state: RunState, content: ContentDatabase) -> Combatant:
	var archetype := content.by_id(state.archetype_id)
	var player := Combatant.new("player")
	player.is_player = true
	player.name_key = String(archetype.get("name_key", ""))
	player.abilities = Abilities.new(archetype.get("abilities", {}))
	player.proficiency_bonus = int(archetype.get("proficiency_bonus", 2))
	player.attack_ability = String(archetype.get("attack_ability", "str"))

	_apply_equipment(player, state, content)

	player.max_hit_points = state.max_hit_points
	player.hit_points = state.hit_points
	player.attacks = [{"damage": _weapon_damage(state, content, player)}]
	return player


## The hit points an archetype starts with, before any equipment.
##
## Taken as the maximum of the hit die rather than rolled: a run that began with
## a bad roll would be over before the player made a single decision, which is
## not the kind of randomness this game is for.
static func starting_hit_points(archetype: Dictionary) -> int:
	var die := String(archetype.get("hit_die", "1d8"))
	var constitution := int(archetype.get("abilities", {}).get("con", 10))
	var modifier := floori(float(constitution - 10) / 2.0)
	return maxi(1, Dice.maximum(die) + modifier)


## Reads every equipped item and folds its effects into [param player].
static func _apply_equipment(player: Combatant, state: RunState, content: ContentDatabase) -> void:
	for slot: String in state.equipment:
		var item: Item = state.equipment[slot]
		if item == null:
			continue
		for effect: Dictionary in effects_of(item, content):
			_apply_effect(player, effect, item)

	player.armour_class = _armour_class(state, content, player)


## Every effect an item confers, whether it is a unique or a generated item.
static func effects_of(item: Item, content: ContentDatabase) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if item.is_unique():
		for effect: Dictionary in content.by_id(item.unique_id).get("effects", []):
			effects.append(effect)
		return effects

	for affix_id in [item.prefix_id, item.suffix_id]:
		if String(affix_id).is_empty():
			continue
		for effect: Dictionary in content.by_id(String(affix_id)).get("effects", []):
			effects.append(effect)
	return effects


static func _apply_effect(player: Combatant, effect: Dictionary, item: Item) -> void:
	match String(effect.get("kind", "")):
		"ability_bonus":
			player.abilities.add(String(effect.get("ability", "str")), int(effect.get("amount", 0)))
		"attack_bonus":
			player.attack_bonus += int(effect.get("amount", 0))
		"bonus_damage":
			player.bonus_damage.append(effect.get("damage", {}))
		"damage_resistance":
			player.damage_resistances.append(String(effect.get("damage_type", "")))
		"on_hit_condition":
			player.on_hit_conditions.append(effect)
		"max_hit_points":
			# Rolled once when the item was generated; the stored value is what
			# counts, so the same item is worth the same tomorrow.
			pass
		"armour_class_bonus":
			# Folded in by _armour_class, which needs the final Dexterity first.
			pass


## Armour class from the equipped armour, the shield and the final Dexterity.
##
## Computed after every ability bonus has been applied, because a trinket that
## raises Dexterity has to raise armour class through it.
static func _armour_class(state: RunState, content: ContentDatabase, player: Combatant) -> int:
	var dexterity := player.abilities.modifier("dex")
	var armour_class := UNARMOURED_BASE + dexterity
	var bonus := 0

	var armour: Item = state.equipped("armour")
	if armour != null:
		var base := content.by_id(armour.base_id)
		var cap := int(base.get("max_dexterity_bonus", 10))
		armour_class = int(base.get("base_armour_class", UNARMOURED_BASE)) + mini(dexterity, cap)

	var shield: Item = state.equipped("off_hand")
	if shield != null:
		bonus += int(content.by_id(shield.base_id).get("base_armour_class", 0))

	for slot: String in state.equipment:
		var item: Item = state.equipment[slot]
		if item == null:
			continue
		for effect: Dictionary in effects_of(item, content):
			if String(effect.get("kind", "")) == "armour_class_bonus":
				bonus += int(effect.get("amount", 0))

	return armour_class + bonus


## The damage the equipped weapon deals, including the ability modifier.
static func _weapon_damage(
	state: RunState, content: ContentDatabase, player: Combatant
) -> Array:
	var weapon: Item = state.equipped("main_hand")
	if weapon == null:
		# An unarmed player still has to be able to act.
		return [{"dice": "1d%d" % 4, "type": "bludgeoning"}]

	var base := content.by_id(weapon.base_id)
	var damage: Dictionary = base.get("damage", {"dice": "1d4", "type": "bludgeoning"})
	var modifier := player.abilities.modifier(player.attack_ability)
	var expression := String(damage.get("dice", "1d4"))
	if modifier != 0:
		expression = "%s%s%d" % [expression, "+" if modifier > 0 else "", modifier]
	return [{"dice": expression, "type": String(damage.get("type", "bludgeoning"))}]
