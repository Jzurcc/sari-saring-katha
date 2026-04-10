extends Node
## Adds scroll-wheel navigation to Dialogic choice buttons.
##
## When a Dialogic timeline is active and choices are visible, scrolling
## the mouse wheel cycles focus through them.
## Scroll UP = previous choice.  Scroll DOWN = next choice.
##
## Dialogic 2 registers every choice button under the "dialogic_choice_button"
## group (see addons/dialogic/Modules/Choice/node_choice_button.gd).

var _focused_idx: int = 0

func _input(event: InputEvent) -> void:
	if Dialogic.current_timeline == null:
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return

	var scroll_dir: int = 0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_dir = -1
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_dir = 1
	else:
		return

	# Collect all visible, enabled choice buttons the correct group name.
	var buttons: Array[Button] = []
	for node in get_tree().get_nodes_in_group("dialogic_choice_button"):
		if node is Button and node.visible and not node.disabled:
			buttons.append(node as Button)

	if buttons.is_empty():
		return

	_focused_idx = (_focused_idx + scroll_dir) % buttons.size()
	if _focused_idx < 0:
		_focused_idx += buttons.size()

	buttons[_focused_idx].grab_focus()
	get_viewport().set_input_as_handled()
