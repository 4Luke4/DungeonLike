extends Control
## First scene of the game.
##
## It exists so that the transition from the Android splash screen to the menu
## is deliberate rather than accidental. The autoloads have already run by the
## time this scene is ready; what happens here is the work that must not happen
## while the splash screen is still covering the window, and the one frame of
## breathing room that lets the engine finish warming up before the menu
## animates in.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_status_label.text = tr("BOOT_PREPARING")

	# Yield one processed frame so the first menu frame is not competing with
	# engine start-up work; without it the menu's first frame is visibly late on
	# slower devices.
	await get_tree().process_frame

	var status := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if status != OK:
		# The only realistic cause is a pack that did not ship the scene, which
		# is a packaging fault rather than something the player can act on.
		push_error("Failed to open the main menu (%d)." % status)
		_status_label.text = tr("BOOT_FAILED")
