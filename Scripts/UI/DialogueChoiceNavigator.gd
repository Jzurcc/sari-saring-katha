extends Node
## Manages Dialogic choice navigation and confirmation controls:
## - Scroll wheel cycles focus through visible choice buttons.
## - Pressing the configurable `dialogue_confirm_choice` action (default: F)
##   confirms the currently focused choice.
## - Pressing Space / `dialogic_default_action` / `ui_accept` on keyboard
##   advances normal dialogue, but is blocked from accidentally confirming
##   choices when choice buttons are visible (unless explicitly bound to
##   `dialogue_confirm_choice` in Settings).
##
## Dialogic 2 registers every choice button under the "dialogic_choice_button"
## group (see addons/dialogic/Modules/Choice/node_choice_button.gd).

const CONFIRM_ACTION := "dialogue_confirm_choice"
const SETTINGS_PATH := "user://settings.cfg"

var _focused_idx: int = 0

func _ready() -> void:
	ensure_confirm_action_initialized()

## Ensures `dialogue_confirm_choice` exists in InputMap (default: F) and applies
## any saved user binding from user://settings.cfg on startup.
func ensure_confirm_action_initialized() -> void:
	if not InputMap.has_action(CONFIRM_ACTION):
		InputMap.add_action(CONFIRM_ACTION)
		var default_ev := InputEventKey.new()
		default_ev.physical_keycode = KEY_F
		InputMap.action_add_event(CONFIRM_ACTION, default_ev)

	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key("controls", CONFIRM_ACTION):
		var data = cfg.get_value("controls", CONFIRM_ACTION)
		var ev := _deserialize_input_event(data)
		if ev:
			InputMap.action_erase_events(CONFIRM_ACTION)
			InputMap.action_add_event(CONFIRM_ACTION, ev)

func _deserialize_input_event(data: Variant) -> InputEvent:
	if not (data is Dictionary):
		return null
	if data.get("type") == "key":
		var ev := InputEventKey.new()
		ev.keycode = int(data.get("keycode", 0))
		ev.physical_keycode = int(data.get("physical", 0))
		return ev
	elif data.get("type") == "mouse":
		var ev := InputEventMouseButton.new()
		ev.button_index = int(data.get("button_index", 0))
		return ev
	return null

func _get_visible_choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for node in get_tree().get_nodes_in_group("dialogic_choice_button"):
		if node is Button and node.visible and not node.disabled:
			buttons.append(node as Button)
	return buttons

func _input(event: InputEvent) -> void:
	if get_tree().paused or Dialogic.current_timeline == null or Dialogic.paused:
		return

	var buttons := _get_visible_choice_buttons()
	if buttons.is_empty():
		return

	# 1. Scroll wheel navigation through visible choice buttons
	if event is InputEventMouseButton and event.pressed:
		var scroll_dir: int = 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_dir = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_dir = 1
		if scroll_dir != 0:
			_sync_focused_idx(buttons)
			_focused_idx = (_focused_idx + scroll_dir) % buttons.size()
			if _focused_idx < 0:
				_focused_idx += buttons.size()
			buttons[_focused_idx].grab_focus()
			get_viewport().set_input_as_handled()
			return

	# 2. Confirm focused choice via `dialogue_confirm_choice` (default: F)
	#    If the user rebound confirm to Left Click, let normal Button click handle it.
	var is_left_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if InputMap.has_action(CONFIRM_ACTION) and not is_left_click:
		if event.is_action_pressed(CONFIRM_ACTION) and not event.is_echo():
			var target_btn := _get_target_choice_button(buttons)
			if target_btn:
				target_btn.button_up.emit()
				if target_btn.has_method("_pressed"):
					target_btn._pressed()
				else:
					target_btn.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_released(CONFIRM_ACTION):
			get_viewport().set_input_as_handled()
			return

	# 3. Block Space / Advance Dialogue / ui_accept on keyboard from confirming choices
	#    (unless the player explicitly rebound `dialogue_confirm_choice` to that same key,
	#    which was already handled in step 2 above).
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		var is_advance_or_accept: bool = event.is_action("ui_accept") \
			or event.is_action("dialogic_default_action") \
			or key_ev.keycode == KEY_SPACE \
			or key_ev.physical_keycode == KEY_SPACE
		if is_advance_or_accept:
			get_viewport().set_input_as_handled()
			return

func _sync_focused_idx(buttons: Array[Button]) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button:
		var idx := buttons.find(focused as Button)
		if idx >= 0:
			_focused_idx = idx

func _get_target_choice_button(buttons: Array[Button]) -> Button:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and buttons.has(focused as Button):
		return focused as Button
	return buttons[clampi(_focused_idx, 0, buttons.size() - 1)]
