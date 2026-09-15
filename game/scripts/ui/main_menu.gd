extends Control
## Main menu.
##
## Nothing here is gameplay: it is the shell the game starts new runs from, and
## the first screen that has to prove the interface rules the project commits
## to — it adapts between phone and tablet, it is fully translated, and it is
## navigable by touch, by keyboard and by pointer alike.

const RUN_SHELL_SCENE := "res://scenes/run_shell.tscn"
const CREDITS_SCENE := "res://scenes/credits.tscn"

## Width, in layout pixels, at or above which the menu uses its wider layout.
## Chosen to sit between a phone in landscape and a small tablet.
const TABLET_BREAKPOINT := 900.0

@onready var _content: VBoxContainer = %Content
@onready var _new_run_button: Button = %NewRunButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _seed_label: Label = %SeedLabel


func _ready() -> void:
	# A menu does not animate, so it does not need the panel's full refresh rate.
	FramePacingService.set_idle(true)

	_new_run_button.pressed.connect(_on_new_run_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	InputModeService.mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(InputModeService.mode())

	get_viewport().size_changed.connect(_apply_adaptive_layout)
	_apply_adaptive_layout()

	# Keyboard players need something focused to navigate from; without this the
	# first arrow key press does nothing at all.
	_new_run_button.grab_focus()
	_seed_label.text = ""


func _on_new_run_pressed() -> void:
	var run_seed := RngService.begin_run()
	# Shown so a player can quote it in a bug report or replay the run later.
	_seed_label.text = tr("MENU_SEED_LABEL") % run_seed.hex_encode()

	FramePacingService.set_idle(false)
	var status := get_tree().change_scene_to_file(RUN_SHELL_SCENE)
	if status != OK:
		push_error("Failed to start a run (%d)." % status)
		FramePacingService.set_idle(true)


func _on_credits_pressed() -> void:
	var status := get_tree().change_scene_to_file(CREDITS_SCENE)
	if status != OK:
		push_error("Failed to open the credits (%d)." % status)


func _on_quit_pressed() -> void:
	get_tree().quit()


# The parameter is typed as int rather than as InputModeService.Mode: an
# autoload is a node instance, not a class, so its enum cannot name a type here.
func _on_input_mode_changed(_mode: int) -> void:
	var show_hints := InputModeService.should_show_key_hints()
	_new_run_button.text = tr("MENU_NEW_RUN") + (" [Enter]" if show_hints else "")


## Adapts to the window the game actually has.
##
## Phones in landscape and tablets differ enough in width that one fixed layout
## is either cramped on the phone or lost in the middle of the tablet. The
## breakpoint switches the content width and spacing rather than swapping in a
## second scene, so there is only one menu to maintain and to translate.
func _apply_adaptive_layout() -> void:
	var viewport_width := float(get_viewport_rect().size.x)
	var is_wide := viewport_width >= TABLET_BREAKPOINT

	_content.custom_minimum_size.x = minf(viewport_width * (0.4 if is_wide else 0.8), 560.0)
	_content.add_theme_constant_override("separation", 20 if is_wide else 12)
