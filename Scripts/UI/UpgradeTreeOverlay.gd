class_name UpgradeTreeOverlay
extends CanvasLayer

## Cozy Store Upgrades Skill Tree ([U]).
## Compact wooden-framed kraft-parchment board: Store Tiers 2->10 along the bottom,
## 4 vertical branches rising to [Open the Door], succinct hover tooltips using the
## EventsOverlay stat-row format, and Uncle Mario delivery queued on close.

const Registry := preload("res://Scripts/Progression/UpgradeTreeRegistry.gd")
const PESO_ICON_TEX := preload("res://Assets/ui/peso_icon.png")

const COL_WOOD_DARK := Color(0.24, 0.14, 0.09, 0.99)
const COL_WOOD_MID := Color(0.36, 0.22, 0.14, 0.98)
const COL_BRASS := Color(0.78, 0.56, 0.24, 0.95)
const COL_PARCHMENT := Color(0.90, 0.81, 0.64, 1.0)
const COL_PARCHMENT_EDGE := Color(0.44, 0.28, 0.16, 0.95)
const COL_CREAM := Color(1.0, 0.95, 0.85, 1.0)
const COL_INK := Color(0.20, 0.12, 0.07, 0.96)
const COL_PATH_OUTLINE := Color(0.24, 0.14, 0.08, 0.92)
const COL_PATH_LIT := Color(0.86, 0.62, 0.24, 1.0)
const COL_PATH_AVAIL := Color(0.72, 0.54, 0.30, 0.88)
const COL_PATH_LOCKED := Color(0.56, 0.46, 0.35, 0.45)

# Matches EventsOverlay stat-row palette
const COL_STAT_POS := Color(0.56, 0.92, 0.52, 1.0)
const COL_STAT_NEG := Color(0.96, 0.48, 0.45, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)

const ICON_SIZE := Vector2(68, 68)
const CAPSTONE_SIZE := Vector2(82, 82)

var is_open: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _hovered_id: String = ""

var _pending_levels: Dictionary = {}         # node_id -> int
var _pending_delivery_items: Dictionary = {} # ItemData -> 1

var _bold_font: FontVariation
var _root: Control
var _board_panel: PanelContainer
var _tree_area: Control
var _path_drawer: Control
var _node_buttons: Dictionary = {} # node_id -> Button

var _money_lbl: Label
var _pending_lbl: Label
var _tooltip: PanelContainer
var _tip_title: Label
var _tip_level: Label
var _tip_stats_box: VBoxContainer
var _tip_desc: Label
var _tip_price_row: HBoxContainer
var _tip_price_lbl: Label
var _tip_status: Label


func _ready() -> void:
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_tree_overlay")

	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.55

	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if is_open:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_U:
				get_viewport().set_input_as_handled()
				close_tree()
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


func open_tree(_focus_node_id: String = "") -> void:
	if is_open:
		return
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	visible = true
	_hovered_id = ""
	_pending_levels.clear()
	_pending_delivery_items.clear()
	if is_instance_valid(_tooltip):
		_tooltip.visible = false

	EventBus.request_sfx.emit("tab_switch")
	_refresh_all()
	call_deferred("_layout_nodes")


func close_tree() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_hovered_id = ""
	if is_instance_valid(_tooltip):
		_tooltip.visible = false
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


func _get_money() -> float:
	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	return float(gm_nodes[0].money) if not gm_nodes.is_empty() else 0.0


func _node_center(lpos: Vector2) -> Vector2:
	if not is_instance_valid(_tree_area):
		return Vector2.ZERO
	var sz := _tree_area.size
	var pad_x := 72.0
	var pad_top := 62.0
	var pad_bot := 56.0
	var usable_w := maxf(240.0, sz.x - pad_x * 2.0)
	var usable_h := maxf(200.0, sz.y - pad_top - pad_bot)
	# Logical x in [0 .. 8], logical y in [0 .. 4] (bottom-up)
	var nx := lpos.x / 8.0
	var ny := 1.0 - (lpos.y / 4.0)
	return Vector2(pad_x + nx * usable_w, pad_top + ny * usable_h)


func _refresh_all() -> void:
	var money := _get_money()
	if is_instance_valid(_money_lbl):
		_money_lbl.text = "%.2f" % money
	if is_instance_valid(_pending_lbl):
		var cnt := _pending_delivery_items.size()
		_pending_lbl.visible = cnt > 0
		_pending_lbl.text = "Queued: %d" % cnt

	_layout_nodes()
	if _hovered_id != "":
		_show_tooltip_for(_hovered_id)


