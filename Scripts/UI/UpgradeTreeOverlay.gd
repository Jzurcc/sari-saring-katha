class_name UpgradeTreeOverlay
extends CanvasLayer

## Modern Cyberpunk / God of War-inspired Store Evolution & Skill Tree ([U]).
## Renders a bottom-up interactive pan/zoom node graph with angled circuit/runic
## connector lines, branch accents, right-side inspector drawer, and queues
## purchased upgrades for Uncle Mario delivery upon closing.

const Registry := preload("res://Scripts/Progression/UpgradeTreeRegistry.gd")

const COL_BG := Color(0.032, 0.036, 0.052, 0.96)
const COL_PANEL := Color(0.062, 0.070, 0.098, 0.96)
const COL_NODE_BG := Color(0.085, 0.096, 0.132, 0.97)
const COL_NODE_LOCKED := Color(0.055, 0.060, 0.082, 0.88)
const COL_TEXT := Color(0.95, 0.94, 0.90, 1.0)
const COL_MUTED := Color(0.62, 0.65, 0.72, 0.92)
const COL_GRID := Color(0.16, 0.20, 0.28, 0.22)

# Logical tree spacing (bottom-up: y=0 at bottom, y=9.4 at top)
const X_STEP := 196.0
const Y_STEP := 112.0
const NODE_SIZE := Vector2(166, 76)
const CAPSTONE_SIZE := Vector2(220, 88)

var is_open: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _selected_id: String = "tier_2"

var _pending_levels: Dictionary = {}       # node_id -> int
var _pending_delivery_items: Dictionary = {} # ItemData -> 1

# Pan & zoom state for the graph canvas
var _pan: Vector2 = Vector2.ZERO
var _zoom: float = 0.88
var _dragging: bool = false
var _drag_moved: bool = false

var _bold_font: FontVariation
var _root: Control
var _top_stats_lbl: Label
var _money_lbl: Label
var _pending_lbl: Label
var _canvas_clip: Control
var _graph_drawer: Control
var _node_layer: Control
var _node_buttons: Dictionary = {} # node_id -> Button

# Inspector widgets
var _insp_branch_lbl: Label
var _insp_icon: TextureRect
var _insp_title_lbl: Label
var _insp_level_lbl: Label
var _insp_desc_lbl: Label
var _insp_prereqs_box: VBoxContainer
var _insp_unlocks_box: VBoxContainer
var _insp_mario_lbl: Label
var _insp_buy_btn: Button
var _insp_paint_btn: Button


func _ready() -> void:
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_tree_overlay")

	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.58

	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if is_open:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_U:
				get_viewport().set_input_as_handled()
				close_tree()
			elif event.keycode == KEY_F:
				get_viewport().set_input_as_handled()
				_reset_view()
			return
		if event.keycode == KEY_U:
			if Dialogic.current_timeline != null:
				return
			if not get_tree().get_nodes_in_group("storefront_canvas_active").is_empty():
				return
			if not get_tree().get_nodes_in_group("minigame_overlay_active").is_empty():
				return
			for j_ov in get_tree().get_nodes_in_group("folklore_journal_overlay"):
				if j_ov.get("is_open"):
					return
			get_viewport().set_input_as_handled()
			open_tree()


func open_tree(focus_node_id: String = "") -> void:
	if is_open:
		return
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	visible = true
	_pending_levels.clear()
	_pending_delivery_items.clear()

	if focus_node_id != "" and not Registry.get_node_def(focus_node_id).is_empty():
		_selected_id = focus_node_id
	else:
		_selected_id = _pick_default_focus()

	EventBus.request_sfx.emit("tab_switch")
	_refresh_all()
	call_deferred("_reset_view")


