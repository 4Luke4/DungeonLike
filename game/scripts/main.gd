extends Control
## Walking-skeleton entry scene.
##
## Proves the vertical slice end to end: the engine boots inside the Kotlin
## host, reaches the host bridge, reads the current input mode, and keeps it up
## to date when peripherals are attached or removed mid-session.
##
## This scene is scaffolding for the milestone, not game UI. It is replaced when
## the real menu and HUD land.

## Name of the engine singleton the Android host registers.
## Must match `HostBridge.PLUGIN_NAME` on the Kotlin side; a mismatch is silent,
## because a missing singleton is an absent lookup rather than an error.
const HOST_SINGLETON := "DungeonLikeHost"

## Signal emitted by the host when the attached input devices change.
## Must match `HostBridge.SIGNAL_INPUT_MODE_CHANGED`.
const SIGNAL_INPUT_MODE_CHANGED := "input_mode_changed"

## Values the host is allowed to report, mapped to what the player is told.
## The host returns a closed set, so anything outside it means the two sides
## have drifted apart and is surfaced rather than silently ignored.
const INPUT_MODE_LABELS := {
	"touch": "Touch",
	"mouse": "Mouse",
	"keyboard": "Keyboard",
	"mouse_and_keyboard": "Mouse and keyboard",
}

@onready var _engine_label: Label = %EngineLabel
@onready var _input_mode_label: Label = %InputModeLabel


func _ready() -> void:
	_engine_label.text = "Godot %s" % Engine.get_version_info().get("string", "unknown")

	var host: Object = _host_bridge()
	if host == null:
		# Expected when the project is run from the editor rather than from the
		# Android host, so it is reported plainly instead of treated as a fault.
		_input_mode_label.text = "Host bridge unavailable"
		return

	host.connect(SIGNAL_INPUT_MODE_CHANGED, _on_input_mode_changed)
	_on_input_mode_changed(host.getInputMode())


## Returns the host bridge singleton, or null when not running inside the host.
func _host_bridge() -> Object:
	if not Engine.has_singleton(HOST_SINGLETON):
		return null
	return Engine.get_singleton(HOST_SINGLETON)


## Renders the current interaction model.
##
## Everything crossing the bridge is treated as untrusted (THREAT_MODEL.md,
## boundary 4), so an unrecognised value is displayed as unknown rather than
## being pasted into the interface unchecked.
func _on_input_mode_changed(input_mode: String) -> void:
	_input_mode_label.text = INPUT_MODE_LABELS.get(input_mode, "Unknown input mode")