func _layout_nodes() -> void:
	if not is_instance_valid(_tree_area) or _tree_area.size.x < 10.0:
		return
	var money := _get_money()
	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var btn: Button = _node_buttons.get(nid)
		if not is_instance_valid(btn):
			continue
		var sz := CAPSTONE_SIZE if nid == "open_door" else ICON_SIZE
		var center := _node_center(n["pos"])
		btn.position = center - sz * 0.5
		btn.size = sz
		var ev := Registry.evaluate_node(nid, money, _pending_levels)
		_style_node_button(btn, n, ev, nid == _hovered_id)

	if is_instance_valid(_path_drawer):
		_path_drawer.queue_redraw()


func _style_node_button(btn: Button, _def: Dictionary, ev: Dictionary, hovered: bool) -> void:
	var state := str(ev["state"])
	var cur_lvl := int(ev["cur_level"])
	var max_lvl := int(ev["max_level"])
	var item: ItemData = ev.get("item")

	var bg := Color(0.95, 0.88, 0.72, 1.0)
	var border_col := Color(0.36, 0.22, 0.13, 1.0)
	var border_w := 2
	var icon_mod := Color.WHITE
	var badge_text := ""
	var badge_col := COL_INK

	match state:
		"maxed":
			bg = Color(0.98, 0.90, 0.62, 1.0)
			border_col = Color(0.72, 0.48, 0.12, 1.0)
			border_w = 3
			badge_text = "%d/%d" % [cur_lvl, max_lvl] if max_lvl > 1 else "✓"
			badge_col = Color(0.12, 0.44, 0.18, 1.0)
		"available":
			bg = Color(0.99, 0.95, 0.84, 1.0)
			border_col = Color(0.22, 0.58, 0.28, 1.0)
			border_w = 3
			badge_text = "%d/%d" % [cur_lvl, max_lvl] if max_lvl > 1 else "+"
			badge_col = Color(0.12, 0.44, 0.18, 1.0)
		"available_poor":
			bg = Color(0.92, 0.84, 0.68, 1.0)
			border_col = Color(0.68, 0.34, 0.20, 0.95)
			badge_text = "%d/%d" % [cur_lvl, max_lvl] if max_lvl > 1 else ""
			badge_col = Color(0.65, 0.18, 0.14, 1.0)
		_:
			bg = Color(0.68, 0.58, 0.44, 0.88)
			border_col = Color(0.34, 0.23, 0.14, 0.85)
			icon_mod = Color(0.38, 0.32, 0.26, 0.72)
			badge_text = "🔒"
			badge_col = Color(0.24, 0.16, 0.10, 0.90)

	if hovered:
		border_col = Color(1.0, 0.86, 0.44, 1.0)
		border_w = 3

	var st := UIStyle.create_flat_stylebox(bg, 6, 4, 4)
	st.border_color = border_col
	st.set_border_width_all(border_w)
	st.shadow_color = Color(0.18, 0.10, 0.04, 0.32)
	st.shadow_size = 3

	var hov := st.duplicate()
	hov.bg_color = bg.lightened(0.06)
	hov.border_color = Color(1.0, 0.86, 0.44, 1.0)
	hov.set_border_width_all(3)

	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)

	var icon_tr := btn.get_node_or_null("Icon") as TextureRect
	if icon_tr:
		icon_tr.texture = item.texture if (item != null and item.texture != null) else null
		icon_tr.modulate = icon_mod

	var badge := btn.get_node_or_null("Badge") as Label
	if badge:
		badge.text = badge_text
		badge.visible = badge_text != ""
		badge.add_theme_color_override("font_color", badge_col)


