extends Control
## The branching map, and the choice of where to go next.
##
## Rooms are laid out in a column per depth with the reachable ones focusable
## and everything else dimmed and skipped. Keyboard traversal follows the
## graph's own edges rather than the screen's geometry, so pressing right moves
## along a path that actually exists.

signal node_chosen(node_id: String)

@onready var _heading: Label = %Heading
@onready var _columns: HBoxContainer = %Columns

var _controller: RunController
var _buttons: Dictionary = {}


func bind(controller: RunController) -> void:
	_controller = controller
	_heading.text = tr("MAP_HEADING")
	_build()
	_apply_adaptive_layout()
	get_viewport().size_changed.connect(_apply_adaptive_layout)


func _build() -> void:
	for child in _columns.get_children():
		child.queue_free()
	_buttons.clear()

	var graph := _controller.state.graph
	var reachable := _controller.available_exits()
	var reachable_ids := PackedStringArray()
	for node in reachable:
		reachable_ids.append(node.id)

	var first_focusable: Button = null
	for depth in range(graph.deepest_depth() + 1):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 8)
		_columns.add_child(column)

		for node in graph.nodes_at_depth(depth):
			var button := _build_button(node, node.id in reachable_ids)
			column.add_child(button)
			_buttons[node.id] = button
			if first_focusable == null and not button.disabled:
				first_focusable = button

	if first_focusable != null:
		first_focusable.grab_focus()
	_wire_focus_along_edges()


func _build_button(node: MapNode, is_reachable: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(120, Layout.target_height())
	button.text = tr(node.kind_name_key())
	button.disabled = not is_reachable

	if node.resolved:
		button.text = "%s ✓" % button.text
		button.tooltip_text = tr("MAP_ROOM_CLEARED")
	elif not is_reachable:
		button.tooltip_text = tr("MAP_ROOM_UNREACHABLE")

	# A disabled button is skipped by focus navigation, which is exactly what
	# keeps a keyboard player from landing on a room they cannot enter.
	button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	if is_reachable:
		button.pressed.connect(func() -> void: node_chosen.emit(node.id))
	return button


## Points each reachable room's rightward focus at a room it actually connects
## to, so arrow keys walk the graph rather than the screen.
func _wire_focus_along_edges() -> void:
	var graph := _controller.state.graph
	for node in graph.nodes():
		var button: Button = _buttons.get(node.id, null)
		if button == null or node.exits.is_empty():
			continue
		var target: Button = _buttons.get(node.exits[0], null)
		if target != null:
			button.focus_neighbor_right = target.get_path()


func _apply_adaptive_layout() -> void:
	_columns.add_theme_constant_override("separation", 24 if Layout.is_wide(self) else 12)
