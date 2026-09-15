extends GutTest
## Tests for input bindings and mode selection.
##
## Bindings are registered in code rather than in `project.godot`, which is what
## makes them testable at all: these assertions are the guarantee that an action
## a scene relies on actually exists, instead of failing silently at runtime as
## an input that never fires.


func test_every_declared_action_is_registered() -> void:
	for action: String in InputModeService.KEY_BINDINGS:
		assert_true(
			InputMap.has_action(action), "action '%s' is declared but was never registered" % action
		)


func test_every_action_has_at_least_one_key() -> void:
	for action: String in InputModeService.KEY_BINDINGS:
		var events := InputMap.action_get_events(action)
		assert_gt(events.size(), 0, "action '%s' has no bound key" % action)


func test_movement_covers_both_common_keyboard_conventions() -> void:
	# Players expect either the arrow keys or the left-hand cluster; a roguelike
	# that only accepts one of them feels broken to half its audience.
	var north := InputMap.action_get_events("move_north")
	var keycodes: Array[int] = []
	for event: InputEvent in north:
		if event is InputEventKey:
			keycodes.append((event as InputEventKey).physical_keycode)

	assert_has(keycodes, KEY_W)
	assert_has(keycodes, KEY_UP)


func test_registration_is_idempotent() -> void:
	# Player rebinding will re-register the whole table. Registering twice must
	# not duplicate events, or one key press would be delivered as two — which
	# in a turn-based game means taking two turns from a single keystroke.
	var before := InputMap.action_get_events("confirm").size()
	InputModeService.register_bindings()
	var after := InputMap.action_get_events("confirm").size()

	assert_eq(after, before, "re-registering must replace bindings, not add to them")


func test_no_keycode_is_bound_to_two_actions() -> void:
	# A key bound to two actions delivers one press as two, which in a
	# turn-based game means taking two turns from a single keystroke. This
	# caught a real collision: the encounter actions were nearly put on the
	# keypad, where KEY_KP_1 and KEY_KP_2 are already movement.
	#
	# cancel and open_menu share Escape deliberately — one closes an overlay and
	# the other opens the menu, and only one of them is ever listening.
	var deliberate_overlap := ["cancel", "open_menu"]
	var owners := {}
	for action: String in InputModeService.KEY_BINDINGS:
		if action in deliberate_overlap:
			continue
		for keycode: int in InputModeService.KEY_BINDINGS[action]:
			assert_false(
				owners.has(keycode),
				"keycode %d is bound to both %s and %s" % [keycode, owners.get(keycode, ""), action]
			)
			owners[keycode] = action


func test_every_action_the_run_uses_is_registered() -> void:
	# The run reads these by name. An action the interface asks for and the
	# table does not declare is not an error at runtime — the press is simply
	# ignored, and the control it belonged to silently stops working.
	for action in ["confirm", "cancel", "wait_turn", "ability_one", "next_target"]:
		assert_true(InputMap.has_action(action), "%s is not registered" % action)
