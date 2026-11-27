class_name ShortcutDockHUD
extends CanvasLayer

## Bottom-left horizontal HUD shortcut dock displaying double-ringed circular Lucide
## medallions paired with square keycap badges matching the Calendar [C] keycap style:
##   - Folklore Journal (default [J], action: toggle_journal) + circular unread gold dot
##   - Price Ledger     (default [L], action: toggle_ledger)
##   - Store Upgrades   (default [U], action: toggle_upgrades)
## Automatically reflects any custom keybind changes made in Settings.

const IC_JOURNAL: Texture2D = preload("res://Assets/ui/icons/book-bookmark.png")
const IC_LEDGER: Texture2D = preload("res://Assets/ui/icons/package-pen.png")
const IC_UPGRADES: Texture2D = preload("res://Assets/ui/icons/book-plus.png")

const SHORTCUTS: Array[Dictionary] = [
	{"id": "journal", "action": "toggle_journal", "default_key": KEY_J, "icon": IC_JOURNAL},
	{"id": "ledger", "action": "toggle_ledger", "default_key": KEY_L, "icon": IC_LEDGER},
	{"id": "upgrades", "action": "toggle_upgrades", "default_key": KEY_U, "icon": IC_UPGRADES},
]


class CircleMedallion extends Control:
	var fill_col: Color = Color(0.06, 0.052, 0.046, 0.92)
	var outer_ring_col: Color = Color(0.86, 0.66, 0.30, 0.78)
	var inner_ring_col: Color = Color(0.96, 0.80, 0.42, 0.92)

	func _draw() -> void:
		var c := size * 0.5
		var r_outer := minf(size.x, size.y) * 0.5 - 1.5
		var r_inner := r_outer - 4.5
		draw_circle(c, r_outer, fill_col)
		# Thin outer ring + thick inner ring (matching Hades diamond event emblems)
		draw_arc(c, r_outer, 0.0, TAU, 56, outer_ring_col, 1.6, true)
		draw_arc(c, r_inner, 0.0, TAU, 56, inner_ring_col, 3.2, true)


var _root: Control
var _dock: HBoxContainer
var _key_labels: Dictionary = {} # action -> Label
var _medallions: Dictionary = {} # action -> Control
var _keycaps: Dictionary = {} # action -> Control
var _medallion_tweens: Dictionary = {} # action -> Tween
var _dot_tweens: Dictionary = {} # Panel -> Tween
var _journal_dot: Panel
var _upgrades_dot: Panel
var _sync_timer: float = 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_actions()
	_build_ui()
	_refresh_keycaps()


