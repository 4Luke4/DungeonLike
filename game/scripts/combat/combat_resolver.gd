class_name CombatResolver
extends RefCounted
## Runs one fight, from initiative to the last combatant standing.
##
## The resolver is the only thing in the project that draws from an encounter's
## stream, and it is a plain object with no node, no scene and no signals. That
## is what makes a whole fight reproducible from a seed and assertable in a test:
## the interface hands it a decision, it resolves the decision and every monster
## turn that follows, and it returns a list of events describing what happened.
##
## The interface animates that list. It never computes an outcome, and it must
## never draw from a gameplay stream for a flourish — a shuffled hit spark that
## called into this stream would shift every later roll and the run would quietly
## stop replaying from its seed. tools/scripts/check_rng_usage.py forbids
## RngService in interface scripts for that reason.
##
## One player decision resolves the player's turn and then every monster turn up
## to the player's next, so the caller never has to drive a turn loop.

## What the fight is waiting for.
enum State { AWAITING_PLAYER, FINISHED }

## How the fight ended.
enum Outcome { UNDECIDED, PLAYER_WON, PLAYER_DIED }

## A fight that has not resolved in this many rounds is a stalemate. Two
## combatants that cannot hit each other would otherwise loop forever, and an
## infinite loop in a turn-based game is indistinguishable from a freeze.
const MAX_ROUNDS := 50

var state: int = State.AWAITING_PLAYER
var outcome: int = Outcome.UNDECIDED
var round_number := 1

var _stream: String
var _player: Combatant
var _monsters: Array[Combatant] = []
var _initiative: Array[Combatant] = []
var _turn_index := 0
var _events: Array[CombatEvent] = []
var _power_uses: Dictionary = {}
var _content: ContentDatabase


## Prepares a fight in [param node] between [param player] and whatever the
## room holds.
func start(content: ContentDatabase, node: MapNode, player: Combatant) -> void:
	_content = content
	_stream = RngService.stream_for(RngService.STREAM_ENCOUNTER, node.id)
	_player = player
	_player.defending = false

	var records := EncounterBuilder.build(content, node)
	for index in range(records.size()):
		var record := records[index]
		var monster := Combatant.from_monster(record, "%s-monster-%d" % [node.id, index])
		monster.roll_hit_points(_stream, String(record.get("hit_dice", "1d8")))
		_monsters.append(monster)

	_roll_initiative()
	_advance_to_player()


## Every combatant in initiative order.
func initiative_order() -> Array[Combatant]:
	return _initiative


## The monsters still standing.
func living_monsters() -> Array[Combatant]:
	return _monsters.filter(func(monster: Combatant) -> bool: return monster.is_alive())


## Events produced since [param index], for the interface to animate.
func events_since(index: int) -> Array[CombatEvent]:
	return _events.slice(clampi(index, 0, _events.size()))


## How many events have been produced in total.
func event_count() -> int:
	return _events.size()


## How many uses of [param power_id] the player has left this fight.
func power_uses_left(power_id: String) -> int:
	return int(_power_uses.get(power_id, 0))


## The player attacks [param target_id] with their weapon.
func player_attacks(target_id: String) -> void:
	var target := _monster(target_id)
	if state != State.AWAITING_PLAYER or target == null or not target.is_alive():
		return
	_player.defending = false
	_attack(_player, target, _player_weapon_attack())
	_finish_player_turn()


## The player takes a defensive stance, raising their armour class until their
## next turn.
func player_defends() -> void:
	if state != State.AWAITING_PLAYER:
		return
	_player.defending = true
	_log("LOG_DEFEND", [_name(_player)], _player.id)
	_finish_player_turn()


## The player uses [param power_id], on [param target_id] where it needs one.
func player_uses_power(power_id: String, target_id: String) -> void:
	if state != State.AWAITING_PLAYER or power_uses_left(power_id) <= 0:
		return
	var power := _content.by_id(power_id)
	if power.is_empty():
		return

	_power_uses[power_id] = power_uses_left(power_id) - 1
	_player.defending = false
	_log("LOG_POWER_USED", [_name(_player), tr(String(power.get("name_key", "")))], _player.id)
	_apply_power(power, target_id)
	_finish_player_turn()


## Grants the player their powers for this fight.
func grant_powers(power_ids: PackedStringArray) -> void:
	for power_id in power_ids:
		var power := _content.by_id(power_id)
		if not power.is_empty():
			_power_uses[power_id] = int(power.get("uses_per_encounter", 1))


