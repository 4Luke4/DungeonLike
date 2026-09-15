extends Node
## Frame rate and power policy.
##
## The product target is a sustained 60, 90 or 120 frames per second on the
## panel the device actually has, without the battery cost that an uncapped
## renderer brings. Those two goals pull against each other, and the settings
## that reconcile them are not the engine defaults, so they are set here in one
## place. No other script may change [member Engine.max_fps], the V-Sync mode or
## low-processor mode.
##
## Three decisions, each with a reason:
##
## [b]V-Sync stays enabled.[/b] Rendering frames the panel never shows costs
## power and gains nothing on a device whose display cannot tear.
##
## [b]Swappy runs in pipeline_forced_on.[/b] The Android frame pacer's automatic
## modes lower the frame rate cap on their own once frames are missed, and they
## do not raise it again — a 120 Hz device that stutters briefly stays capped
## lower for the rest of the session. The forced mode honours the cap this
## service sets. It is configured in `project.godot`; this service sets the cap
## that mode honours.
##
## [b]The cap comes from the panel, not from a constant.[/b] Asking the display
## what it can do is the only way a single build runs correctly on 60, 90 and
## 120 Hz hardware.

## Frame rate cap while the game is idle on a static screen, in hertz. Menus do
## not animate continuously, and drawing them at panel rate is pure battery
## cost.
const IDLE_FPS := 30

## Sleep between iterations in low-processor mode, in microseconds. Roughly one
## eighth of a frame at 60 Hz: long enough to matter, short enough that input
## still feels immediate.
const IDLE_SLEEP_USEC := 2000

## Emitted when the effective cap changes, so the interface can show it.
signal frame_cap_changed(fps: int)

var _preferred_cap := 0
var _idle := false


func _ready() -> void:
	# The panel is the default cap: 0 would mean uncapped, which on a 120 Hz
	# device renders frames the display never shows.
	apply_preferred_cap(HostBridge.display_refresh_rate_hz())


## Frame rates the player can choose between, ascending.
##
## Derived from what the display reports rather than hardcoded, so the settings
## screen never offers a rate the panel cannot produce.
func available_caps() -> PackedInt32Array:
	return HostBridge.supported_refresh_rates_hz()


## Sets the cap the player prefers, clamped to what the panel supports.
func apply_preferred_cap(fps: int) -> void:
	var supported := available_caps()
	var highest := supported[supported.size() - 1] if not supported.is_empty() else fps
	_preferred_cap = clampi(fps, 1, highest)
	_apply()


## The cap currently in force, which is the idle cap while idling.
func current_cap() -> int:
	return IDLE_FPS if _idle else _preferred_cap


## Declares whether the game is showing a static screen.
##
## Called by menus and other non-animating scenes. A menu left open on a table
## should not drain the battery like active play does.
func set_idle(idle: bool) -> void:
	if _idle == idle:
		return
	_idle = idle
	_apply()


func _apply() -> void:
	var cap := current_cap()
	Engine.max_fps = cap
	# Low-processor mode sleeps between iterations instead of spinning, which is
	# what actually saves power; the frame cap alone only limits rendering.
	OS.low_processor_usage_mode = _idle
	OS.low_processor_usage_mode_sleep_usec = IDLE_SLEEP_USEC
	frame_cap_changed.emit(cap)
