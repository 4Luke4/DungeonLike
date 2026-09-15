class_name Layout
extends RefCounted
## Where the phone layout ends and the tablet layout begins.
##
## The breakpoint was already a constant in the main menu, and this milestone
## adds six more screens that need the same number. Restating it in each of them
## would be exactly the duplication the repository standard forbids: one of the
## seven would eventually be changed alone, and that screen would lay out
## differently from the rest on the same device.

## Width, in layout pixels, at or above which the wider layout is used. Chosen
## to sit between a phone in landscape and a small tablet.
const TABLET_BREAKPOINT := 900.0

## Minimum height of a control the player has to hit, by input mode. A finger
## needs a larger target than a cursor does.
const TOUCH_TARGET_HEIGHT := 56
const POINTER_TARGET_HEIGHT := 40


## Whether [param control] is currently in a window wide enough for the tablet
## layout.
static func is_wide(control: Control) -> bool:
	return control.get_viewport_rect().size.x >= TABLET_BREAKPOINT


## The height a hittable control should have for the current input mode.
static func target_height() -> int:
	return (
		TOUCH_TARGET_HEIGHT
		if InputModeService.should_use_touch_targets()
		else POINTER_TARGET_HEIGHT
	)


## Appends a key hint to [param label], but only when a keyboard is in use.
##
## Hints are noise on a touch device and are the difference between usable and
## unusable on a keyboard, which is why they are decided per mode rather than
## per build.
static func with_key_hint(label: String, hint: String) -> String:
	return "%s [%s]" % [label, hint] if InputModeService.should_show_key_hints() else label
