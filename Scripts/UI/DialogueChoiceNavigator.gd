extends Node
## DialogueChoiceNavigator — autoload-level node that adds scroll-wheel
## navigation to Dialogic choice buttons.
##
## When a Dialogic timeline is active and choices are on screen, scrolling
## the mouse wheel cycles focus through the visible choice buttons.
## Scroll UP = move to previous choice.  Scroll DOWN = move to next choice.
##
## Dialogic 2 marks every choice button with the "dialogic_choice" group,
## so we find them at runtime without hard-coding scene paths.

var _focused_idx: int = 0

func _input(event: InputEvent) -> void:
	# Only act when a timeline is running
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

	# Gather all currently visible+enabled choice buttons
	var buttons: Array[Button] = []
	for node in get_tree().get_nodes_in_group("dialogic_choice"):
		if node is Button and node.visible and not node.disabled:
			buttons.append(node as Button)

	if buttons.is_empty():
		return

	# Clamp/wrap focus index
	_focused_idx = (_focused_idx + scroll_dir) % buttons.size()
	if _focused_idx < 0:
		_focused_idx += buttons.size()

	buttons[_focused_idx].grab_focus()
	get_viewport().set_input_as_handled()
