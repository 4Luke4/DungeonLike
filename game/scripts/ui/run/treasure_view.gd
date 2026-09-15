extends Control
## What was found, and whether to take it.
##
## The comparison against what is already equipped is the whole point of the
## screen: an item's numbers mean nothing on their own, and a player should not
## have to remember their own armour class to make the decision.

signal resolved

var _controller: RunController

@onready var _heading: Label = %Heading
@onready var _found: Label = %Found
@onready var _current: Label = %Current
@onready var _take_button: Button = %TakeButton
@onready var _leave_button: Button = %LeaveButton


func bind(controller: RunController) -> void:
	_controller = controller
	_heading.text = tr("TREASURE_HEADING")
	_take_button.text = tr("TREASURE_TAKE")
	_leave_button.text = tr("TREASURE_LEAVE")
	_take_button.custom_minimum_size.y = Layout.target_height()
	_leave_button.custom_minimum_size.y = Layout.target_height()
	_take_button.pressed.connect(_on_take)
	_leave_button.pressed.connect(_on_leave)

	var item := controller.pending_item
	if item == null:
		_found.text = tr("TREASURE_NOTHING")
		_current.text = ""
		_take_button.visible = false
		_leave_button.text = tr("ENCOUNTER_CONTINUE")
		_leave_button.grab_focus()
		return

	_found.text = _describe(item)
	_current.text = _describe_equipped(item)
	_take_button.grab_focus()


## An item's name and what it does, in the player's language.
func _describe(item: Item) -> String:
	var lines: Array[String] = [ItemNaming.display_name(item, _controller.content)]
	for effect: Dictionary in PlayerBuilder.effects_of(item, _controller.content):
		lines.append("· %s" % _describe_effect(effect, item))
	return "\n".join(lines)


func _describe_equipped(item: Item) -> String:
	var base := _controller.content.by_id(item.base_id)
	var slot := String(base.get("slot", "trinket"))
	var equipped := _controller.state.equipped(slot)
	if equipped == null:
		return "%s: %s" % [tr("TREASURE_EQUIPPED"), tr("INVENTORY_EMPTY_SLOT")]
	return "%s\n%s" % [tr("TREASURE_EQUIPPED"), _describe(equipped)]


## Effects are described from their own fields rather than from a sentence in
## the data, so that the description is always in step with what the effect does
## and needs no separate translation per affix.
func _describe_effect(effect: Dictionary, item: Item) -> String:
	var description := ""
	match String(effect.get("kind", "")):
		"attack_bonus":
			description = "+%d %s" % [int(effect.get("amount", 0)), tr("ENCOUNTER_ATTACK")]
		"armour_class_bonus":
			description = (
				"+%d %s" % [int(effect.get("amount", 0)), tr("RULES_ARMOUR_CLASS_SHORT")]
			)
		"ability_bonus":
			description = (
				"+%d %s"
				% [
					int(effect.get("amount", 0)),
					tr(Abilities.name_key(String(effect.get("ability", "str")))),
				]
			)
		"bonus_damage":
			var damage: Dictionary = effect.get("damage", {})
			description = (
				"+%s %s"
				% [
					String(damage.get("dice", "")),
					tr(Damage.name_key(String(damage.get("type", "fire")))),
				]
			)
		"max_hit_points":
			description = ("+%d %s" % [_rolled_value(effect, item), tr("RULES_HIT_POINTS_SHORT")])
		"damage_resistance":
			description = (
				"%s: %s"
				% [
					tr("RULES_RESISTANCE"),
					tr(Damage.name_key(String(effect.get("damage_type", "fire")))),
				]
			)
		"on_hit_condition":
			description = tr(Conditions.name_key(String(effect.get("condition", "poisoned"))))
	return description


## The value this particular item rolled for a variable effect, so the card
## shows what the player is actually getting rather than the range it came from.
func _rolled_value(effect: Dictionary, item: Item) -> int:
	for key: String in item.rolled_values:
		return int(item.rolled_values[key])
	return Dice.minimum(String(effect.get("roll", "0d0")))


func _on_take() -> void:
	_controller.take_pending_item()
	resolved.emit()


func _on_leave() -> void:
	_controller.leave_pending_item()
	resolved.emit()