func close_tree() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Input.mouse_mode = _prev_mouse_mode
	EventBus.request_sfx.emit("drop")

	if not _pending_delivery_items.is_empty():
		var items_copy := _pending_delivery_items.duplicate()
		_pending_delivery_items.clear()
		_pending_levels.clear()
		if is_instance_valid(MarioManager) and not MarioManager.is_restocking_active:
			MarioManager.start_delivery(items_copy)
	else:
		_pending_levels.clear()


func _pick_default_focus() -> String:
	var money := _get_money()
	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var ev := Registry.evaluate_node(nid, money, _pending_levels)
		if str(ev["state"]) == "available":
			return nid
	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var ev := Registry.evaluate_node(nid, money, _pending_levels)
		if str(ev["state"]) == "available_poor":
			return nid
	return "tier_2"


func _get_money() -> float:
	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	return float(gm_nodes[0].money) if not gm_nodes.is_empty() else 0.0


func _reset_view() -> void:
	if not is_instance_valid(_canvas_clip):
		return
	var csz := _canvas_clip.size
	if csz.x <= 10.0 or csz.y <= 10.0:
		return
	_zoom = 0.88
	# Focus around the selected node, biased slightly toward bottom-mid so roots show clearly
	var focus_def := Registry.get_node_def(_selected_id)
	var focus_pos: Vector2 = focus_def.get("pos", Vector2(0.0, 2.0))
	var world_pt := _logical_to_world(focus_pos)
	_pan = csz * 0.5 - world_pt * _zoom
	_layout_nodes()


func _logical_to_world(lpos: Vector2) -> Vector2:
	# y=0 is at the bottom, y=9.4 is at the top (so negate y)
	return Vector2(lpos.x * X_STEP, -lpos.y * Y_STEP)


func _world_to_canvas(wpos: Vector2) -> Vector2:
	return wpos * _zoom + _pan


func _refresh_all() -> void:
	var money := _get_money()
	if is_instance_valid(_top_stats_lbl) and is_instance_valid(StoryManager):
		var xp_need := StoryManager.get_xp_for_next_level()
		var xp_str := ("%d/%d XP" % [StoryManager.player_xp, xp_need]) if xp_need > 0 else "MAX XP"
		_top_stats_lbl.text = "Player Lv. %d (%s)   •   Store Tier %d" % [
			StoryManager.player_level, xp_str, StoryManager.current_tier
		]
	if is_instance_valid(_money_lbl):
		_money_lbl.text = "₱%.2f" % money
	if is_instance_valid(_pending_lbl):
		var cnt := _pending_delivery_items.size()
		_pending_lbl.visible = cnt > 0
		_pending_lbl.text = "Mario Delivery Queued: %d" % cnt

	_layout_nodes()
	_refresh_inspector()


func _layout_nodes() -> void:
	if not is_instance_valid(_node_layer):
		return
	var money := _get_money()
	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var btn: Button = _node_buttons.get(nid)
		if not is_instance_valid(btn):
			continue
		var base_sz := CAPSTONE_SIZE if nid == "open_door" else NODE_SIZE
		var scaled_sz := base_sz * _zoom
		var center := _world_to_canvas(_logical_to_world(n["pos"]))
		btn.position = center - scaled_sz * 0.5
		btn.size = scaled_sz
		btn.scale = Vector2.ONE

		var ev := Registry.evaluate_node(nid, money, _pending_levels)
		_style_node_button(btn, n, ev, nid == _selected_id)

	if is_instance_valid(_graph_drawer):
		_graph_drawer.queue_redraw()


