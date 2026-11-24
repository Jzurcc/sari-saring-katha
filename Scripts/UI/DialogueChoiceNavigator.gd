extends Node
## Manages Dialogic choice navigation, confirmation controls, and dynamic
## console-style keybind prompts:
## - Scroll wheel cycles focus through visible choice buttons.
## - Pressing `dialogue_confirm_choice` (default: F) confirms the focused choice.
## - Pressing Space / `dialogic_default_action` / `ui_accept` on keyboard advances
##   normal dialogue, but is blocked from confirming choices when choices are visible.
## - Displays a dynamic keycap badge next to the currently selected choice (`[F]`)
##   and a bottom-right dialogue control legend (`[SPACE] Advance` / `[SCROLL] Choose · [F] Select`)
##   that automatically updates whenever the player rebinds controls in Settings.

const CONFIRM_ACTION := "dialogue_confirm_choice"
const ADVANCE_ACTION := "dialogic_default_action"
const SETTINGS_PATH := "user://settings.cfg"

var _focused_idx: int = 0

# Console-style prompt UI nodes
var _prompt_layer: CanvasLayer
var _legend_panel: PanelContainer
var _legend_hbox: HBoxContainer
var _choice_badge: PanelContainer
var _choice_badge_key_lbl: Label
var _last_legend_mode: String = "" # "", "advance", "choice"
var _last_advance_key: String = ""
var _last_confirm_key: String = ""
var _badge_pos_initialized: bool = false

func _ready() -> void:
	ensure_confirm_action_initialized()
	_build_prompt_ui()
	EventBus.keybinds_changed.connect(_on_keybinds_changed)

## Ensures `dialogue_confirm_choice` exists in InputMap (default: F) and applies
## any saved user binding from user://settings.cfg on startup.
func ensure_confirm_action_initialized() -> void:
	if not InputMap.has_action(CONFIRM_ACTION):
		InputMap.add_action(CONFIRM_ACTION)
		var default_ev := InputEventKey.new()
		default_ev.physical_keycode = KEY_F
		InputMap.action_add_event(CONFIRM_ACTION, default_ev)

	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section("controls"):
		for action in [CONFIRM_ACTION, ADVANCE_ACTION]:
			if cfg.has_section_key("controls", action):
				var data = cfg.get_value("controls", action)
				var ev := _deserialize_input_event(data)
				if ev and InputMap.has_action(action):
					InputMap.action_erase_events(action)
					InputMap.action_add_event(action, ev)

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

# ── Dynamic Keybind Formatting ───────────────────────────────────────────────

func _get_action_key_label(action_name: String, fallback: String) -> String:
	if not InputMap.has_action(action_name):
		return fallback
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return fallback

	# Prefer a keyboard event for cleaner keycap display (especially for dialogic_default_action)
	var chosen: InputEvent = events[0]
	for ev in events:
		if ev is InputEventKey:
			chosen = ev
			break

	if chosen is InputEventMouseButton:
		match (chosen as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "SCROLL ↑"
			MOUSE_BUTTON_WHEEL_DOWN: return "SCROLL ↓"

	var raw := chosen.as_text()
	for suffix in [" (Physical)", " (physical)", " - Physical", " - physical", " (Physical Key)"]:
		raw = raw.replace(suffix, "")
	raw = raw.strip_edges()
	if raw == "":
		return fallback
	return raw.to_upper()

func _on_keybinds_changed() -> void:
	_last_advance_key = ""
	_last_confirm_key = ""
	_last_legend_mode = ""

# ── Prompt UI Construction ───────────────────────────────────────────────────

func _build_prompt_ui() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = 105
	add_child(_prompt_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_layer.add_child(root)

	# 1. Bottom-right console control legend
	_legend_panel = PanelContainer.new()
	_legend_panel.anchor_left = 1.0
	_legend_panel.anchor_right = 1.0
	_legend_panel.anchor_top = 1.0
	_legend_panel.anchor_bottom = 1.0
	_legend_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_legend_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_legend_panel.offset_right = -26.0
	_legend_panel.offset_bottom = -20.0
	_legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var legend_style := UIStyle.create_flat_stylebox(Color(0.08, 0.075, 0.07, 0.88), 10, 14, 8)
	legend_style.border_color = Color(0.88, 0.72, 0.42, 0.55)
	legend_style.border_width_left = 1
	legend_style.border_width_top = 1
	legend_style.border_width_right = 1
	legend_style.border_width_bottom = 1
	_legend_panel.add_theme_stylebox_override("panel", legend_style)
	_legend_panel.visible = false
	root.add_child(_legend_panel)

	_legend_hbox = HBoxContainer.new()
	_legend_hbox.add_theme_constant_override("separation", 14)
	_legend_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_panel.add_child(_legend_hbox)

	# 2. Floating keycap badge snapped beside the currently selected choice button
	_choice_badge = PanelContainer.new()
	_choice_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := UIStyle.create_flat_stylebox(Color(0.10, 0.09, 0.08, 0.94), 7, 9, 4)
	badge_style.border_color = Color(1.0, 0.90, 0.54, 0.92)
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	badge_style.shadow_size = 6
	_choice_badge.add_theme_stylebox_override("panel", badge_style)
	_choice_badge.visible = false
	root.add_child(_choice_badge)

	_choice_badge_key_lbl = Label.new()
	_choice_badge_key_lbl.text = "F"
	_choice_badge_key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_badge_key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_choice_badge_key_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_choice_badge_key_lbl.add_theme_font_size_override("font_size", 15)
	_choice_badge_key_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56, 1.0))
	_choice_badge_key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_badge.add_child(_choice_badge_key_lbl)

