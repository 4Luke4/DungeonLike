extends Control
## How the run ended, and the seed that would produce it again.
##
## The seed is shown deliberately, and so is the archetype: a run is a function
## of both, so a seed on its own does not reproduce what happened. A bug report
## that carries only one of them cannot be investigated.

signal finished

var _controller: RunController

@onready var _heading: Label = %Heading
@onready var _details: Label = %Details
@onready var _seed_label: Label = %SeedLabel
@onready var _copy_button: Button = %CopyButton
@onready var _done_button: Button = %DoneButton


func bind(controller: RunController) -> void:
	_controller = controller
	var state := controller.state

	_heading.text = tr("SUMMARY_VICTORY") if state.victorious else tr("SUMMARY_DEFEAT")
	_details.text = _build_details(state)
	_seed_label.text = tr("RUN_SEED_LABEL") % state.seed_hex

	_copy_button.text = tr("SUMMARY_COPY_SEED")
	_done_button.text = tr("SUMMARY_NEW_RUN")
	_copy_button.custom_minimum_size.y = Layout.target_height()
	_done_button.custom_minimum_size.y = Layout.target_height()
	_copy_button.pressed.connect(_on_copy)
	_done_button.pressed.connect(func() -> void: finished.emit())
	_done_button.grab_focus()


func _build_details(state: RunState) -> String:
	var archetype := _controller.content.by_id(state.archetype_id)
	var lines: Array[String] = [
		tr("SUMMARY_ARCHETYPE") % tr(String(archetype.get("name_key", ""))),
		tr("SUMMARY_DEPTH_REACHED") % state.depth,
		tr("SUMMARY_ENEMIES_DEFEATED") % state.enemies_defeated,
	]
	if state.best_item != null:
		lines.append(
			tr("SUMMARY_BEST_ITEM") % ItemNaming.display_name(state.best_item, _controller.content)
		)
	return "\n".join(lines)


func _on_copy() -> void:
	DisplayServer.clipboard_set(_controller.state.seed_hex)
	_copy_button.text = tr("SUMMARY_SEED_COPIED")
	_copy_button.disabled = true