func _unhandled_input(event: InputEvent) -> void:
	for s in SHORTCUTS:
		var act := str(s["action"])
		if event.is_action_pressed(act):
			_pop_medallion(act)
			break


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

	# Bottom-left horizontal dock
	_dock = HBoxContainer.new()
	_dock.anchor_left = 0.0
	_dock.anchor_right = 0.0
	_dock.anchor_top = 1.0
	_dock.anchor_bottom = 1.0
	_dock.offset_left = 26.0
	_dock.offset_right = 290.0
	_dock.offset_top = -92.0
	_dock.offset_bottom = -22.0
	_dock.add_theme_constant_override("separation", 18)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dock)

	for s in SHORTCUTS:
		# Double-ring circular medallion encasing the Lucide icon
		var circle := CircleMedallion.new()
		circle.custom_minimum_size = Vector2(66, 66)
		circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dock.add_child(circle)

		var icon_center := CenterContainer.new()
		icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.add_child(icon_center)

		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(30, 30)
		ic.texture = s["icon"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = Color(1.0, 0.94, 0.80, 0.96)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.add_child(ic)

		if str(s["id"]) == "journal":
			_journal_dot = _make_red_dot()
			circle.add_child(_journal_dot)
		elif str(s["id"]) == "upgrades":
			_upgrades_dot = _make_red_dot()
			circle.add_child(_upgrades_dot)

		# Square keycap badge tucked into the bottom-right rim of the circle
		var key_panel := PanelContainer.new()
		key_panel.custom_minimum_size = Vector2(28, 28)
		key_panel.anchor_left = 1.0
		key_panel.anchor_right = 1.0
		key_panel.anchor_top = 1.0
		key_panel.anchor_bottom = 1.0
		key_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		key_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		key_panel.offset_left = -23.0
		key_panel.offset_right = 5.0
		key_panel.offset_top = -25.0
		key_panel.offset_bottom = 3.0
		key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ks := UIStyle.create_flat_stylebox(Color(0.06, 0.052, 0.046, 0.94), 6, 7, 3)
		ks.border_color = Color(0.86, 0.66, 0.30, 0.88)
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
		circle.add_child(key_panel)

		var act_key := str(s["action"])
		_key_labels[act_key] = key_lbl
		_medallions[act_key] = circle
		_keycaps[act_key] = key_panel


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


func _make_red_dot() -> Panel:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size = Vector2(16, 16)
	dot.position = Vector2(49, 1)
	dot.visible = false
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_st := StyleBoxFlat.new()
	dot_st.bg_color = Color(0.94, 0.28, 0.24, 1.0)
	dot_st.border_color = Color(0.08, 0.06, 0.04, 0.96)
	dot_st.set_border_width_all(1)
	dot_st.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", dot_st)
	return dot


func _has_any_buyable_upgrade() -> bool:
	var gm := get_tree().get_first_node_in_group("game_manager")
	var avail_money: float = float(gm.money) if (gm != null and "money" in gm) else 0.0
	for n in UpgradeTreeRegistry.get_all_nodes():
		var ev := UpgradeTreeRegistry.evaluate_node(str(n["id"]), avail_money)
		if bool(ev.get("can_buy", false)):
			return true
	return false


func _pop_medallion(action: String) -> void:
	var circle: Control = _medallions.get(action)
	if not is_instance_valid(circle):
		return
	var prev: Tween = _medallion_tweens.get(action)
	if prev and prev.is_valid():
		prev.kill()
	circle.pivot_offset = circle.size * 0.5
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	# Crisp area-preserving press squash -> overshoot -> rest
	tw.tween_property(circle, "scale", Vector2(0.88, 1.12), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(circle, "scale", Vector2(1.06, 0.95), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(circle, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var keycap: Control = _keycaps.get(action)
	if is_instance_valid(keycap):
		keycap.pivot_offset = keycap.size * 0.5
		tw.parallel().tween_property(keycap, "scale", Vector2(0.86, 0.86), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(keycap, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_medallion_tweens[action] = tw


func _set_dot_visible(dot: Panel, should_show: bool) -> void:
	if not is_instance_valid(dot):
		return
	if dot.visible == should_show:
		return
	var prev: Tween = _dot_tweens.get(dot)
	if prev and prev.is_valid():
		prev.kill()
	dot.visible = should_show
	dot.pivot_offset = dot.size * 0.5
	if should_show:
		dot.scale = Vector2.ZERO
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(dot, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			if not is_instance_valid(dot) or not dot.visible:
				return
			var pulse := create_tween().set_loops()
			pulse.set_ignore_time_scale(true)
			pulse.tween_property(dot, "scale", Vector2(1.14, 1.14), 0.90).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			pulse.tween_property(dot, "scale", Vector2.ONE, 0.90).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_dot_tweens[dot] = pulse
		)
		_dot_tweens[dot] = tw
	else:
		dot.scale = Vector2.ONE
		_dot_tweens.erase(dot)


func _refresh_visibility_and_badges() -> void:
	if is_instance_valid(_journal_dot) and is_instance_valid(CharacterProgressionManager):
		_set_dot_visible(_journal_dot, CharacterProgressionManager.has_any_unread_journal())
	if is_instance_valid(_upgrades_dot):
		_set_dot_visible(_upgrades_dot, _has_any_buyable_upgrade())
