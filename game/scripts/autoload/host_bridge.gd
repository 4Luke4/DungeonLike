extends Node
## Single access point to the Android host.
##
## Every platform capability the engine cannot provide for itself — real
## platform entropy, the panel's refresh rates, which input hardware is
## attached, achievements — arrives through the host plugin registered by the
## Kotlin activity. Nothing else in the project may call
## [method Engine.get_singleton] for it.
##
## The indirection is not ceremony. The project must still run in the editor on
## a desktop machine, where no Android host exists, so every call here degrades
## to a documented fallback instead of failing. Code that talked to the
## singleton directly would work on device and crash in the editor.

## Emitted when a keyboard, pointer or controller is attached or detached.
signal input_devices_changed(has_keyboard: bool, has_pointer: bool, has_controller: bool)

## Floor for any refresh rate the engine or the host reports.
##
## [method DisplayServer.screen_get_refresh_rate] returns -1 when it cannot
## query the display, which happens headlessly and on some devices. Passing that
## through would set a negative frame cap and, through [FramePacingService],
## leave the game running uncapped or not at all. Every Android display
## refreshes at least this fast, and the Kotlin host applies the same floor.
const FALLBACK_REFRESH_RATE_HZ := 60

## Name the Kotlin plugin registers itself under. It is spelled in exactly one
## other place, `HostPlugin.PLUGIN_NAME`; changing either alone silently
## disconnects the game from the host.
const PLUGIN_NAME := "DungeonLikeHost"

var _plugin: Object = null


func _ready() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
		_plugin.connect("input_devices_changed", _on_input_devices_changed)
	else:
		# Expected in the editor and on desktop builds. It is logged rather than
		# asserted because a developer running the project on a laptop is a
		# supported workflow, not an error.
		print_verbose("Host plugin '%s' unavailable; using engine-only fallbacks." % PLUGIN_NAME)


## Whether the Android host is present. Callers use this to record how a run was
## seeded and to decide whether platform-specific interface hints make sense.
func is_available() -> bool:
	return _plugin != null


## Returns [param byte_count] bytes of platform entropy.
##
## Returns an empty array when no host is present; [RngService] treats that as
## "this source contributed nothing" and seeds the run from the engine's
## generator alone, recording that it did so.
func host_entropy(byte_count: int) -> PackedByteArray:
	if _plugin == null:
		return PackedByteArray()
	return _plugin.hostEntropy(byte_count)


## Refresh rate of the display's current mode, in hertz.
##
## Falls back to the engine's own reading, which is what the editor and desktop
## builds use.
func display_refresh_rate_hz() -> int:
	var reported := 0
	if _plugin == null:
		reported = int(round(DisplayServer.screen_get_refresh_rate()))
	else:
		reported = _plugin.displayRefreshRateHz()
	return reported if reported > 0 else FALLBACK_REFRESH_RATE_HZ


## Every refresh rate the display supports, ascending.
##
## The settings screen offers these as frame rate caps rather than a hardcoded
## list that a given panel may not support at all.
func supported_refresh_rates_hz() -> PackedInt32Array:
	if _plugin == null:
		return PackedInt32Array([display_refresh_rate_hz()])

	# The host reports what the panel advertises, but a rate of zero or less is
	# not something the game can cap to, so an unusable list degrades to the
	# single rate the display is running at rather than to nothing.
	var usable := PackedInt32Array()
	for rate: int in _plugin.supportedRefreshRatesHz():
		if rate > 0:
			usable.append(rate)
	if usable.is_empty():
		usable.append(display_refresh_rate_hz())
	return usable


## Whether a physical alphabetic keyboard is attached.
func has_physical_keyboard() -> bool:
	if _plugin == null:
		# Desktop always has one; treating the editor as keyboard-capable is
		# what makes keyboard navigation testable without a device.
		return not OS.has_feature("mobile")
	return _plugin.hasPhysicalKeyboard()


## Whether a mouse, trackpad or stylus is attached.
func has_pointer_device() -> bool:
	if _plugin == null:
		return not OS.has_feature("mobile")
	return _plugin.hasPointerDevice()


## Whether a gamepad or joystick is attached.
func has_game_controller() -> bool:
	if _plugin == null:
		return not Input.get_connected_joypads().is_empty()
	return _plugin.hasGameController()


## Whether an achievement backend is present.
func achievements_available() -> bool:
	if _plugin == null:
		return false
	return _plugin.achievementsAvailable()


## Reports an achievement as unlocked.
##
## Progress is always recorded in the local save as well, so a run played with
## no backend is not lost; this only tells the platform.
func unlock_achievement(achievement_id: String) -> void:
	if _plugin == null:
		return
	_plugin.unlockAchievement(achievement_id)


## Adds progress to an incremental achievement.
func increment_achievement(achievement_id: String, steps: int) -> void:
	if _plugin == null:
		return
	_plugin.incrementAchievement(achievement_id, steps)


func _on_input_devices_changed(has_keyboard: bool, has_pointer: bool, has_controller: bool) -> void:
	input_devices_changed.emit(has_keyboard, has_pointer, has_controller)
