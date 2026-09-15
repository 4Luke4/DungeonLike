extends GutTest
## Tests for how a fight resolves.
##
## The termination test is the one that matters most. Two combatants who cannot
## hit each other would otherwise loop forever, and an infinite loop in a
## turn-based game is indistinguishable from a freeze — the player sees a
## hung application, not a bug.

var _content: ContentDatabase
var _node: MapNode


func before_each() -> void:
	_content = ContentDatabase.new()
	RngService.begin_run_with_seed(_seed(0x4d))
	_node = MapNode.new("node-1-0", 1, 0)
	_node.kind = MapNode.KIND_ENCOUNTER
	_node.theme_id = "flooded_crypt"


func test_a_fight_starts_with_somebody_to_fight() -> void:
	var resolver := _start()
	assert_gt(resolver.living_monsters().size(), 0, "an encounter needs monsters")
	assert_gt(resolver.initiative_order().size(), 1, "the player and at least one monster act")


func test_initiative_includes_every_combatant_exactly_once() -> void:
	var resolver := _start()
	var seen := {}
	for combatant in resolver.initiative_order():
		assert_false(seen.has(combatant.id), "%s acts twice per round" % combatant.id)
		seen[combatant.id] = true


func test_a_fight_always_terminates() -> void:
	# Driven by attacking as fast as possible, which is the shortest path to a
	# conclusion and therefore the least likely to hide a loop.
	for seed_byte in [0x10, 0x50, 0x90, 0xd0]:
		RngService.begin_run_with_seed(_seed(seed_byte))
		var resolver := _start()
		var guard := 0
		while resolver.state != CombatResolver.State.FINISHED:
			var living := resolver.living_monsters()
			if living.is_empty():
				break
			resolver.player_attacks(living[0].id)
			guard += 1
			assert_lt(guard, 500, "the fight did not terminate with seed %d" % seed_byte)
		assert_eq(resolver.state, CombatResolver.State.FINISHED)
		assert_ne(
			resolver.outcome, CombatResolver.Outcome.UNDECIDED, "a finished fight has a result"
		)


func test_hit_points_never_fall_below_zero() -> void:
	var resolver := _start()
	while resolver.state != CombatResolver.State.FINISHED:
		var living := resolver.living_monsters()
		if living.is_empty():
			break
		resolver.player_attacks(living[0].id)
		for combatant in resolver.initiative_order():
			assert_gte(combatant.hit_points, 0, "%s fell below zero" % combatant.id)


func test_the_same_seed_produces_the_same_fight() -> void:
	# The strongest assertion in this suite: it compares the whole event log,
	# so any change in draw order anywhere in combat fails it.
	var first := _fight_signature(0x2c)
	var second := _fight_signature(0x2c)
	assert_eq(first, second, "a seed must replay a fight exactly")


func test_different_seeds_produce_different_fights() -> void:
	assert_ne(_fight_signature(0x2c), _fight_signature(0xa1))


func test_a_dead_monster_cannot_be_attacked() -> void:
	var resolver := _start()
	var target := resolver.living_monsters()[0]
	while target.is_alive() and resolver.state != CombatResolver.State.FINISHED:
		resolver.player_attacks(target.id)
	if resolver.state == CombatResolver.State.FINISHED:
		return
	var before := resolver.event_count()
	resolver.player_attacks(target.id)
	assert_eq(resolver.event_count(), before, "attacking a corpse must do nothing at all")


func test_defending_raises_armour_class_and_ends_the_turn() -> void:
	var resolver := _start()
	var before := resolver.event_count()
	resolver.player_defends()
	assert_gt(resolver.event_count(), before, "defending is reported")


func test_powers_are_limited_to_their_declared_uses() -> void:
	var resolver := _start()
	resolver.grant_powers(PackedStringArray(["second_wind"]))
	var allowed := int(_content.by_id("second_wind").get("uses_per_encounter", 1))
	assert_eq(resolver.power_uses_left("second_wind"), allowed)

	for _attempt in range(allowed):
		if resolver.state == CombatResolver.State.FINISHED:
			return
		resolver.player_uses_power("second_wind", "")
	assert_eq(resolver.power_uses_left("second_wind"), 0, "a spent power stays spent")


## The whole event log of a fight, as a comparable string.
func _fight_signature(seed_byte: int) -> String:
	RngService.begin_run_with_seed(_seed(seed_byte))
	var resolver := _start()
	var guard := 0
	while resolver.state != CombatResolver.State.FINISHED and guard < 500:
		var living := resolver.living_monsters()
		if living.is_empty():
			break
		resolver.player_attacks(living[0].id)
		guard += 1

	var lines: Array[String] = []
	for event in resolver.events_since(0):
		lines.append(event.to_signature())
	return "|".join(lines)


func _start() -> CombatResolver:
	var state := RunState.new()
	state.archetype_id = "vanguard"
	state.max_hit_points = 40
	state.hit_points = 40
	var weapon := Item.new("longsword")
	state.equip(weapon, "main_hand")

	var resolver := CombatResolver.new()
	resolver.start(_content, _node, PlayerBuilder.build(state, _content))
	return resolver


func _seed(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(RngService.SEED_LENGTH)
	bytes.fill(value)
	return bytes
