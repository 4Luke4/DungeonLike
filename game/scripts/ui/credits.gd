extends Control
## Credits and licence notices.
##
## This screen is a licensing obligation, not decoration. The rules vocabulary
## the game is built on is used under a Creative Commons Attribution licence
## that requires a specific attribution statement to be reproduced exactly, and
## the engine and its bundled libraries are used under licences that require
## their notices to accompany the distribution.
##
## The engine's own notices are read from the running engine rather than copied
## into this project, so they can never describe a different build from the one
## the player is running.

@onready var _body: RichTextLabel = %Body
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	FramePacingService.set_idle(true)
	_body.text = _build_notices()
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.grab_focus()


func _build_notices() -> String:
	var sections := PackedStringArray()

	sections.append("[b]%s[/b]" % tr("CREDITS_GAME_HEADING"))
	sections.append(tr("CREDITS_GAME_BODY"))

	# Reproduced exactly as the licence requires; it must not be reworded, and
	# no further attribution may be added alongside it. See
	# THIRD_PARTY_NOTICES.md.
	sections.append("[b]%s[/b]" % tr("CREDITS_RULES_HEADING"))
	sections.append(tr("CREDITS_SRD_ATTRIBUTION"))

	sections.append("[b]%s[/b]" % tr("CREDITS_ENGINE_HEADING"))
	sections.append(Engine.get_license_text())

	sections.append("[b]%s[/b]" % tr("CREDITS_THIRD_PARTY_HEADING"))
	for entry: Dictionary in Engine.get_copyright_info():
		var component: String = entry.get("name", "")
		if not component.is_empty():
			sections.append("- " + component)

	return "\n\n".join(sections)


func _on_back_pressed() -> void:
	var status := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if status != OK:
		push_error("Failed to return to the main menu (%d)." % status)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