func _make_keycap_chip(key_text: String, action_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_style := UIStyle.create_flat_stylebox(Color(0.16, 0.145, 0.125, 0.96), 6, 8, 2)
	cap_style.border_color = Color(1.0, 0.90, 0.56, 0.85)
	cap_style.border_width_left = 1
	cap_style.border_width_top = 1
	cap_style.border_width_right = 1
	cap_style.border_width_bottom = 2
	cap.add_theme_stylebox_override("panel", cap_style)
	row.add_child(cap)

	var k_lbl := Label.new()
	k_lbl.text = key_text
	k_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	k_lbl.add_theme_font_size_override("font_size", 13)
	k_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56, 1.0))
	k_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(k_lbl)

	var a_lbl := Label.new()
	a_lbl.text = action_text
	a_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	a_lbl.add_theme_font_size_override("font_size", 14)
	a_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT)
	a_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(a_lbl)

	return row

func _rebuild_legend(mode: String, adv_key: String, conf_key: String) -> void:
	for child in _legend_hbox.get_children():
		child.queue_free()
	if mode == "choice":
		_legend_hbox.add_child(_make_keycap_chip("SCROLL", "Choose"))
		_legend_hbox.add_child(_make_keycap_chip(conf_key, "Select Choice"))
	elif mode == "advance":
		_legend_hbox.add_child(_make_keycap_chip(adv_key, "Advance"))

func _is_dialogue_ui_visible() -> bool:
	if get_tree().paused or Dialogic.current_timeline == null or Dialogic.paused:
		return false
	var layout = Dialogic.Styles.get_layout_node()
	if is_instance_valid(layout) and not layout.visible:
		return false
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(_legend_panel) or not is_instance_valid(_choice_badge):
		return

	if not _is_dialogue_ui_visible():
		_legend_panel.visible = false
		_choice_badge.visible = false
		_badge_pos_initialized = false
		return

	var buttons := _get_visible_choice_buttons()
	var adv_key := _get_action_key_label(ADVANCE_ACTION, "SPACE")
	var conf_key := _get_action_key_label(CONFIRM_ACTION, "F")
	var mode := "choice" if not buttons.is_empty() else "advance"

	if mode != _last_legend_mode or adv_key != _last_advance_key or conf_key != _last_confirm_key:
		_last_legend_mode = mode
		_last_advance_key = adv_key
		_last_confirm_key = conf_key
		_rebuild_legend(mode, adv_key, conf_key)
		_choice_badge_key_lbl.text = conf_key

	_legend_panel.visible = true

	if not buttons.is_empty():
		var target_btn := _get_target_choice_button(buttons)
		if is_instance_valid(target_btn):
			var btn_rect := target_btn.get_global_rect()
			if btn_rect.size.x > 1.0 and btn_rect.size.y > 1.0:
				_choice_badge.visible = true
				var badge_sz := _choice_badge.get_combined_minimum_size()
				var desired_pos := Vector2(
					maxf(8.0, btn_rect.position.x - badge_sz.x - 10.0),
					btn_rect.position.y + (btn_rect.size.y - badge_sz.y) * 0.5
				)
				if not _badge_pos_initialized:
					_choice_badge.position = desired_pos
					_badge_pos_initialized = true
				else:
					_choice_badge.position = _choice_badge.position.lerp(desired_pos, clampf(delta * 20.0, 0.0, 1.0))
			else:
				_choice_badge.visible = false
		else:
			_choice_badge.visible = false
	else:
		_choice_badge.visible = false
		_badge_pos_initialized = false

# ── Choice Input Handling ────────────────────────────────────────────────────

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