func _style_node_button(btn: Button, def: Dictionary, ev: Dictionary, selected: bool) -> void:
	var state := str(ev["state"])
	var accent := Registry.get_branch_color(str(def["branch"]))
	var cur_lvl := int(ev["cur_level"])
	var max_lvl := int(ev["max_level"])
	var cost := float(ev["cost"])
	var item: ItemData = ev.get("item")

	var bg := COL_NODE_BG
	var border_col := Color(0.24, 0.27, 0.36, 0.85)
	var border_w := 2
	var title_col := COL_TEXT
	var sub_col := COL_MUTED

	match state:
		"maxed":
			bg = Color(0.08, 0.13, 0.12, 0.98)
			border_col = accent
			border_w = 2
			sub_col = accent
		"available":
			bg = Color(0.10, 0.12, 0.18, 0.98)
			border_col = accent.lightened(0.22)
			border_w = 3
			sub_col = Color(0.54, 0.96, 0.68, 1.0)
		"available_poor":
			bg = Color(0.09, 0.10, 0.14, 0.96)
			border_col = Color(accent.r, accent.g, accent.b, 0.60)
			sub_col = Color(0.96, 0.52, 0.44, 0.95)
		"locked_level":
			bg = COL_NODE_LOCKED
			border_col = Color(0.45, 0.34, 0.24, 0.72)
			title_col = Color(0.74, 0.72, 0.70, 0.92)
		_:
			bg = COL_NODE_LOCKED
			border_col = Color(0.20, 0.22, 0.29, 0.65)
			title_col = Color(0.55, 0.58, 0.65, 0.78)
			sub_col = Color(0.42, 0.45, 0.52, 0.75)

	if selected:
		border_col = Color.WHITE
		border_w = 3

	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border_col
	st.set_border_width_all(border_w)
	st.corner_radius_top_left = 4
	st.corner_radius_top_right = 12
	st.corner_radius_bottom_left = 12
	st.corner_radius_bottom_right = 4
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	if state == "maxed" or state == "available" or selected:
		st.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.38)
		st.shadow_size = 10

	var hov := st.duplicate()
	hov.bg_color = bg.lightened(0.08)
	hov.border_color = Color.WHITE if selected else accent.lightened(0.35)

	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)

	var icon_tr := btn.get_node_or_null("HBox/Icon") as TextureRect
	if icon_tr:
		icon_tr.texture = item.texture if (item != null and item.texture != null) else null
		icon_tr.modulate = Color(0.45, 0.48, 0.55, 0.75) if state == "locked" else Color.WHITE

	var title_lbl := btn.get_node_or_null("HBox/Col/Title") as Label
	if title_lbl:
		title_lbl.text = str(def["title"])
		title_lbl.add_theme_color_override("font_color", title_col)
		title_lbl.add_theme_font_size_override("font_size", maxi(11, int(roundf(14.0 * _zoom))))

	var sub_lbl := btn.get_node_or_null("HBox/Col/Sub") as Label
	if sub_lbl:
		var pips := ""
		if max_lvl > 1:
			for i in range(max_lvl):
				pips += "●" if i < cur_lvl else "○"
			pips += "  "
		if state == "maxed":
			sub_lbl.text = pips + ("MAX" if max_lvl > 1 else "OWNED")
		elif state == "locked":
			sub_lbl.text = pips + "LOCKED"
		elif state == "locked_level":
			sub_lbl.text = pips + str(ev["reason"])
		else:
			sub_lbl.text = pips + ("₱%.0f" % cost)
		sub_lbl.add_theme_color_override("font_color", sub_col)
		sub_lbl.add_theme_font_size_override("font_size", maxi(10, int(roundf(12.0 * _zoom))))


