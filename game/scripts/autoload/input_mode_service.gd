extends Node
## Input bindings and the current input mode.
##
## The game must be equally playable with a touch screen, with a keyboard and
## with a mouse, because Android tablets and desktop-mode devices routinely have
## all three and gain or lose them while the game runs. Two things follow, and
## both live here.
##
## [b]Bindings are registered in code.[/b] Actions could be declared in
## `project.godot`, but that file stores input events as serialised objects that
## are unreadable in review and hostile to hand-editing. Declaring them here
## keeps every binding legible in one table, lets tests assert that an action
## exists, and is the same place player rebinding will hook into.
##
## [b]The mode follows the hardware.[/b] The host reports device changes as they
## happen, and the interface reacts: pointer and keyboard modes show key hints
## and keep focus navigation meaningful, touch mode shows larger targets and no
## hints.

## Emitted when the active input mode changes.
signal mode_changed(mode: Mode)

enum Mode {
	TOUCH,
	POINTER,
	KEYBOARD,
}

## Bindings, as action name to the keys and buttons that trigger it.
##
## Gameplay never reads a raw key: it checks an action, so that rebinding and
## alternative hardware work without touching game code.
##
## The four movement actions are registered and currently unused. The run is
## played across a map of focusable buttons, where the engine's own
## [code]ui_up[/code] and [code]ui_right[/code] own the arrow keys and a focused
## [Control] consumes the event before [method Node._unhandled_input] is
## reached. They are kept rather than deleted because they are the bindings a
## free-movement mode would want, and because deleting them would throw away
## working WASD support to save nine lines.
const KEY_BINDINGS := {
	"move_north": [KEY_W, KEY_UP, KEY_KP_8],
	"move_south": [KEY_S, KEY_DOWN, KEY_KP_2],
	"move_west": [KEY_A, KEY_LEFT, KEY_KP_4],
	"move_east": [KEY_D, KEY_RIGHT, KEY_KP_6],
	"wait_turn": [KEY_PERIOD, KEY_KP_5],
	"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
	"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"open_inventory": [KEY_I, KEY_TAB],
	"open_menu": [KEY_ESCAPE],
	# Encounter actions. Deliberately on the number and letter rows rather than
	# the keypad: KEY_KP_1 and KEY_KP_2 are already bound to movement, and a
	# keycode bound to two actions delivers one press as two, which in a
	# turn-based game means taking two turns from a single keystroke.
	"ability_one": [KEY_1],
	"ability_two": [KEY_2],
	"previous_target": [KEY_Q],
	"next_target": [KEY_E],
}

var _mode: Mode = Mode.TOUCH


func _ready() -> void:
	register_bindings()
	HostBridge.input_devices_changed.connect(_on_input_devices_changed)
	_resolve_initial_mode()


## The active input mode.
func mode() -> Mode:
	return _mode


## Whether key hints should be shown. They are noise on a touch-only device and
## essential on a keyboard.
func should_show_key_hints() -> bool:
	return _mode == Mode.KEYBOARD


## Whether the interface should size its targets for a finger rather than a
## cursor.
func should_use_touch_targets() -> bool:
	return _mode == Mode.TOUCH


## Registers every binding, replacing whatever was bound before.
##
## Existing events are erased first so that calling this twice — which player
## rebinding will do — cannot leave an action bound to the same key twice and
## deliver every press as two.
##
## Keys are bound by physical keycode rather than by character, so the movement
## cluster stays in the same place on an AZERTY or QWERTZ keyboard instead of
## scattering across the board.
func register_bindings() -> void:
	for action: String in KEY_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
		for keycode: int in KEY_BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


func _resolve_initial_mode() -> void:
	_on_input_devices_changed(
		HostBridge.has_physical_keyboard(),
		HostBridge.has_pointer_device(),
		HostBridge.has_game_controller(),
	)


func _on_input_devices_changed(
	has_keyboard: bool, has_pointer: bool, _has_controller: bool
) -> void:
	# A keyboard is the most specific signal: a device with a keyboard attached
	# is being used at a desk, and hiding key hints there would waste the most
	# capable input the player has.
	var resolved := Mode.TOUCH
	if has_keyboard:
		resolved = Mode.KEYBOARD
	elif has_pointer:
		resolved = Mode.POINTER

	if resolved == _mode:
		return
	_mode = resolved
	mode_changed.emit(_mode)


func _input(event: InputEvent) -> void:
	# The reported hardware says what is attached; actual use says what the
	# player has in their hands right now. A tablet with a keyboard case folded
	# behind it should return to touch targets the moment it is tapped.
	if event is InputEventScreenTouch and _mode != Mode.TOUCH:
		_mode = Mode.TOUCH
		mode_changed.emit(_mode)
	elif event is InputEventKey and _mode != Mode.KEYBOARD and HostBridge.has_physical_keyboard():
		_mode = Mode.KEYBOARD
		mode_changed.emit(_mode)
	elif event is InputEventMouseButton and _mode == Mode.TOUCH and HostBridge.has_pointer_device():
		_mode = Mode.POINTER
		mode_changed.emit(_mode)
