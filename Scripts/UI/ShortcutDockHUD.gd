class_name ShortcutDockHUD
extends CanvasLayer

## Vertical mid-left HUD shortcut dock displaying Lucide icons paired with square keycap
## badges matching the Calendar [C] keycap style:
##   - Folklore Journal (default [J], action: toggle_journal) + unread gold indicator
##   - Price Ledger     (default [L], action: toggle_ledger)
##   - Store Upgrades   (default [U], action: toggle_upgrades)
## Automatically reflects any custom keybind changes made in Settings.

const IC_JOURNAL: Texture2D = preload("res://Assets/ui/icons/award.png")
const IC_LEDGER: Texture2D = preload("res://Assets/ui/icons/banknote.png")
const IC_UPGRADES: Texture2D = preload("res://Assets/ui/icons/trending-up.png")

const SHORTCUTS: Array[Dictionary] = [
	{"id": "journal", "action": "toggle_journal", "default_key": KEY_J, "icon": IC_JOURNAL},
	{"id": "ledger", "action": "toggle_ledger", "default_key": KEY_L, "icon": IC_LEDGER},
	{"id": "upgrades", "action": "toggle_upgrades", "default_key": KEY_U, "icon": IC_UPGRADES},
]

var _root: Control
var _dock: VBoxContainer
var _key_labels: Dictionary = {} # action -> Label
var _journal_dot: ColorRect
var _sync_timer: float = 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_build_ui()
	_refresh_keycaps()


func _process(delta: float) -> void:
	_sync_timer += delta
	if _sync_timer >= 0.25:
		_sync_timer = 0.0
		_refresh_keycaps()
		_refresh_visibility_and_badges()


func _ensure_input_actions() -> void:
	for s in SHORTCUTS:
		var act := str(s["action"])
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		if InputMap.action_get_events(act).is_empty():
			var ev := InputEventKey.new()
			ev.physical_keycode = int(s["default_key"])
			InputMap.action_add_event(act, ev)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dock = VBoxContainer.new()
	_dock.anchor_left = 0.0
	_dock.anchor_right = 0.0
	_dock.anchor_top = 0.5
	_dock.anchor_bottom = 0.5
	_dock.offset_left = 20.0
	_dock.offset_right = 76.0
	_dock.offset_top = -112.0
	_dock.offset_bottom = 112.0
	_dock.alignment = BoxContainer.ALIGNMENT_CENTER
	_dock.add_theme_constant_override("separation", 16)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dock)

	for s in SHORTCUTS:
		var item_v := VBoxContainer.new()
		item_v.alignment = BoxContainer.ALIGNMENT_CENTER
		item_v.add_theme_constant_override("separation", 4)
		item_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dock.add_child(item_v)

		# Lucide icon (slightly larger than the square keycap below it)
		var icon_holder := Control.new()
		icon_holder.custom_minimum_size = Vector2(36, 36)
		icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_v.add_child(icon_holder)

		var ic := TextureRect.new()
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.texture = s["icon"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = Color(1.0, 0.94, 0.80, 0.94)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(ic)

		if str(s["id"]) == "journal":
			_journal_dot = ColorRect.new()
			_journal_dot.color = Color(1.0, 0.84, 0.34, 1.0)
			_journal_dot.custom_minimum_size = Vector2(8, 8)
			_journal_dot.size = Vector2(8, 8)
			_journal_dot.position = Vector2(28, 0)
			_journal_dot.visible = false
			_journal_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_holder.add_child(_journal_dot)

		# Square keycap pill (exact same size & style as Calendar [C] keycap in MayariCardHUD)
		var key_panel := PanelContainer.new()
		key_panel.custom_minimum_size = Vector2(30, 30)
		key_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ks := UIStyle.create_flat_stylebox(Color(0.06, 0.052, 0.046, 0.86), 6, 8, 4)
		ks.border_color = Color(0.86, 0.66, 0.30, 0.78)
		ks.set_border_width_all(1)
		key_panel.add_theme_stylebox_override("panel", ks)

		var key_lbl := Label.new()
		key_lbl.text = OS.get_keycode_string(int(s["default_key"]))
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		key_lbl.add_theme_font_size_override("font_size", 16)
		key_lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78, 1.0))
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_panel.add_child(key_lbl)
		item_v.add_child(key_panel)

		_key_labels[str(s["action"])] = key_lbl


func _refresh_keycaps() -> void:
	for s in SHORTCUTS:
		var act := str(s["action"])
		var lbl: Label = _key_labels.get(act)
		if not is_instance_valid(lbl):
			continue
		var txt := _get_action_key_label(act, int(s["default_key"]))
		if lbl.text != txt:
			lbl.text = txt


func _get_action_key_label(action: String, fallback_key: int) -> String:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var kc: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
				if kc != KEY_NONE:
					return _short_key_name(OS.get_keycode_string(kc))
	return _short_key_name(OS.get_keycode_string(fallback_key))


func _short_key_name(raw: String) -> String:
	var s := raw.strip_edges().to_upper()
	match s:
		"CONTROL": return "CTRL"
		"ESCAPE": return "ESC"
		"BACKSPACE": return "BKSP"
		"SPACE": return "SPC"
		"RETURN", "ENTER": return "ENT"
		_: return s


func _refresh_visibility_and_badges() -> void:
	if is_instance_valid(_journal_dot) and is_instance_valid(CharacterProgressionManager):
		_journal_dot.visible = CharacterProgressionManager.has_any_unread_journal()

	var hide_dock := false
	if is_instance_valid(Dialogic) and Dialogic.current_timeline != null:
		hide_dock = true
	elif not get_tree().get_nodes_in_group("storefront_canvas_active").is_empty():
		hide_dock = true
	elif not get_tree().get_nodes_in_group("day_summary_overlay_active").is_empty():
		hide_dock = true
	else:
		for grp in ["folklore_journal_overlay", "upgrade_tree_overlay", "events_overlay", "price_ledger_overlay"]:
			for ov in get_tree().get_nodes_in_group(grp):
				if ov.get("is_open"):
					hide_dock = true
					break
			if hide_dock:
				break
	_dock.visible = not hide_dock