func _refresh_inspector() -> void:
	var def := Registry.get_node_def(_selected_id)
	if def.is_empty():
		return
	var money := _get_money()
	var ev := Registry.evaluate_node(_selected_id, money, _pending_levels)
	var accent := Registry.get_branch_color(str(def["branch"]))
	var cur_lvl := int(ev["cur_level"])
	var max_lvl := int(ev["max_level"])
	var target_lvl := int(ev["target_level"])
	var state := str(ev["state"])
	var item: ItemData = ev.get("item")

	_insp_branch_lbl.text = Registry.get_branch_label(str(def["branch"]))
	_insp_branch_lbl.add_theme_color_override("font_color", accent)

	_insp_title_lbl.text = item.item_name if (item != null and item.item_name != "") else str(def["title"])
	_insp_icon.texture = item.texture if (item != null and item.texture != null) else null
	_insp_icon.modulate = Color(0.45, 0.48, 0.55, 0.8) if state == "locked" else Color.WHITE

	if state == "maxed":
		_insp_level_lbl.text = "Status: %s (%d / %d)" % [("MAXED OUT" if max_lvl > 1 else "OWNED"), cur_lvl, max_lvl]
		_insp_level_lbl.add_theme_color_override("font_color", accent)
	elif max_lvl > 1:
		_insp_level_lbl.text = "Level %d / %d  →  Next: Lv. %d" % [cur_lvl, max_lvl, target_lvl]
		_insp_level_lbl.add_theme_color_override("font_color", COL_TEXT)
	else:
		_insp_level_lbl.text = "Available to Unlock" if state.begins_with("available") else "Locked"
		_insp_level_lbl.add_theme_color_override("font_color", COL_TEXT if state.begins_with("available") else COL_MUTED)

	var desc_text := str(item.get_meta("upgrade_desc", "")) if item != null else ""
	if desc_text == "" and str(def["kind"]) == "tier":
		desc_text = "Expands your sari-sari store to Tier %d and unlocks new catalog stock." % int(def["tier"])
	_insp_desc_lbl.text = desc_text if desc_text != "" else "Store evolution upgrade."

	# Prerequisites checklist
	for ch in _insp_prereqs_box.get_children():
		ch.queue_free()
	var prereqs: Array = def.get("prereqs", [])
	if prereqs.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "✓ No prerequisite nodes required"
		none_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		none_lbl.add_theme_font_size_override("font_size", 14)
		none_lbl.add_theme_color_override("font_color", Color(0.54, 0.90, 0.64))
		_insp_prereqs_box.add_child(none_lbl)
	else:
		for pre_id in prereqs:
			var pdef := Registry.get_node_def(str(pre_id))
			var met := Registry.is_node_unlocked_in_tree(str(pre_id), _pending_levels)
			var row := Button.new()
			row.text = ("%s  %s" % ["✓" if met else "✕", str(pdef.get("title", pre_id))])
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.focus_mode = Control.FOCUS_NONE
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var r_st := UIStyle.create_flat_stylebox(Color(1, 1, 1, 0.04), 4, 8, 4)
			var r_hov := UIStyle.create_flat_stylebox(Color(1, 1, 1, 0.10), 4, 8, 4)
			row.add_theme_stylebox_override("normal", r_st)
			row.add_theme_stylebox_override("hover", r_hov)
			row.add_theme_stylebox_override("pressed", r_hov)
			row.add_theme_font_override("font", UIStyle.FONT_INDER)
			row.add_theme_font_size_override("font_size", 14)
			row.add_theme_color_override("font_color", Color(0.54, 0.92, 0.64) if met else Color(0.92, 0.48, 0.44))
			var target_pre := str(pre_id)
			row.pressed.connect(func():
				_selected_id = target_pre
				EventBus.request_sfx.emit("tab_switch")
				_refresh_all()
			)
			_insp_prereqs_box.add_child(row)

	# Tier unlocks preview (shows items unlocked at this tier)
	for ch in _insp_unlocks_box.get_children():
		ch.queue_free()
	if str(def["kind"]) == "tier" and is_instance_valid(StoryManager):
		var tier_num := int(def["tier"])
		var tier_items: Array[ItemData] = StoryManager.get_items_for_tier(tier_num)
		if not tier_items.is_empty():
			var hdr := Label.new()
			hdr.text = "UNLOCKS CATALOG ITEMS:"
			hdr.add_theme_font_override("font", _bold_font)
			hdr.add_theme_font_size_override("font_size", 13)
			hdr.add_theme_color_override("font_color", accent)
			_insp_unlocks_box.add_child(hdr)

			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 4)
			_insp_unlocks_box.add_child(flow)
			for ti in tier_items:
				var chip := Label.new()
				chip.text = "• " + ti.item_name
				chip.add_theme_font_override("font", UIStyle.FONT_INDER)
				chip.add_theme_font_size_override("font_size", 13)
				chip.add_theme_color_override("font_color", COL_TEXT)
				flow.add_child(chip)

	_insp_mario_lbl.visible = bool(def.get("mario_delivery", false)) and state != "maxed"

	# Buy button state
	var mario_busy := is_instance_valid(MarioManager) and MarioManager.is_restocking_active
	if state == "maxed":
		_insp_buy_btn.disabled = true
		_insp_buy_btn.text = "MAXED OUT" if max_lvl > 1 else "ALREADY OWNED"
		UIStyle.style_button(_insp_buy_btn, Color(0.16, 0.22, 0.20, 0.9), accent, 16.0, 6)
	elif mario_busy:
		_insp_buy_btn.disabled = true
		_insp_buy_btn.text = "MARIO IS DELIVERING..."
		UIStyle.style_button(_insp_buy_btn, Color(0.18, 0.19, 0.24, 0.9), COL_MUTED, 15.0, 6)
	elif bool(ev["can_buy"]):
		_insp_buy_btn.disabled = false
		var verb := "UPGRADE TO LV. %d" % target_lvl if cur_lvl >= 1 else "UNLOCK"
		_insp_buy_btn.text = "%s  ·  ₱%.0f" % [verb, float(ev["cost"])]
		UIStyle.style_button(_insp_buy_btn, Color(0.18, 0.56, 0.36, 1.0), Color.WHITE, 16.0, 6)
	else:
		_insp_buy_btn.disabled = true
		_insp_buy_btn.text = str(ev["reason"])
		UIStyle.style_button(_insp_buy_btn, Color(0.18, 0.19, 0.24, 0.9), Color(0.82, 0.58, 0.54), 15.0, 6)

	# Paint Studio shortcut for owned Roof Signage / Promo Poster
	var kind := str(def["kind"])
	var sf_lvl := int(def.get("storefront_level", 0))
	if kind == "storefront_step" and (sf_lvl == 1 or sf_lvl == 2) and is_instance_valid(StoryManager) and StoryManager.storefront_upgrade_level >= sf_lvl:
		_insp_paint_btn.visible = true
		_insp_paint_btn.text = "OPEN PAINT STUDIO (SIGNAGE)" if sf_lvl == 1 else "OPEN PAINT STUDIO (POSTER)"
		_insp_paint_btn.set_meta("paint_slot", "signage" if sf_lvl == 1 else "poster")
	else:
		_insp_paint_btn.visible = false


