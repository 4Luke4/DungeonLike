extends Control
## Container a run is played inside.
##
## It is deliberately empty. Dungeon generation, encounters and loot are not
## implemented yet; this scene exists so that the boundary they will mount into
## is established, and so that the path from the menu into a seeded run is
## exercised end to end from the first day.

@onready var _seed_label: Label = %SeedLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	# Play is animated, so the frame cap returns to the panel's rate.
	FramePacingService.set_idle(false)

	_seed_label.text = tr("RUN_SEED_LABEL") % RngService.run_seed_hex()
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.grab_focus()


func _on_back_pressed() -> void:
	FramePacingService.set_idle(true)
	var status := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if status != OK:
		push_error("Failed to return to the main menu (%d)." % status)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