func _show_tooltip_for(node_id: String) -> void:
	var def := Registry.get_node_def(node_id)
	if def.is_empty() or not is_instance_valid(_tooltip):
		return

	var money := _get_money()
	var ev := Registry.evaluate_node(node_id, money, _pending_levels)
	var state := str(ev["state"])
	var cur_lvl := int(ev["cur_level"])
	var max_lvl := int(ev["max_level"])
	var target_lvl := int(ev["target_level"])
	var cost := float(ev["cost"])
	var item: ItemData = ev.get("item")

	_tip_title.text = item.item_name if (item != null and item.item_name != "") else str(def["title"])
	if max_lvl > 1:
		_tip_level.text = "Lv.%d/%d" % [cur_lvl, max_lvl]
	else:
		_tip_level.text = "Owned" if state == "maxed" else ""
	_tip_level.visible = _tip_level.text != ""

	# Render Event-Card-style stat rows
	for ch in _tip_stats_box.get_children():
		ch.queue_free()
	var stats := Registry.get_node_stats(node_id, target_lvl)
	_tip_stats_box.visible = not stats.is_empty()
	for st in stats:
		var s_row := HBoxContainer.new()
		s_row.add_theme_constant_override("separation", 8)
		s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_stats_box.add_child(s_row)

		var s_name := Label.new()
		s_name.text = "▸ " + str(st.get("label", ""))
		s_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
		s_name.add_theme_font_size_override("font_size", 13)
		s_name.add_theme_color_override("font_color", COL_CREAM)
		s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_row.add_child(s_name)

		var s_val := Label.new()
		s_val.text = str(st.get("value", ""))
		s_val.add_theme_font_override("font", _bold_font)
		s_val.add_theme_font_size_override("font_size", 14)
		var tone := str(st.get("tone", "pos"))
		var val_col := COL_STAT_POS if tone == "pos" else (COL_STAT_NEG if tone == "neg" else COL_GOLD_BRIGHT)
		s_val.add_theme_color_override("font_color", val_col)
		s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_row.add_child(s_val)

	# Restored description (from item metadata or Tier catalog items)
	var desc := str(item.get_meta("upgrade_desc", "")) if item != null else ""
	if str(def["kind"]) == "tier" and is_instance_valid(InventoryManager):
		var target_t := int(def["tier"])
		var names: Array[String] = []
		for ti in InventoryManager.get_all_items():
			if ti != null and ti.can_be_sold and ti.tier == target_t:
				names.append(ti.item_name)
				if names.size() >= 5:
					break
		if not names.is_empty():
			desc = "Unlocks: " + ", ".join(names)
	_tip_desc.text = desc
	_tip_desc.visible = desc != ""

	var mario_busy := is_instance_valid(MarioManager) and MarioManager.is_restocking_active
	var kind := str(def["kind"])
	var sf_lvl := int(def.get("storefront_level", 0))
	var can_paint := kind == "storefront_step" and (sf_lvl == 1 or sf_lvl == 2) and is_instance_valid(StoryManager) and StoryManager.storefront_upgrade_level >= sf_lvl

	var show_price := (state == "available" or state == "available_poor" or state == "locked") and cost > 0.0
	_tip_price_row.visible = show_price
	if show_price:
		_tip_price_lbl.text = "%.0f" % cost
		_tip_price_lbl.add_theme_color_override("font_color", COL_STAT_POS if money >= cost else COL_STAT_NEG)

	if can_paint:
		_tip_status.text = "Owned  •  Click to Paint"
		_tip_status.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	elif state == "maxed":
		_tip_status.text = "Owned"
		_tip_status.add_theme_color_override("font_color", COL_STAT_POS)
	elif mario_busy:
		_tip_status.text = "Mario is delivering..."
		_tip_status.add_theme_color_override("font_color", Color(0.84, 0.78, 0.68))
	elif bool(ev["can_buy"]):
		_tip_status.text = "Click to Unlock"
		_tip_status.add_theme_color_override("font_color", COL_STAT_POS)
	elif state == "available_poor":
		_tip_status.text = "Not enough pesos"
		_tip_status.add_theme_color_override("font_color", COL_STAT_NEG)
	else:
		var missing: Array[String] = []
		for pre_id in def.get("prereqs", []):
			if not Registry.is_node_unlocked_in_tree(str(pre_id), _pending_levels):
				var pdef := Registry.get_node_def(str(pre_id))
				missing.append(str(pdef.get("title", pre_id)))
		_tip_status.text = ("Requires: " + ", ".join(missing)) if not missing.is_empty() else str(ev["reason"])
		_tip_status.add_theme_color_override("font_color", Color(0.90, 0.74, 0.52))

	_tooltip.visible = true
	_tooltip.reset_size()
	call_deferred("_position_tooltip_beside", node_id)


func _position_tooltip_beside(node_id: String) -> void:
	if not is_instance_valid(_tooltip) or not _tooltip.visible:
		return
	var btn: Button = _node_buttons.get(node_id)
	if not is_instance_valid(btn):
		return
	var br := btn.get_global_rect()
	var vp := get_viewport().get_visible_rect().size
	var tsz := _tooltip.size
	var tx := br.end.x + 12.0
	if tx + tsz.x > vp.x - 12.0:
		tx = br.position.x - tsz.x - 12.0
	var ty := clampf(br.position.y + br.size.y * 0.5 - tsz.y * 0.5, 12.0, vp.y - tsz.y - 12.0)
	_tooltip.global_position = Vector2(tx, ty)