func _on_buy_pressed() -> void:
	if is_instance_valid(MarioManager) and MarioManager.is_restocking_active:
		return
	var money := _get_money()
	var ev := Registry.evaluate_node(_selected_id, money, _pending_levels)
	if not bool(ev["can_buy"]):
		AudioManager.play_sfx("error")
		return
	var item: ItemData = ev.get("item")
	var cost := float(ev["cost"])
	if item == null:
		return

	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	if not gm_nodes.is_empty() and gm_nodes[0].has_method("deduct_money"):
		gm_nodes[0].deduct_money(cost)

	_pending_levels[_selected_id] = int(_pending_levels.get(_selected_id, 0)) + 1
	_pending_delivery_items[item] = 1

	AudioManager.play_sfx("purchase")
	_refresh_all()


func _on_paint_pressed() -> void:
	var slot := str(_insp_paint_btn.get_meta("paint_slot", "signage"))
	close_tree()
	for pm in get_tree().get_nodes_in_group("pause_menu"):
		if pm.has_method("_open_storefront_canvas"):
			pm._open_storefront_canvas(slot)
			return
	var ov := StorefrontCanvasOverlay.new()
	get_tree().current_scene.add_child(ov)
	ov.open_canvas(slot)


func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_drag_moved = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(1.10, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(0.90, mb.position)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_pan += mm.relative
		_drag_moved = true
		_layout_nodes()


func _apply_zoom(factor: float, pivot: Vector2) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom * factor, 0.62, 1.35)
	if is_equal_approx(_zoom, old_zoom):
		return
	var world_at_pivot := (pivot - _pan) / old_zoom
	_pan = pivot - world_at_pivot * _zoom
	_layout_nodes()


