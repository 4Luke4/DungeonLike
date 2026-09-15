extends Control
## A fight, as the player sees it.
##
## The view sends one decision at a time to [RunController] and then renders the
## events that came back. It never decides an outcome, and it never draws from a
## gameplay stream: a randomised flourish here would move every later roll and
## the run would stop replaying from its seed without anything appearing to
## break. tools/scripts/check_rng_usage.py forbids RngService in this directory
## for exactly that reason.
##
## Because the whole player turn and every monster turn after it resolve before
## a single frame is drawn, skipping the presentation changes nothing about the
## result. That is what makes a fast-forward safe to add later.

signal encounter_finished
signal state_changed

var _controller: RunController
var _resolver: CombatResolver
var _target_id := ""
var _rendered_events := 0

@onready var _enemies: HBoxContainer = %Enemies
@onready var _log: RichTextLabel = %CombatLog
@onready var _actions: HBoxContainer = %Actions
@onready var _turn_label: Label = %TurnLabel
@onready var _body: BoxContainer = %Body


func bind(controller: RunController) -> void:
	_controller = controller
	_resolver = controller.encounter
	_log.bbcode_enabled = false
	_refresh_all()
	_apply_adaptive_layout()
	get_viewport().size_changed.connect(_apply_adaptive_layout)
	InputModeService.mode_changed.connect(func(_mode: int) -> void: _build_actions())


func _refresh_all() -> void:
	_render_new_events()
	_build_enemies()
	_build_actions()
	_turn_label.text = tr("ENCOUNTER_YOUR_TURN")
	state_changed.emit()


## Appends whatever the resolver produced since the last render.
##
## Reading forward from a cursor rather than rebuilding means the log keeps its
## scroll position and the player can read back through a long fight.
func _render_new_events() -> void:
	for event in _resolver.events_since(_rendered_events):
		_log.append_text(tr(event.message_key).format(event.arguments) + "\n")
	_rendered_events = _resolver.event_count()


func _build_enemies() -> void:
	for child in _enemies.get_children():
		child.queue_free()

	var living := _resolver.living_monsters()
	if living.is_empty():
		return
	if _target_id.is_empty() or not _is_living(_target_id):
		_target_id = living[0].id

	for monster in living:
		_enemies.add_child(_build_enemy_button(monster))


func _build_enemy_button(monster: Combatant) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = Layout.target_height()
	button.toggle_mode = true
	button.button_pressed = monster.id == _target_id
	var conditions := monster.conditions.active()
	var suffix := ""
	if not conditions.is_empty():
		var names: Array[String] = []
		for condition in conditions:
			names.append(tr(Conditions.name_key(condition)))
		suffix = "\n(%s)" % ", ".join(names)
	button.text = (
		"%s\n%s %d/%d%s"
		% [
			tr(monster.name_key),
			tr("RULES_HIT_POINTS_SHORT"),
			monster.hit_points,
			monster.max_hit_points,
			suffix,
		]
	)
	button.pressed.connect(func() -> void: _select_target(monster.id))
	return button


func _select_target(monster_id: String) -> void:
	_target_id = monster_id
	_build_enemies()


func _build_actions() -> void:
	for child in _actions.get_children():
		child.queue_free()

	if _resolver.state == CombatResolver.State.FINISHED:
		_actions.add_child(
			_action_button(tr("ENCOUNTER_CONTINUE"), "", func() -> void: encounter_finished.emit())
		)
		_actions.get_child(0).grab_focus()
		return

	_actions.add_child(_action_button(tr("ENCOUNTER_ATTACK"), "Enter", func() -> void: _attack()))
	_actions.add_child(_action_button(tr("ENCOUNTER_DEFEND"), ".", func() -> void: _defend()))

	var index := 1
	for power_id in _power_ids():
		var power := _controller.content.by_id(power_id)
		var left := _resolver.power_uses_left(power_id)
		var label := (
			"%s (%s)"
			% [
				tr(String(power.get("name_key", ""))),
				(
					tr("ENCOUNTER_USES_LEFT").format([left])
					if left > 0
					else tr("ENCOUNTER_NO_USES_LEFT")
				),
			]
		)
		var button := _action_button(label, str(index), func() -> void: _use_power(power_id))
		button.disabled = left <= 0
		button.tooltip_text = tr(String(power.get("description_key", "")))
		_actions.add_child(button)
		index += 1

	_actions.get_child(0).grab_focus()


func _action_button(label: String, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = Layout.target_height()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = Layout.with_key_hint(label, hint) if not hint.is_empty() else label
	button.pressed.connect(action)
	return button


func _power_ids() -> PackedStringArray:
	var powers := PackedStringArray()
	var archetype := _controller.content.by_id(_controller.state.archetype_id)
	for power_id: Variant in archetype.get("powers", []):
		powers.append(String(power_id))
	return powers


func _attack() -> void:
	if _target_id.is_empty():
		return
	_resolver.player_attacks(_target_id)
	_after_action()


func _defend() -> void:
	_resolver.player_defends()
	_after_action()


func _use_power(power_id: String) -> void:
	_resolver.player_uses_power(power_id, _target_id)
	_after_action()


func _after_action() -> void:
	_refresh_all()
	if _resolver.state == CombatResolver.State.FINISHED:
		_turn_label.text = ""


func _is_living(monster_id: String) -> bool:
	for monster in _resolver.living_monsters():
		if monster.id == monster_id:
			return true
	return false


## Side by side on a tablet, stacked on a phone. The log is the part that
## suffers most from a narrow window, so it goes below rather than beside.
func _apply_adaptive_layout() -> void:
	_body.vertical = not Layout.is_wide(self)


func _unhandled_input(event: InputEvent) -> void:
	if _resolver.state == CombatResolver.State.FINISHED:
		return
	if event.is_action_pressed("wait_turn"):
		_defend()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("next_target"):
		_cycle_target(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("previous_target"):
		_cycle_target(-1)
		get_viewport().set_input_as_handled()


func _cycle_target(step: int) -> void:
	var living := _resolver.living_monsters()
	if living.size() < 2:
		return
	for index in range(living.size()):
		if living[index].id == _target_id:
			_select_target(living[(index + step + living.size()) % living.size()].id)
			return
