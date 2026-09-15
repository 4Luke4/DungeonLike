extends Control
## Main menu.
##
## Nothing here is gameplay: it is the shell the game starts new runs from, and
## the first screen that has to prove the interface rules the project commits
## to — it adapts between phone and tablet, it is fully translated, and it is
## navigable by touch, by keyboard and by pointer alike.

const RUN_SHELL_SCENE := "res://scenes/run_shell.tscn"
const CREDITS_SCENE := "res://scenes/credits.tscn"

@onready var _content: VBoxContainer = %Content
@onready var _new_run_button: Button = %NewRunButton
@onready var _continue_button: Button = %ContinueButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	# A menu does not animate, so it does not need the panel's full refresh rate.
	FramePacingService.set_idle(true)

	_new_run_button.pressed.connect(_on_new_run_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	# Offered only when there is something to continue. The check asks whether a
	# save parses, not whether it verifies, so a quarantined save does not leave
	# a button that does nothing when pressed.
	_continue_button.visible = RunStore.has_resumable_run()
	_credits_button.pressed.connect(_on_credits_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	InputModeService.mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(InputModeService.mode())

	get_viewport().size_changed.connect(_apply_adaptive_layout)
	_apply_adaptive_layout()

	# Keyboard players need something focused to navigate from; without this the
	# first arrow key press does nothing at all.
	_new_run_button.grab_focus()


func _on_new_run_pressed() -> void:
	_start_run(false)


func _on_continue_pressed() -> void:
	_start_run(true)


## Opens the run shell, telling it whether to resume.
##
## The scene is instantiated and configured before it enters the tree rather
## than opened with [method SceneTree.change_scene_to_file], because that call
## defers the swap and gives no opportunity to set anything on the new scene
## before its [method Node._ready] runs — and whether to resume has to be known
## by then.
##
## The run is no longer seeded here. Seeding happens in [RunController] once an
## archetype has been chosen: a seed drawn before that decision would imply the
## choice could not affect what the dungeon holds.
func _start_run(resume: bool) -> void:
	var packed: PackedScene = load(RUN_SHELL_SCENE)
	if packed == null:
		push_error("Failed to load the run shell.")
		return

	var shell: Control = packed.instantiate()
	shell.resume_requested = resume

	FramePacingService.set_idle(false)
	var tree := get_tree()
	tree.root.add_child(shell)
	tree.current_scene.queue_free()
	tree.current_scene = shell


func _on_credits_pressed() -> void:
	var status := get_tree().change_scene_to_file(CREDITS_SCENE)
	if status != OK:
		push_error("Failed to open the credits (%d)." % status)


func _on_quit_pressed() -> void:
	get_tree().quit()


# The parameter is typed as int rather than as InputModeService.Mode: an
# autoload is a node instance, not a class, so its enum cannot name a type here.
func _on_input_mode_changed(_mode: int) -> void:
	_new_run_button.text = Layout.with_key_hint(tr("MENU_NEW_RUN"), "Enter")
	_continue_button.text = tr("MENU_CONTINUE_RUN")


## Adapts to the window the game actually has.
##
## Phones in landscape and tablets differ enough in width that one fixed layout
## is either cramped on the phone or lost in the middle of the tablet. The
## breakpoint switches the content width and spacing rather than swapping in a
## second scene, so there is only one menu to maintain and to translate.
func _apply_adaptive_layout() -> void:
	var viewport_width := float(get_viewport_rect().size.x)
	# The breakpoint is shared with every run screen; restating it here would
	# eventually leave the menu laying out differently from the game it opens.
	var is_wide := Layout.is_wide(self)

	_content.custom_minimum_size.x = minf(viewport_width * (0.4 if is_wide else 0.8), 560.0)
	_content.add_theme_constant_override("separation", 20 if is_wide else 12)