func _draw_graph() -> void:
	if not is_instance_valid(_graph_drawer):
		return
	var sz := _graph_drawer.size
	var money := _get_money()

	# Subtle blueprint grid
	var grid_step := 64.0 * _zoom
	if grid_step >= 16.0:
		var ox := fmod(_pan.x, grid_step)
		var oy := fmod(_pan.y, grid_step)
		var x := ox
		while x < sz.x:
			_graph_drawer.draw_line(Vector2(x, 0), Vector2(x, sz.y), COL_GRID, 1.0)
			x += grid_step
		var y := oy
		while y < sz.y:
			_graph_drawer.draw_line(Vector2(0, y), Vector2(sz.x, y), COL_GRID, 1.0)
			y += grid_step

	# Draw angled circuit/runic traces between prerequisites and children
	for n in Registry.get_all_nodes():
		var child_id := str(n["id"])
		var child_pt := _world_to_canvas(_logical_to_world(n["pos"]))
		var child_unlocked := Registry.is_node_unlocked_in_tree(child_id, _pending_levels)
		var child_ev := Registry.evaluate_node(child_id, money, _pending_levels)
		var child_avail := str(child_ev["state"]).begins_with("available")
		var accent := Registry.get_branch_color(str(n["branch"]))

		for pre_id in n.get("prereqs", []):
			var pdef := Registry.get_node_def(str(pre_id))
			if pdef.is_empty():
				continue
			var parent_pt := _world_to_canvas(_logical_to_world(pdef["pos"]))
			var parent_unlocked := Registry.is_node_unlocked_in_tree(str(pre_id), _pending_levels)

			var line_col := Color(0.20, 0.24, 0.32, 0.62)
			var width := 2.5 * _zoom
			if parent_unlocked and child_unlocked:
				line_col = accent
				width = 3.6 * _zoom
			elif parent_unlocked and child_avail:
				line_col = Color(accent.r, accent.g, accent.b, 0.78)
				width = 3.0 * _zoom

			# 3-segment Cyberpunk circuit elbow
			var mid_y := lerpf(parent_pt.y, child_pt.y, 0.5)
			var pts := PackedVector2Array([
				parent_pt,
				Vector2(parent_pt.x, mid_y),
				Vector2(child_pt.x, mid_y),
				child_pt,
			])
			if parent_unlocked:
				_graph_drawer.draw_polyline(pts, Color(line_col.r, line_col.g, line_col.b, 0.20), width + 5.0 * _zoom, true)
			_graph_drawer.draw_polyline(pts, line_col, width, true)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BG
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	_root.add_child(outer)

	# ── TOP HUD BAR ──
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 64)
	var tb_st := UIStyle.create_flat_stylebox(Color(0.05, 0.058, 0.082, 0.98), 0, 24, 10)
	tb_st.border_width_bottom = 2
	tb_st.border_color = Color(0.95, 0.76, 0.34, 0.45)
	top_bar.add_theme_stylebox_override("panel", tb_st)
	outer.add_child(top_bar)

	var thbox := HBoxContainer.new()
	thbox.add_theme_constant_override("separation", 20)
	top_bar.add_child(thbox)

	var title_lbl := Label.new()
	title_lbl.text = "STORE EVOLUTION"
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.80, 0.40, 1.0))
	thbox.add_child(title_lbl)

	_top_stats_lbl = Label.new()
	_top_stats_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_stats_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_stats_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_top_stats_lbl.add_theme_font_size_override("font_size", 16)
	_top_stats_lbl.add_theme_color_override("font_color", COL_MUTED)
	thbox.add_child(_top_stats_lbl)

	_pending_lbl = Label.new()
	_pending_lbl.add_theme_font_override("font", _bold_font)
	_pending_lbl.add_theme_font_size_override("font_size", 15)
	_pending_lbl.add_theme_color_override("font_color", Color(0.32, 0.88, 0.96, 1.0))
	thbox.add_child(_pending_lbl)

	_money_lbl = Label.new()
	_money_lbl.add_theme_font_override("font", _bold_font)
	_money_lbl.add_theme_font_size_override("font_size", 22)
	_money_lbl.add_theme_color_override("font_color", Color(0.54, 0.94, 0.64, 1.0))
	thbox.add_child(_money_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕  CLOSE [U]"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(close_btn, Color(0.18, 0.14, 0.16, 0.95), Color(1.0, 0.88, 0.80), 14.0, 6)
	close_btn.pressed.connect(close_tree)
	thbox.add_child(close_btn)

	# ── MAIN SPLIT: Interactive Graph (Left) + Inspector Drawer (Right) ──
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 0)
	outer.add_child(split)

	_canvas_clip = Control.new()
	_canvas_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_clip.size_flags_stretch_ratio = 2.05
	_canvas_clip.clip_contents = true
	_canvas_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_clip.gui_input.connect(_on_canvas_gui_input)
	split.add_child(_canvas_clip)

	_graph_drawer = Control.new()
	_graph_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_drawer.draw.connect(_draw_graph)
	_canvas_clip.add_child(_graph_drawer)

	_node_layer = Control.new()
	_node_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_node_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas_clip.add_child(_node_layer)

	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var btn := _create_node_button(nid)
		_node_layer.add_child(btn)
		_node_buttons[nid] = btn

	# Bottom-left canvas hint + Reset View pill
	var hint_row := HBoxContainer.new()
	hint_row.anchor_left = 0.0
	hint_row.anchor_top = 1.0
	hint_row.anchor_bottom = 1.0
	hint_row.offset_left = 18
	hint_row.offset_top = -48
	hint_row.offset_bottom = -14
	hint_row.add_theme_constant_override("separation", 12)
	_canvas_clip.add_child(hint_row)

	var hint_lbl := Label.new()
	hint_lbl.text = "Drag to pan   •   Scroll to zoom"
	hint_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	hint_lbl.add_theme_font_size_override("font_size", 14)
	hint_lbl.add_theme_color_override("font_color", COL_MUTED)
	hint_row.add_child(hint_lbl)

	var reset_btn := Button.new()
	reset_btn.text = "Center View [F]"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(reset_btn, Color(0.12, 0.14, 0.20, 0.92), COL_TEXT, 13.0, 6)
	reset_btn.pressed.connect(_reset_view)
	hint_row.add_child(reset_btn)

	# ── RIGHT-SIDE INSPECTOR DRAWER ──
	var insp := PanelContainer.new()
	insp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp.size_flags_stretch_ratio = 1.0
	var insp_st := UIStyle.create_flat_stylebox(COL_PANEL, 0, 24, 22)
	insp_st.border_width_left = 2
	insp_st.border_color = Color(0.24, 0.28, 0.38, 0.90)
	insp.add_theme_stylebox_override("panel", insp_st)
	split.add_child(insp)

	var ivbox := VBoxContainer.new()
	ivbox.add_theme_constant_override("separation", 12)
	insp.add_child(ivbox)

	_insp_branch_lbl = Label.new()
	_insp_branch_lbl.add_theme_font_override("font", _bold_font)
	_insp_branch_lbl.add_theme_font_size_override("font_size", 13)
	ivbox.add_child(_insp_branch_lbl)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 14)
	ivbox.add_child(head_row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(76, 76)
	var if_st := UIStyle.create_flat_stylebox(Color(0.04, 0.045, 0.065, 0.95), 8, 8, 8)
	if_st.border_color = Color(0.30, 0.34, 0.44, 0.85)
	if_st.set_border_width_all(1)
	icon_frame.add_theme_stylebox_override("panel", if_st)
	head_row.add_child(icon_frame)

	_insp_icon = TextureRect.new()
	_insp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_insp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.add_child(_insp_icon)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_col.add_theme_constant_override("separation", 4)
	head_row.add_child(title_col)

	_insp_title_lbl = Label.new()
	_insp_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insp_title_lbl.add_theme_font_override("font", _bold_font)
	_insp_title_lbl.add_theme_font_size_override("font_size", 24)
	_insp_title_lbl.add_theme_color_override("font_color", COL_TEXT)
	title_col.add_child(_insp_title_lbl)

	_insp_level_lbl = Label.new()
	_insp_level_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_insp_level_lbl.add_theme_font_size_override("font_size", 15)
	title_col.add_child(_insp_level_lbl)

	_insp_desc_lbl = Label.new()
	_insp_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insp_desc_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_insp_desc_lbl.add_theme_font_size_override("font_size", 16)
	_insp_desc_lbl.add_theme_constant_override("line_spacing", 4)
	_insp_desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.86, 0.96))
	ivbox.add_child(_insp_desc_lbl)

	var pre_hdr := Label.new()
	pre_hdr.text = "PREREQUISITES"
	pre_hdr.add_theme_font_override("font", _bold_font)
	pre_hdr.add_theme_font_size_override("font_size", 13)
	pre_hdr.add_theme_color_override("font_color", COL_MUTED)
	ivbox.add_child(pre_hdr)

	_insp_prereqs_box = VBoxContainer.new()
	_insp_prereqs_box.add_theme_constant_override("separation", 4)
	ivbox.add_child(_insp_prereqs_box)

	_insp_unlocks_box = VBoxContainer.new()
	_insp_unlocks_box.add_theme_constant_override("separation", 6)
	ivbox.add_child(_insp_unlocks_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ivbox.add_child(spacer)

	_insp_mario_lbl = Label.new()
	_insp_mario_lbl.text = "Uncle Mario delivers queued upgrades when you close [U]."
	_insp_mario_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insp_mario_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_insp_mario_lbl.add_theme_font_size_override("font_size", 14)
	_insp_mario_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.40, 0.92))
	ivbox.add_child(_insp_mario_lbl)

	_insp_paint_btn = Button.new()
	_insp_paint_btn.custom_minimum_size = Vector2(0, 42)
	_insp_paint_btn.focus_mode = Control.FOCUS_NONE
	_insp_paint_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_insp_paint_btn, Color(0.76, 0.44, 0.16, 1.0), Color.WHITE, 15.0, 6)
	_insp_paint_btn.pressed.connect(_on_paint_pressed)
	ivbox.add_child(_insp_paint_btn)

	_insp_buy_btn = Button.new()
	_insp_buy_btn.custom_minimum_size = Vector2(0, 50)
	_insp_buy_btn.focus_mode = Control.FOCUS_NONE
	_insp_buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insp_buy_btn.pressed.connect(_on_buy_pressed)
	ivbox.add_child(_insp_buy_btn)


func _create_node_button(node_id: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_contents = true

	var hb := HBoxContainer.new()
	hb.name = "HBox"
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)

	var title := Label.new()
	title.name = "Title"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_override("font", _bold_font)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	var sub := Label.new()
	sub.name = "Sub"
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)

	btn.pressed.connect(func():
		_selected_id = node_id
		EventBus.request_sfx.emit("tab_switch")
		_refresh_all()
	)
	return btn