# --- Turn flow ---------------------------------------------------------------


func _roll_initiative() -> void:
	var entries: Array = []
	for combatant: Combatant in [_player] + _monsters:
		var rolled := (
			RngService.next_in_range(_stream, 1, Checks.DIE_SIDES)
			+ combatant.abilities.modifier("dex")
		)
		entries.append({"combatant": combatant, "score": rolled})
		_log("LOG_INITIATIVE", [_name(combatant), rolled], combatant.id)

	# Ties break on Dexterity and then on identifier. Deliberately not a re-roll:
	# a re-roll would take a number of draws that depends on how the dice landed,
	# and the count of draws taken from a stream is part of what a seed replays.
	entries.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_one: Combatant = left["combatant"]
			var right_one: Combatant = right["combatant"]
			if left["score"] != right["score"]:
				return left["score"] > right["score"]
			var left_dex := left_one.abilities.score("dex")
			var right_dex := right_one.abilities.score("dex")
			if left_dex != right_dex:
				return left_dex > right_dex
			return left_one.id < right_one.id
	)

	for entry: Dictionary in entries:
		_initiative.append(entry["combatant"])


## Resolves monster turns until it is the player's turn again, or the fight ends.
func _advance_to_player() -> void:
	while state != State.FINISHED:
		var current := _initiative[_turn_index]
		if current.is_player:
			if current.is_alive():
				return
			_step_turn()
			continue
		if current.is_alive():
			_take_monster_turn(current)
			if _check_finished():
				return
		_step_turn()


func _finish_player_turn() -> void:
	_expire_conditions(_player)
	if _check_finished():
		return
	_step_turn()
	_advance_to_player()


func _step_turn() -> void:
	_turn_index += 1
	if _turn_index < _initiative.size():
		return
	_turn_index = 0
	round_number += 1
	_log("LOG_ROUND_BEGINS", [round_number], "")
	if round_number > MAX_ROUNDS:
		# A stalemate is resolved against the player: they may walk away from a
		# fight they cannot win, but they do not win it by outlasting the clock.
		state = State.FINISHED
		outcome = Outcome.PLAYER_DIED
		_log("LOG_DEFEAT", [], _player.id)


func _take_monster_turn(monster: Combatant) -> void:
	if monster.conditions.prevents_acting():
		_expire_conditions(monster)
		return
	if _player.is_alive() and not monster.attacks.is_empty():
		var choice := RngService.next_below(_stream, monster.attacks.size())
		_attack(monster, _player, monster.attacks[choice])
	_expire_conditions(monster)


func _expire_conditions(combatant: Combatant) -> void:
	for condition in combatant.conditions.advance_round():
		_log(
			"LOG_CONDITION_ENDED",
			[_name(combatant), tr(Conditions.name_key(condition))],
			combatant.id
		)


func _check_finished() -> bool:
	if not _player.is_alive():
		state = State.FINISHED
		outcome = Outcome.PLAYER_DIED
		_log("LOG_DEFEAT", [], _player.id)
		return true
	if living_monsters().is_empty():
		state = State.FINISHED
		outcome = Outcome.PLAYER_WON
		_log("LOG_VICTORY", [], "")
		return true
	return false


# --- Attacks and damage ------------------------------------------------------


## Resolves one attack from [param attacker] against [param defender].
##
## The bias is worked out from both sides at once: conditions on the attacker
## that make their rolls worse, and conditions on the defender that make them
## easier or harder to hit. Advantage and disadvantage cancel rather than
## accumulate, which also keeps the number of dice drawn predictable.
func _attack(attacker: Combatant, defender: Combatant, action: Dictionary) -> void:
	var has_advantage := defender.conditions.gives_attackers_advantage()
	var has_disadvantage := (
		attacker.conditions.gives_sufferer_disadvantage()
		or defender.conditions.gives_attackers_disadvantage()
	)
	var bias := Checks.combine_bias(has_advantage, has_disadvantage)
	if bias == Checks.Bias.ADVANTAGE:
		_log("LOG_WITH_ADVANTAGE", [_name(attacker)], attacker.id)
	elif bias == Checks.Bias.DISADVANTAGE:
		_log("LOG_WITH_DISADVANTAGE", [_name(attacker)], attacker.id)

	var modifier := _attack_modifier(attacker, action)
	var result := Checks.resolve(_stream, modifier, defender.effective_armour_class(), bias)
	if not result.succeeded:
		_log("LOG_ATTACK_MISS", [_name(attacker), _name(defender)], defender.id)
		return

	var damage_records: Array = action.get("damage", [])
	var total := _deal_damage(attacker, defender, damage_records, result.critical)
	var key := "LOG_ATTACK_CRIT" if result.critical else "LOG_ATTACK_HIT"
	_log(key, [_name(attacker), _name(defender), total], defender.id)

	_apply_rider(attacker, defender, action)
	_report_death(defender)


