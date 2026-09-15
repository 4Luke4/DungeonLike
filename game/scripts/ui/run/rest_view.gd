extends Control
## A room with nothing in it, and the choice of whether to use it.
##
## Pressing on without resting is a real option rather than a courtesy: the
## recovery is capped at a quarter of the maximum, so a player near full health
## gains almost nothing and may prefer to keep moving.

signal resolved

var _controller: RunController

@onready var _heading: Label = %Heading
@onready var _result: Label = %Result
@onready var _rest_button: Button = %RestButton
@onready var _press_on_button: Button = %PressOnButton


func bind(controller: RunController) -> void:
	_controller = controller
	_heading.text = tr("REST_HEADING")
	_result.text = ""
	_rest_button.text = tr("REST_RECOVER")
	_press_on_button.text = tr("REST_PRESS_ON")
	_rest_button.custom_minimum_size.y = Layout.target_height()
	_press_on_button.custom_minimum_size.y = Layout.target_height()
	_rest_button.pressed.connect(_on_rest)
	_press_on_button.pressed.connect(func() -> void: resolved.emit())
	_rest_button.grab_focus()


func _on_rest() -> void:
	var restored := _controller.rest()
	_result.text = tr("REST_RECOVER_RESULT") % restored
	# The result is shown before the screen changes, so the player sees what
	# their decision bought them.
	_rest_button.disabled = true
	_press_on_button.text = tr("ENCOUNTER_CONTINUE")
	_press_on_button.grab_focus()
