extends Control
## Choosing who makes the descent.
##
## This is the first decision of a run and it is taken before the seed is drawn.
## That order matters: a seed drawn first would imply the choice could not affect
## what the dungeon holds, and the run summary reports both because a seed alone
## does not reproduce a run.

signal archetype_chosen(archetype_id: String)

var _content: ContentDatabase
var _selected := ""

@onready var _heading: Label = %Heading
@onready var _cards: BoxContainer = %Cards


func bind(content: ContentDatabase) -> void:
	_content = content
	_heading.text = tr("ARCHETYPE_SELECT_HEADING")
	_build_cards()
	_apply_adaptive_layout()
	get_viewport().size_changed.connect(_apply_adaptive_layout)
	InputModeService.mode_changed.connect(_on_input_mode_changed)


func _build_cards() -> void:
	var archetypes := _content.all("archetypes")
	for index in range(archetypes.size()):
		var archetype: Dictionary = archetypes[index]
		var card := _build_card(archetype, index)
		_cards.add_child(card)
		# Keyboard players need somewhere to start, or the first arrow press
		# does nothing at all.
		if index == 0:
			card.grab_focus()


func _build_card(archetype: Dictionary, index: int) -> Button:
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = Layout.target_height() * 3
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.clip_text = false
	card.text = _card_text(archetype, index)
	card.pressed.connect(_on_card_pressed.bind(String(archetype.get("id", ""))))
	return card


func _card_text(archetype: Dictionary, index: int) -> String:
	var name := tr(String(archetype.get("name_key", "")))
	var description := tr(String(archetype.get("description_key", "")))
	return "%s\n\n%s" % [Layout.with_key_hint(name, str(index + 1)), description]


func _on_card_pressed(archetype_id: String) -> void:
	_selected = archetype_id
	archetype_chosen.emit(_selected)


func _on_input_mode_changed(_mode: int) -> void:
	# A keyboard can be attached mid-run, so the hints are rebuilt rather than
	# decided once at start-up.
	var archetypes := _content.all("archetypes")
	for index in range(mini(archetypes.size(), _cards.get_child_count())):
		var card := _cards.get_child(index) as Button
		card.text = _card_text(archetypes[index], index)


## A phone in landscape cannot show three cards side by side and stay readable,
## so below the breakpoint they stack.
func _apply_adaptive_layout() -> void:
	_cards.vertical = not Layout.is_wide(self)


func _unhandled_input(event: InputEvent) -> void:
	# Number keys select directly, which is faster than walking the row and is
	# what the hints promise.
	for index in range(_cards.get_child_count()):
		if event.is_action_pressed("ability_one") and index == 0:
			(_cards.get_child(0) as Button).emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ability_two") and index == 1:
			(_cards.get_child(1) as Button).emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