## The bonus added to an attack roll.
##
## A monster carries its total as data; the player's is built from the ability
## their weapon uses, their proficiency and whatever their equipment adds.
func _attack_modifier(attacker: Combatant, action: Dictionary) -> int:
	if not attacker.is_player:
		return int(action.get("attack_bonus", 0))
	return (
		attacker.abilities.modifier(attacker.attack_ability)
		+ attacker.proficiency_bonus
		+ attacker.attack_bonus
	)


## Rolls and applies every part of a hit, and returns the total that landed.
##
## Each typed part is resisted separately, because a weapon that deals slashing
## and fire against something that resists fire should have the fire halved and
## the slashing left alone.
func _deal_damage(
	attacker: Combatant, defender: Combatant, records: Array, critical: bool
) -> int:
	var parts: Array = records.duplicate()
	if attacker.is_player:
		parts.append_array(attacker.bonus_damage)

	var total := 0
	for record: Dictionary in parts:
		var expression := String(record.get("dice", "0d0"))
		var damage_type := String(record.get("type", "bludgeoning"))
		var rolled := (
			Dice.roll_critical(_stream, expression)
			if critical
			else Dice.roll(_stream, expression)
		)
		var applied := Damage.apply(
			damage_type,
			rolled,
			defender.damage_resistances,
			defender.damage_immunities,
			defender.damage_vulnerabilities
		)
		_log_defence(defender, applied)
		total += applied.amount

	defender.take_damage(total)
	return total


## Notes a resistance, immunity or vulnerability that changed the amount.
func _log_defence(defender: Combatant, applied: Damage.Result) -> void:
	var type_name := tr(Damage.name_key(applied.damage_type))
	match applied.applied:
		Damage.Applied.RESISTED:
			_log("LOG_RESISTED", [_name(defender), type_name], defender.id)
		Damage.Applied.IMMUNE:
			_log("LOG_IMMUNE", [_name(defender), type_name], defender.id)
		Damage.Applied.VULNERABLE:
			_log("LOG_VULNERABLE", [_name(defender), type_name], defender.id)


## Applies a saving throw rider attached to an attack, from the monster's own
## action or from the player's equipment.
func _apply_rider(attacker: Combatant, defender: Combatant, action: Dictionary) -> void:
	var riders: Array = []
	if action.has("rider_save"):
		var rider: Dictionary = action["rider_save"]
		riders.append({
			"ability": rider.get("ability", "con"),
			"difficulty_class": rider.get("difficulty_class", 10),
			"condition": rider.get("on_failure_condition", ""),
			"rounds": rider.get("condition_rounds", 1),
		})
	if attacker.is_player:
		for effect: Dictionary in attacker.on_hit_conditions:
			riders.append({
				"ability": effect.get("save_ability", "con"),
				"difficulty_class": effect.get("difficulty_class", 10),
				"condition": effect.get("condition", ""),
				"rounds": effect.get("rounds", 1),
			})

	for rider: Dictionary in riders:
		_saving_throw(defender, rider)


## Rolls one saving throw and applies the condition if it fails.
func _saving_throw(defender: Combatant, rider: Dictionary) -> void:
	var ability := String(rider["ability"])
	var ability_name := tr(Abilities.name_key(ability))
	var modifier := defender.abilities.modifier(ability)
	var result := Checks.resolve(_stream, modifier, int(rider["difficulty_class"]))
	if result.succeeded:
		_log("LOG_SAVE_SUCCESS", [_name(defender), ability_name], defender.id)
		return

	_log("LOG_SAVE_FAILURE", [_name(defender), ability_name], defender.id)
	var condition := String(rider["condition"])
	if condition.is_empty():
		return
	if defender.apply_condition(condition, int(rider["rounds"])):
		_log(
			"LOG_CONDITION_APPLIED",
			[_name(defender), tr(Conditions.name_key(condition))],
			defender.id
		)


