class_name CombatEvent
extends RefCounted
## One line of what happened, in a form the interface can render and a test can
## compare.
##
## The resolver produces these; it never formats a sentence and never calls
## [method Object.tr]. That separation is what lets the same event log be
## asserted against in a test, replayed at any speed by the interface, and read
## in any of the five shipped languages without the simulation knowing which.
##
## [member arguments] are already-localised fragments or numbers, positional in
## the order the message key expects.

## The localisation key of the sentence to show.
var message_key: String

## Values to substitute into it, in order.
var arguments: Array = []

## Which combatant the line is about, for highlighting. May be empty.
var subject_id: String


func _init(key: String, values: Array = [], subject: String = "") -> void:
	message_key = key
	arguments = values
	subject_id = subject


## A compact form used by the determinism tests, where comparing whole objects
## would compare identities rather than contents.
func to_signature() -> String:
	return "%s(%s)" % [message_key, ",".join(arguments.map(func(value): return str(value)))]


func to_dict() -> Dictionary:
	return {"key": message_key, "arguments": arguments, "subject": subject_id}


static func from_dict(stored: Dictionary) -> CombatEvent:
	return CombatEvent.new(
		String(stored.get("key", "")),
		stored.get("arguments", []),
		String(stored.get("subject", ""))
	)
