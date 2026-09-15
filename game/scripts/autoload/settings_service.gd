extends Node
## Player settings, persisted between sessions.
##
## Settings are kept apart from save data on purpose. Saves are authenticated
## against a device-bound key so that a modified save is detected; settings are
## not, because a player editing their own preferences file is not a problem
## worth solving and locking them out of it would be hostile. See
## `docs/architecture/THREAT_MODEL.md`.

## Emitted whenever a value changes, so open screens stay in step.
signal setting_changed(section: String, key: String, value: Variant)

## Where settings live. `user://` resolves to the application's private
## directory, which no other application can read.
const SETTINGS_PATH := "user://settings.cfg"

var _config := ConfigFile.new()


func _ready() -> void:
	var status := _config.load(SETTINGS_PATH)
	if status != OK and status != ERR_FILE_NOT_FOUND:
		# A settings file that exists but cannot be parsed is discarded rather
		# than repaired: defaults are always playable, and refusing to start
		# over a corrupt preferences file would be absurd.
		push_warning(
			(
				"Settings at %s could not be read (%d); defaults will be used."
				% [SETTINGS_PATH, status]
			)
		)
		_config = ConfigFile.new()


## Returns a stored value, or [param default] if it has never been set.
func get_value(section: String, key: String, default: Variant) -> Variant:
	return _config.get_value(section, key, default)


## Stores a value and writes it to disk immediately.
##
## Settings are changed rarely and one at a time, so writing on each change is
## cheaper than tracking dirty state, and it means a setting survives the
## process being killed the moment after it was changed.
func set_value(section: String, key: String, value: Variant) -> void:
	if _config.get_value(section, key, null) == value:
		return
	_config.set_value(section, key, value)
	var status := _config.save(SETTINGS_PATH)
	if status != OK:
		push_warning("Settings could not be saved to %s (%d)." % [SETTINGS_PATH, status])
	setting_changed.emit(section, key, value)