func _report_death(defender: Combatant) -> void:
	if not defender.is_alive():
		_log("LOG_DEFEATED", [_name(defender)], defender.id)


# --- Powers ------------------------------------------------------------------


## Applies a power's effect. Each kind is a small, separate case on purpose:
## a power that did several of these at once would be a spell system, and this
## milestone does not have one.
func _apply_power(power: Dictionary, target_id: String) -> void:
	var kind := String(power.get("kind", ""))
	match kind:
		"self_heal":
			var restored := _player.heal(Dice.roll(_stream, String(power.get("heal", "1d4"))))
			_log("LOG_HEALED", [_name(_player), restored], _player.id)
		"self_condition":
			var condition := String(power.get("condition", ""))
			if _player.apply_condition(condition, int(power.get("rounds", 1))):
				_log(
					"LOG_CONDITION_APPLIED",
					[_name(_player), tr(Conditions.name_key(condition))],
					_player.id
				)
		"attack_single_enemy", "attack_with_advantage":
			var target := _monster(target_id)
			if target != null and target.is_alive():
				_power_attack(power, target, kind == "attack_with_advantage")
		"attack_all_enemies":
			for target: Combatant in living_monsters():
				_power_attack(power, target, false)
		"save_all_enemies":
			for target: Combatant in living_monsters():
				_power_save(power, target)


## A power that resolves as an attack roll against one target.
func _power_attack(power: Dictionary, target: Combatant, with_advantage: bool) -> void:
	var bias := (
		Checks.Bias.ADVANTAGE
		if with_advantage
		else Checks.combine_bias(
			target.conditions.gives_attackers_advantage(),
			_player.conditions.gives_sufferer_disadvantage()
		)
	)
	var ability := String(power.get("attack_ability", _player.attack_ability))
	var modifier := (
		_player.abilities.modifier(ability) + _player.proficiency_bonus + _player.attack_bonus
	)
	var result := Checks.resolve(_stream, modifier, target.effective_armour_class(), bias)
	if not result.succeeded:
		_log("LOG_ATTACK_MISS", [_name(_player), _name(target)], target.id)
		return

	var total := _deal_damage(_player, target, power.get("damage", []), result.critical)
	var key := "LOG_ATTACK_CRIT" if result.critical else "LOG_ATTACK_HIT"
	_log(key, [_name(_player), _name(target), total], target.id)
	_report_death(target)


## A power that every target rolls a saving throw against.
func _power_save(power: Dictionary, target: Combatant) -> void:
	var ability := String(power.get("save_ability", "dex"))
	var modifier := target.abilities.modifier(ability)
	var result := Checks.resolve(_stream, modifier, int(power.get("difficulty_class", 12)))
	var key := "LOG_SAVE_SUCCESS" if result.succeeded else "LOG_SAVE_FAILURE"
	_log(key, [_name(target), tr(Abilities.name_key(ability))], target.id)

	var total := 0
	for record: Dictionary in power.get("damage", []):
		var rolled := Dice.roll(_stream, String(record.get("dice", "1d6")))
		var applied := Damage.apply(
			String(record.get("type", "force")),
			rolled,
			target.damage_resistances,
			target.damage_immunities,
			target.damage_vulnerabilities
		)
		_log_defence(target, applied)
		total += applied.amount

	if result.succeeded and bool(power.get("half_damage_on_success", false)):
		total = total / 2
	elif result.succeeded:
		total = 0

	target.take_damage(total)
	_log("LOG_ATTACK_HIT", [_name(_player), _name(target), total], target.id)
	_report_death(target)


# --- Helpers -----------------------------------------------------------------


## The player's weapon attack, assembled from their equipment.
func _player_weapon_attack() -> Dictionary:
	return {"damage": _player.attacks[0].get("damage", []) if not _player.attacks.is_empty() else []}


func _monster(target_id: String) -> Combatant:
	for monster in _monsters:
		if monster.id == target_id:
			return monster
	return null


func _name(combatant: Combatant) -> String:
	return tr(combatant.name_key)


func _log(key: String, values: Array, subject: String) -> void:
	_events.append(CombatEvent.new(key, values, subject))