func _on_node_pressed(node_id: String) -> void:
	var def := Registry.get_node_def(node_id)
	if def.is_empty():
		return

	var kind := str(def["kind"])
	var sf_lvl := int(def.get("storefront_level", 0))
	if kind == "storefront_step" and (sf_lvl == 1 or sf_lvl == 2) and is_instance_valid(StoryManager) and StoryManager.storefront_upgrade_level >= sf_lvl:
		var slot := "signage" if sf_lvl == 1 else "poster"
		close_tree()
		for pm in get_tree().get_nodes_in_group("pause_menu"):
			if pm.has_method("_open_storefront_canvas"):
				pm._open_storefront_canvas(slot)
				return
		var ov := StorefrontCanvasOverlay.new()
		get_tree().current_scene.add_child(ov)
		ov.open_canvas(slot)
		return

	if is_instance_valid(MarioManager) and MarioManager.is_restocking_active:
		AudioManager.play_sfx("error")
		return

	var money := _get_money()
	var ev := Registry.evaluate_node(node_id, money, _pending_levels)
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

	_pending_levels[node_id] = int(_pending_levels.get(node_id, 0)) + 1
	_pending_delivery_items[item] = 1
	AudioManager.play_sfx("purchase")
	_refresh_all()


func _draw_paths() -> void:
	if not is_instance_valid(_path_drawer):
		return
	var money := _get_money()
	for n in Registry.get_all_nodes():
		var child_id := str(n["id"])
		var child_pt := _node_center(n["pos"])
		var child_unlocked := Registry.is_node_unlocked_in_tree(child_id, _pending_levels)
		var child_ev := Registry.evaluate_node(child_id, money, _pending_levels)
		var child_avail := str(child_ev["state"]).begins_with("available")

		for pre_id in n.get("prereqs", []):
			var pdef := Registry.get_node_def(str(pre_id))
			if pdef.is_empty():
				continue
			var parent_pt := _node_center(pdef["pos"])
			var parent_unlocked := Registry.is_node_unlocked_in_tree(str(pre_id), _pending_levels)

			var pts: PackedVector2Array
			if is_equal_approx(parent_pt.y, child_pt.y) or is_equal_approx(parent_pt.x, child_pt.x):
				pts = PackedVector2Array([parent_pt, child_pt])
			else:
				var mid_y := lerpf(parent_pt.y, child_pt.y, 0.5)
				pts = PackedVector2Array([
					parent_pt,
					Vector2(parent_pt.x, mid_y),
					Vector2(child_pt.x, mid_y),
					child_pt,
				])

			var fill_col := COL_PATH_LOCKED
			if parent_unlocked and child_unlocked:
				fill_col = COL_PATH_LIT
			elif parent_unlocked and child_avail:
				fill_col = COL_PATH_AVAIL

			_path_drawer.draw_polyline(pts, COL_PATH_OUTLINE, 8.0, true)
			_path_drawer.draw_polyline(pts, fill_col, 4.0, true)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.03, 0.02, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close_tree()
	)
	_root.add_child(backdrop)

	# Full-screen framed wooden board
	_board_panel = PanelContainer.new()
	_board_panel.anchor_left = 0.025
	_board_panel.anchor_right = 0.975
	_board_panel.anchor_top = 0.035
	_board_panel.anchor_bottom = 0.965
	var wood_st := UIStyle.create_flat_stylebox(COL_WOOD_DARK, 12, 18, 14)
	wood_st.border_color = COL_BRASS
	wood_st.set_border_width_all(3)
	wood_st.shadow_color = Color(0, 0, 0, 0.60)
	wood_st.shadow_size = 18
	_board_panel.add_theme_stylebox_override("panel", wood_st)
	_root.add_child(_board_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_board_panel.add_child(vbox)

	# Top bar with Peso logo
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vbox.add_child(top)

	var title := Label.new()
	title.text = "Store Upgrades"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_CREAM)
	top.add_child(title)

	_pending_lbl = Label.new()
	_pending_lbl.add_theme_font_override("font", _bold_font)
	_pending_lbl.add_theme_font_size_override("font_size", 16)
	_pending_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	top.add_child(_pending_lbl)

	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 6)
	money_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(money_row)

	var peso_hdr := TextureRect.new()
	peso_hdr.texture = PESO_ICON_TEX
	peso_hdr.custom_minimum_size = Vector2(26, 26)
	peso_hdr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	peso_hdr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	peso_hdr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_row.add_child(peso_hdr)

	_money_lbl = Label.new()
	_money_lbl.add_theme_font_override("font", _bold_font)
	_money_lbl.add_theme_font_size_override("font_size", 24)
	_money_lbl.add_theme_color_override("font_color", COL_STAT_POS)
	money_row.add_child(_money_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Close [U / Esc]"
	close_btn.custom_minimum_size = Vector2(34, 34)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(close_btn, COL_WOOD_MID, COL_CREAM, 16.0, 8)
	close_btn.pressed.connect(close_tree)
	top.add_child(close_btn)

	# Inner kraft-parchment board
	var parchment := PanelContainer.new()
	parchment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pst := UIStyle.create_flat_stylebox(COL_PARCHMENT, 8, 6, 6)
	pst.border_color = COL_PARCHMENT_EDGE
	pst.set_border_width_all(2)
	parchment.add_theme_stylebox_override("panel", pst)
	vbox.add_child(parchment)

	_tree_area = Control.new()
	_tree_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_area.resized.connect(_layout_nodes)
	parchment.add_child(_tree_area)

	_path_drawer = Control.new()
	_path_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_path_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path_drawer.draw.connect(_draw_paths)
	_tree_area.add_child(_path_drawer)

	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var btn := _create_node_button(nid)
		_tree_area.add_child(btn)
		_node_buttons[nid] = btn

	# Floating tooltip (warm espresso + brass border, restored description + Event-Card stats + Peso price)
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.z_index = 40
	_tooltip.custom_minimum_size = Vector2(285, 0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tst := UIStyle.create_flat_stylebox(Color(0.06, 0.05, 0.042, 0.96), 10, 16, 12)
	tst.border_color = COL_BRASS
	tst.set_border_width_all(2)
	tst.shadow_color = Color(0, 0, 0, 0.55)
	tst.shadow_size = 12
	_tooltip.add_theme_stylebox_override("panel", tst)
	_root.add_child(_tooltip)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 7)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(tv)

	var thead := HBoxContainer.new()
	thead.add_theme_constant_override("separation", 10)
	thead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(thead)

	_tip_title = Label.new()
	_tip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_title.add_theme_font_override("font", _bold_font)
	_tip_title.add_theme_font_size_override("font_size", 19)
	_tip_title.add_theme_color_override("font_color", COL_CREAM)
	_tip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thead.add_child(_tip_title)

	_tip_level = Label.new()
	_tip_level.add_theme_font_override("font", _bold_font)
	_tip_level.add_theme_font_size_override("font_size", 14)
	_tip_level.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_tip_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thead.add_child(_tip_level)

	_tip_desc = Label.new()
	_tip_desc.custom_minimum_size = Vector2(255, 0)
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.add_theme_font_override("font", UIStyle.FONT_INDER)
	_tip_desc.add_theme_font_size_override("font_size", 14)
	_tip_desc.add_theme_color_override("font_color", Color(0.86, 0.80, 0.70))
	_tip_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_desc)

	_tip_stats_box = VBoxContainer.new()
	_tip_stats_box.add_theme_constant_override("separation", 3)
	_tip_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_stats_box)

	_tip_price_row = HBoxContainer.new()
	_tip_price_row.add_theme_constant_override("separation", 6)
	_tip_price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_price_row)

	var peso_tip := TextureRect.new()
	peso_tip.texture = PESO_ICON_TEX
	peso_tip.custom_minimum_size = Vector2(22, 22)
	peso_tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	peso_tip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	peso_tip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	peso_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_price_row.add_child(peso_tip)

	_tip_price_lbl = Label.new()
	_tip_price_lbl.add_theme_font_override("font", _bold_font)
	_tip_price_lbl.add_theme_font_size_override("font_size", 21)
	_tip_price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_price_row.add_child(_tip_price_lbl)

	_tip_status = Label.new()
	_tip_status.add_theme_font_override("font", _bold_font)
	_tip_status.add_theme_font_size_override("font_size", 14)
	_tip_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_status)


func _create_node_button(node_id: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	var badge := Label.new()
	badge.name = "Badge"
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = -34
	badge.offset_top = -17
	badge.offset_right = -2
	badge.offset_bottom = -1
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	badge.add_theme_font_override("font", _bold_font)
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_constant_override("outline_size", 3)
	badge.add_theme_color_override("font_outline_color", Color(0.98, 0.95, 0.86, 0.95))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)

	btn.mouse_entered.connect(func():
		_hovered_id = node_id
		_layout_nodes()
		_show_tooltip_for(node_id)
	)
	btn.mouse_exited.connect(func():
		if _hovered_id == node_id:
			_hovered_id = ""
			if is_instance_valid(_tooltip):
				_tooltip.visible = false
			_layout_nodes()
	)
	btn.pressed.connect(func(): _on_node_pressed(node_id))
	return btn
