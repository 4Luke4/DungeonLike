class_name RunStore
extends RefCounted
## Writes, authenticates and reads back the run in progress.
##
## Android kills backgrounded processes whenever it needs the memory, so a run
## that existed only in memory would be lost to an incoming telephone call. The
## run is therefore written at every room boundary — never mid-turn, which keeps
## the stored state small and the reload path trivial.
##
## The file carries an HMAC tag produced by a key that lives in the Android
## Keystore and never leaves it. The point is [b]detection[/b], not prevention:
## the threat model is explicit that the device owner is not an adversary, and
## editing your own save is a decision about your own game. What the tag buys is
## that a save the game did not write is [i]reported[/i] rather than loaded as
## though it were valid, because the alternative is a bug report nobody can
## reproduce.
##
## The seed, archetype and depth are stored in the clear alongside the signed
## payload. That is deliberate: if verification fails, the game can still tell
## the player which seed they were on, so a corrupt save costs them a run rather
## than the dungeon they were enjoying.

## How a load went, so the interface can say something useful about each case.
enum Result { LOADED, NONE, UNREADABLE, TAMPERED }

const SAVE_PATH := "user://run.save"

## Where a save that failed its check is moved. Kept rather than deleted so it
## can be attached to a bug report.
const QUARANTINE_PATH := "user://run.quarantine"

const FORMAT_VERSION := 1


## Whether there is a save worth offering a Continue button for.
##
## Checks that the file parses, not that it verifies: a quarantined save would
## otherwise leave a button that does nothing when pressed.
static func has_resumable_run() -> bool:
	var envelope := _read_envelope()
	return not envelope.is_empty() and not bool(envelope.get("finished", false))


## The seed of the stored run, for reporting a failed load.
static func stored_seed_hex() -> String:
	return String(_read_envelope().get("seed_hex", ""))


## Writes [param state] to disk, signed if a host is available.
func save(state: RunState) -> bool:
	var payload := JSON.stringify(state.to_dict(), "", true, true)
	var payload_bytes := payload.to_utf8_buffer()
	var tag := HostBridge.save_integrity_tag(payload_bytes)

	var envelope := {
		"format": FORMAT_VERSION,
		"seed_hex": state.seed_hex,
		"archetype_id": state.archetype_id,
		"depth": state.depth,
		"finished": state.finished,
		"host_tagged": not tag.is_empty(),
		"payload_b64": Marshalls.raw_to_base64(payload_bytes),
		"tag_hex": tag.hex_encode(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("The run could not be saved (%d)." % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(envelope, "", true, true))
	file.close()
	return true


## Reads the stored run.
##
## Returns the outcome and, when it succeeded, the restored state. A save that
## fails its check is moved aside rather than deleted and is never loaded.
func load_run() -> Dictionary:
	var envelope := _read_envelope()
	if envelope.is_empty():
		return {"result": Result.NONE, "state": null}

	var payload_bytes := Marshalls.base64_to_raw(String(envelope.get("payload_b64", "")))
	if payload_bytes.is_empty():
		return {"result": Result.UNREADABLE, "state": null}

	var was_tagged := bool(envelope.get("host_tagged", false))
	if was_tagged:
		var tag := PackedByteArray(Array(String(envelope.get("tag_hex", "")).hex_decode()))
		if not HostBridge.verify_save_integrity(payload_bytes, tag):
			_quarantine()
			return {"result": Result.TAMPERED, "state": null}

	var parsed: Variant = JSON.parse_string(payload_bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"result": Result.UNREADABLE, "state": null}

	var state := RunState.from_dict(parsed)
	if state == null:
		return {"result": Result.UNREADABLE, "state": null}

	# A save written where no host existed — in the editor, or on a desktop
	# build — carries no signature. It is honoured rather than refused, because
	# the device owner is not an adversary, but the interface says so.
	state.integrity_unverified = not was_tagged
	return {"result": Result.LOADED, "state": state}


## Removes the stored run, once it is finished or abandoned.
func discard() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func _read_envelope() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var envelope: Dictionary = parsed
	return envelope if int(envelope.get("format", 0)) == FORMAT_VERSION else {}


func _quarantine() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	if FileAccess.file_exists(QUARANTINE_PATH):
		DirAccess.remove_absolute(QUARANTINE_PATH)
	DirAccess.rename_absolute(SAVE_PATH, QUARANTINE_PATH)
