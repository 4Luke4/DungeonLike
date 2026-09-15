extends Control
## The screen a whole run is played inside.
##
## Every part of a run — choosing an archetype, the map, a fight, a treasure, a
## rest, the summary — is a view mounted into this one scene rather than a scene
## of its own. That is deliberate and it is what keeps the run out of an
## autoload: the run state lives here, and because nothing ever changes scene
## while a run is in progress, nothing ever destroys it.
##
## This script owns presentation and sequencing. It never decides an outcome:
## every decision goes to [RunController], which resolves it and reports what
## happened. It must never draw from a gameplay stream either — a randomised
## flourish here would shift every later roll and the run would quietly stop
## replaying from its seed. tools/scripts/check_rng_usage.py enforces that by
## forbidding RngService in this directory.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

const VIEW_SCENES := {
	"archetype": "res://scenes/run/archetype_select.tscn",
	"map": "res://scenes/run/map.tscn",
	"encounter": "res://scenes/run/encounter.tscn",
	"treasure": "res://scenes/run/treasure.tscn",
	"rest": "res://scenes/run/rest.tscn",
	"summary": "res://scenes/run/summary.tscn",
}

@onready var _view_host: MarginContainer = %ViewHost
@onready var _depth_label: Label = %DepthLabel
@onready var _health_label: Label = %HealthLabel
@onready var _seed_label: Label = %SeedLabel
@onready var _notice_label: Label = %NoticeLabel

var _controller: RunController
var _store := RunStore.new()
var _current_view: Control = null

## Set by the main menu before this scene is added to the tree.
var resume_requested := false


func _ready() -> void:
	# Play is animated, so the frame cap returns to the panel's rate.
	FramePacingService.set_idle(false)

	var content := ContentDatabase.new()
	if not content.is_loaded():
		push_error("Game content could not be loaded: %s" % ", ".join(content.failures()))
		_return_to_menu()
		return

	_controller = RunController.new(content)
	_notice_label.visible = false

	if resume_requested and _resume():
		_show_map()
	else:
		_show_archetype_select()
	_refresh_status()


## Mounts a view, replacing whatever was showing.
func _show_view(name: String) -> Control:
	if _current_view != null:
		_current_view.queue_free()
		_current_view = null

	var packed: PackedScene = load(VIEW_SCENES[name])
	var view: Control = packed.instantiate()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view_host.add_child(view)
	_current_view = view
	return view


func _resume() -> bool:
	var outcome := _store.load_run()
	match int(outcome["result"]):
		RunStore.Result.LOADED:
			var state: RunState = outcome["state"]
			_controller.resume(state)
			if state.integrity_unverified:
				_show_notice(tr("SAVE_UNVERIFIED_NOTICE"))
			return true
		RunStore.Result.TAMPERED:
			_show_notice(tr("SAVE_INTEGRITY_FAILED"))
		RunStore.Result.UNREADABLE:
			_show_notice(tr("SAVE_INTEGRITY_FAILED"))
	return false


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.visible = true


# --- View sequencing ---------------------------------------------------------


func _show_archetype_select() -> void:
	var view := _show_view("archetype")
	view.archetype_chosen.connect(_on_archetype_chosen)
	view.bind(_controller.content)


func _on_archetype_chosen(archetype_id: String) -> void:
	_controller.start_new_run(archetype_id)
	_store.save(_controller.state)
	_show_map()


func _show_map() -> void:
	FramePacingService.set_idle(true)
	var view := _show_view("map")
	view.node_chosen.connect(_on_node_chosen)
	view.bind(_controller)
	_refresh_status()


func _on_node_chosen(node_id: String) -> void:
	FramePacingService.set_idle(false)
	_controller.enter_node(node_id)
	_refresh_status()

	if _controller.encounter != null:
		_show_encounter()
	elif _controller.pending_item != null:
		_show_treasure()
	elif _controller.state.graph.node(node_id).kind == MapNode.KIND_REST:
		_show_rest()
	else:
		_after_room()


func _show_encounter() -> void:
	var view := _show_view("encounter")
	view.encounter_finished.connect(_on_encounter_finished)
	view.state_changed.connect(_refresh_status)
	view.bind(_controller)


func _on_encounter_finished() -> void:
	_controller.conclude_fight()
	_refresh_status()
	if _controller.state.finished:
		_show_summary()
	elif _controller.pending_item != null:
		_show_treasure()
	else:
		_after_room()


func _show_treasure() -> void:
	var view := _show_view("treasure")
	view.resolved.connect(_after_room)
	view.bind(_controller)


func _show_rest() -> void:
	FramePacingService.set_idle(true)
	var view := _show_view("rest")
	view.resolved.connect(_after_room)
	view.bind(_controller)


func _show_summary() -> void:
	FramePacingService.set_idle(true)
	_store.discard()
	var view := _show_view("summary")
	view.finished.connect(_return_to_menu)
	view.bind(_controller)


## Saves and returns to the map once a room is done with.
func _after_room() -> void:
	_refresh_status()
	if _controller.state.finished:
		_show_summary()
		return
	_store.save(_controller.state)
	_show_map()


func _refresh_status() -> void:
	var state := _controller.state
	if state == null:
		return
	_depth_label.text = tr("MAP_DEPTH") % state.depth
	_health_label.text = "%s %d/%d" % [
		tr("RULES_HIT_POINTS_SHORT"), state.hit_points, state.max_hit_points
	]
	_seed_label.text = tr("RUN_SEED_LABEL") % state.seed_hex


func _return_to_menu() -> void:
	FramePacingService.set_idle(true)
	var status := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if status != OK:
		push_error("Failed to return to the main menu (%d)." % status)


func _notification(what: int) -> void:
	# Android can kill a paused process at any moment, which is the case the
	# save exists for. Writing here rather than only at room boundaries is what
	# makes an interrupted session resumable rather than merely a crashed one.
	if what == NOTIFICATION_APPLICATION_PAUSED and _controller != null:
		if _controller.state != null and not _controller.state.finished:
			_store.save(_controller.state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		if _controller != null and _controller.state != null and not _controller.state.finished:
			_store.save(_controller.state)
		_return_to_menu()
		get_viewport().set_input_as_handled()
