class_name UpgradeTreeOverlay
extends CanvasLayer

## Cozy Store Upgrades Skill Tree ([U]).
## Compact wooden-framed kraft-parchment board: Store Tiers 2->10 along the bottom,
## 4 vertical branches rising to [Open the Door], succinct hover tooltips using the
## EventsOverlay stat-row format, and Uncle Mario delivery queued on close.

const Registry := preload("res://Scripts/Progression/UpgradeTreeRegistry.gd")
const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
const PESO_ICON_TEX := preload("res://Assets/ui/peso_icon.png")

const COL_WOOD_DARK := Color(0.24, 0.14, 0.09, 0.99)
const COL_WOOD_MID := Color(0.36, 0.22, 0.14, 0.98)
const COL_BRASS := Color(0.78, 0.56, 0.24, 0.95)
const COL_PARCHMENT := Color(0.90, 0.81, 0.64, 1.0)
const COL_PARCHMENT_EDGE := Color(0.44, 0.28, 0.16, 0.95)
const COL_CREAM := Color(1.0, 0.95, 0.85, 1.0)
const COL_INK := Color(0.20, 0.12, 0.07, 0.96)
const COL_PATH_OUTLINE := Color(0.02, 0.015, 0.01, 0.85)
const COL_PATH_LIT := Color(0.94, 0.76, 0.36, 1.0)
const COL_PATH_AVAIL := Color(0.54, 0.84, 0.52, 0.88)
const COL_PATH_LOCKED := Color(0.32, 0.26, 0.20, 0.55)
const COL_OUTLINE := Color(0.05, 0.038, 0.028, 0.95)

# Matches EventsOverlay stat-row palette
const COL_STAT_POS := Color(0.56, 0.92, 0.52, 1.0)
const COL_STAT_NEG := Color(0.96, 0.48, 0.45, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)

const ICON_SIZE := Vector2(74, 74)
const CAPSTONE_SIZE := Vector2(88, 88)

var is_open: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _hovered_id: String = ""
var _anim_time: float = 0.0

var _pending_levels: Dictionary = {} # node_id -> int
var _pending_delivery_items: Dictionary = {} # ItemData -> 1

# Active unlock celebration FX:
# _path_surges: Array of {"pts": PackedVector2Array, "t": float, "dur": float}
# _unlock_rings: Array of {"center": Vector2, "t": float, "dur": float, "base_r": float, "col": Color}
var _path_surges: Array[Dictionary] = []
var _unlock_rings: Array[Dictionary] = []
var _hover_tweens: Dictionary = {} # node_id -> Tween
var _available_border_styles: Array[StyleBoxFlat] = []

var _bold_font: FontVariation
var _root: Control
var _board_panel: PanelContainer
var _tree_area: Control
var _path_drawer: Control
var _fx_drawer: Control
var _node_buttons: Dictionary = {} # node_id -> Button

var _money_lbl: Label # legacy; the HUD money counter is elevated instead
var _hud_money: Control
var _hud_money_parent: Node
var _hud_money_index: int = 0
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
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_tree_overlay")

	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.55

	_build_ui()
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not is_open:
		return
	_anim_time += delta

	for i in range(_path_surges.size() - 1, -1, -1):
		_path_surges[i]["t"] = float(_path_surges[i]["t"]) + delta
		if float(_path_surges[i]["t"]) >= float(_path_surges[i]["dur"]):
			_path_surges.remove_at(i)

	for i in range(_unlock_rings.size() - 1, -1, -1):
		_unlock_rings[i]["t"] = float(_unlock_rings[i]["t"]) + delta
		if float(_unlock_rings[i]["t"]) >= float(_unlock_rings[i]["dur"]):
			_unlock_rings.remove_at(i)

	# Calm breathing color pulse (emerald <-> warm gold) on "Can Buy Now" nodes
	if not _available_border_styles.is_empty():
		var breath := 0.5 + 0.5 * sin(_anim_time * 3.0)
		var pulse_col := Color(0.38, 0.82, 0.46, 1.0).lerp(Color(1.0, 0.88, 0.46, 1.0), breath)
		for st in _available_border_styles:
			if is_instance_valid(st):
				st.border_color = pulse_col

	if is_instance_valid(_path_drawer):
		_path_drawer.queue_redraw()
	if is_instance_valid(_fx_drawer):
		_fx_drawer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var is_upgrade_toggle: bool = event.is_action_pressed("toggle_upgrades") if InputMap.has_action("toggle_upgrades") else (event.keycode == KEY_U)
		if is_open:
			if event.keycode == KEY_ESCAPE or is_upgrade_toggle:
				get_viewport().set_input_as_handled()
				close_tree()
			return
		if is_upgrade_toggle:
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
	set_process(true)
	_hovered_id = ""
	_pending_levels.clear()
	_pending_delivery_items.clear()
	_path_surges.clear()
	_unlock_rings.clear()
	if is_instance_valid(_tooltip):
		_tooltip.visible = false

	EventBus.request_sfx.emit("tab_switch")
	_elevate_hud_money()
	_refresh_all()
	call_deferred("_play_open_cascade")


func _play_open_cascade() -> void:
	_layout_nodes()
	if is_instance_valid(_board_panel):
		_board_panel.modulate.a = 0.0
		var btw := create_tween()
		btw.tween_property(_board_panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var btn: Button = _node_buttons.get(nid)
		if not is_instance_valid(btn):
			continue
		var row_y := float(n["pos"].y)
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2(0.72, 0.72)
		btn.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(row_y * 0.035)
		tw.tween_property(btn, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(btn, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_tree() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	set_process(false)
	_hovered_id = ""
	if is_instance_valid(_tooltip):
		_tooltip.visible = false
	_restore_hud_money()
	Input.mouse_mode = _prev_mouse_mode
	EventBus.request_sfx.emit("drop")

	if not _pending_delivery_items.is_empty():
		var items_copy := _pending_delivery_items.duplicate()
		_pending_delivery_items.clear()
		_pending_levels.clear()
		if is_instance_valid(MarioManager):
			MarioManager.append_or_start_delivery(items_copy)
	else:
		_pending_levels.clear()


## Moves the main HUD's MoneyContainer into this overlay so the same counter shows on top of the menu.
func _elevate_hud_money() -> void:
	if is_instance_valid(_hud_money):
		return
	var m := get_tree().current_scene.get_node_or_null("CanvasLayer/LeftHUD/MoneyContainer") as Control
	if m == null:
		return
	_hud_money = m
	_hud_money_parent = m.get_parent()
	_hud_money_index = m.get_index()
	m.reparent(_root, true)
	if is_instance_valid(_tooltip):
		_root.move_child(m, _tooltip.get_index())


func _restore_hud_money() -> void:
	if not is_instance_valid(_hud_money):
		return
	if is_instance_valid(_hud_money_parent):
		_hud_money.reparent(_hud_money_parent, true)
		_hud_money_parent.move_child(_hud_money, mini(_hud_money_index, _hud_money_parent.get_child_count() - 1))
	_hud_money = null


func _exit_tree() -> void:
	_restore_hud_money()


func _get_money() -> float:
	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	return float(gm_nodes[0].money) if not gm_nodes.is_empty() else 0.0


func _node_center(lpos: Vector2) -> Vector2:
	if not is_instance_valid(_tree_area):
		return Vector2.ZERO
	var sz := _tree_area.size
	var usable_w := clampf(sz.x * 0.75, 240.0, 1100.0)
	var usable_h := clampf(sz.y * 0.78, 180.0, 580.0)
	var start_x := (sz.x - usable_w) * 0.5
	var start_y := (sz.y - usable_h) * 0.5 - 8.0
	# Logical x in [0 .. 9], logical y in [0 .. 4] (bottom-up)
	var nx := lpos.x / 9.0
	var ny := 1.0 - (lpos.y / 4.0)
	return Vector2(start_x + nx * usable_w, start_y + ny * usable_h)


func _refresh_all() -> void:
	var money := _get_money()
	if is_instance_valid(_money_lbl):
		_money_lbl.text = "%.2f" % money
	if is_instance_valid(_pending_lbl):
		var cnt := _pending_delivery_items.size()
		_pending_lbl.visible = cnt > 0
		_pending_lbl.text = "%d Queued · Mario delivers on close" % cnt

	_layout_nodes()
	if _hovered_id != "":
		_show_tooltip_for(_hovered_id)


func _layout_nodes() -> void:
	if not is_instance_valid(_tree_area) or _tree_area.size.x < 10.0:
		return
	_available_border_styles.clear()
	var money := _get_money()
	for n in Registry.get_all_nodes():
		var nid := str(n["id"])
		var btn: Button = _node_buttons.get(nid)
		if not is_instance_valid(btn):
			continue
		var sz := CAPSTONE_SIZE if (nid == "open_door" or nid == "store_tier") else ICON_SIZE
		var center := _node_center(n["pos"])
		btn.position = center - sz * 0.5
		btn.size = sz
		var ev := Registry.evaluate_node(nid, money, _pending_levels)
		_style_node_button(btn, n, ev, nid == _hovered_id)

	if is_instance_valid(_path_drawer):
		_path_drawer.queue_redraw()


func _style_node_button(btn: Button, _def: Dictionary, ev: Dictionary, hovered: bool) -> void:
	var state := str(ev["state"])
	var item: ItemData = ev.get("item")

	var bg := Color(0.14, 0.12, 0.10, 0.95)
	var border_col := Color(0.42, 0.32, 0.20, 0.75)
	var border_w := 2
	var icon_mod := Color.WHITE
	var badge_text := ""
	var badge_col := COL_CREAM

	match state:
		"maxed":
			bg = Color(0.24, 0.19, 0.11, 0.98)
			border_col = Color(0.92, 0.74, 0.34, 1.0)
			border_w = 3
		"available":
			bg = Color(0.16, 0.14, 0.115, 0.96)
			border_col = Color(0.46, 0.86, 0.50, 1.0)
			border_w = 3
		"available_poor":
			bg = Color(0.14, 0.12, 0.10, 0.92)
			border_col = Color(0.88, 0.44, 0.40, 0.90)
		_:
			bg = Color(0.09, 0.08, 0.07, 0.84)
			border_col = Color(0.32, 0.25, 0.18, 0.65)
			icon_mod = Color(0.48, 0.42, 0.36, 0.46)

	if hovered:
		border_col = Color(1.0, 0.88, 0.52, 1.0)
		border_w = 3

	var st := UIStyle.create_flat_stylebox(bg, 12, 4, 4)
	st.border_color = border_col
	st.set_border_width_all(border_w)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	st.shadow_size = 8

	var hov := st.duplicate()
	hov.bg_color = bg.lightened(0.06)
	hov.border_color = Color(1.0, 0.86, 0.44, 1.0)
	hov.set_border_width_all(3)

	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	if state == "available" and not hovered:
		_available_border_styles.append(st)

	var icon_tr := btn.get_node_or_null("Icon") as TextureRect
	if icon_tr:
		icon_tr.texture = item.texture if (item != null and item.texture != null) else null
		icon_tr.modulate = icon_mod

	var badge := btn.get_node_or_null("Badge") as Label
	if badge:
		badge.text = badge_text
		badge.visible = badge_text != ""
		badge.add_theme_color_override("font_color", badge_col)

	var lock_lbl := btn.get_node_or_null("CenterLock") as Label
	if lock_lbl:
		lock_lbl.visible = (state == "locked")

	# Compact under-node pill: "Paint" for owned Signage/Poster, or price tag for actionable nodes
	var pill := btn.get_node_or_null("SubPill") as PanelContainer
	if pill:
		var plbl := pill.get_node_or_null("Lbl") as Label
		var kind := str(_def.get("kind", ""))
		var sf_lvl := int(_def.get("storefront_level", 0))
		var can_paint := kind == "storefront_step" and (sf_lvl == 1 or sf_lvl == 2) and is_instance_valid(StoryManager) and StoryManager.storefront_upgrade_level >= sf_lvl
		var cost := float(ev.get("cost", 0.0))
		if can_paint:
			pill.visible = true
			if plbl:
				plbl.text = "Paint"
				plbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
			var pst: StyleBoxFlat = pill.get_theme_stylebox("panel") as StyleBoxFlat
			if pst:
				pst.border_color = COL_BRASS
		elif (state == "available" or state == "available_poor") and cost > 0.0:
			pill.visible = true
			if plbl:
				plbl.text = "₱%d" % int(roundf(cost))
				plbl.add_theme_color_override("font_color", COL_STAT_POS if state == "available" else COL_STAT_NEG)
			var pst: StyleBoxFlat = pill.get_theme_stylebox("panel") as StyleBoxFlat
			if pst:
				pst.border_color = Color(0.46, 0.86, 0.50, 0.78) if state == "available" else Color(0.88, 0.44, 0.40, 0.65)
		else:
			pill.visible = false


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
	if str(def["kind"]) == "tier_hub":
		_tip_level.text = "Tier %d/%d" % [cur_lvl, max_lvl]
	elif max_lvl > 1:
		_tip_level.text = "Lv.%d" % cur_lvl
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
		s_name.add_theme_font_size_override("font_size", 16)
		s_name.add_theme_color_override("font_color", COL_CREAM)
		s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_row.add_child(s_name)

		var s_val := Label.new()
		s_val.text = str(st.get("value", ""))
		s_val.add_theme_font_override("font", _bold_font)
		s_val.add_theme_font_size_override("font_size", 17)
		var tone := str(st.get("tone", "pos"))
		var val_col := COL_STAT_POS if tone == "pos" else (COL_STAT_NEG if tone == "neg" else COL_GOLD_BRIGHT)
		s_val.add_theme_color_override("font_color", val_col)
		s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_row.add_child(s_val)

	# Crisp 1-sentence description (stats below carry the exact numbers)
	var desc := Registry.get_short_description(node_id)
	if str(def["kind"]) == "tier_hub" and is_instance_valid(InventoryManager):
		var target_t := clampi(target_lvl, 2, 10)
		var names: Array[String] = []
		for ti in InventoryManager.get_all_items():
			if ti != null and ti.can_be_sold and ti.tier == target_t:
				names.append(ti.item_name)
				if names.size() >= 5:
					break
		if not names.is_empty():
			desc = "Unlocks: " + ", ".join(names)
		if target_t == 10:
			desc = (desc + "\nCandy containers will now be separated.") if desc != "" else "Candy containers will now be separated."
	_tip_desc.text = desc
	_tip_desc.visible = desc != ""

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
	_tooltip.modulate.a = 0.0
	_tooltip.reset_size()
	call_deferred("_position_tooltip_beside", node_id)


func _position_tooltip_beside(node_id: String) -> void:
	if not is_instance_valid(_tooltip) or not _tooltip.visible:
		return
	# Wrapped labels settle their height a frame later; shrink-wrap to the final height.
	_tooltip.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(_tooltip) or not _tooltip.visible or _hovered_id != node_id:
		return
	_tooltip.reset_size()
	_tooltip.modulate.a = 1.0
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
		if not StoryManager.can_edit_storefront_slot(slot):
			AudioManager.play_sfx("error")
			EventBus.show_notification.emit(
				"Signage Already Edited Today",
				"You can only edit your Roof Signage once per day. Come back tomorrow!",
				"error"
			)
			return
		close_tree()
		var ov := StorefrontCanvasOverlay.new()
		get_tree().root.add_child(ov)
		ov.open_editor(slot)
		return

	var money := _get_money()
	var ev := Registry.evaluate_node(node_id, money, _pending_levels)
	if not bool(ev["can_buy"]):
		AudioManager.play_sfx("error")
		_shake_node(node_id)
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
	_play_unlock_celebration(node_id, def)


func _shake_node(node_id: String) -> void:
	var btn: Button = _node_buttons.get(node_id)
	if not is_instance_valid(btn):
		return
	var def := Registry.get_node_def(node_id)
	if def.is_empty():
		return
	var sz := CAPSTONE_SIZE if (node_id == "open_door" or node_id == "store_tier") else ICON_SIZE
	var base_x := (_node_center(def["pos"]) - sz * 0.5).x
	var tw := create_tween()
	tw.tween_property(btn, "position:x", base_x - 6.0, 0.04)
	tw.tween_property(btn, "position:x", base_x + 6.0, 0.04)
	tw.tween_property(btn, "position:x", base_x - 4.0, 0.04)
	tw.tween_property(btn, "position:x", base_x, 0.05)


func _build_curve_between(parent_pt: Vector2, child_pt: Vector2) -> PackedVector2Array:
	if is_equal_approx(parent_pt.y, child_pt.y) or is_equal_approx(parent_pt.x, child_pt.x):
		return _sample_cubic_bezier(parent_pt, parent_pt.lerp(child_pt, 0.33), parent_pt.lerp(child_pt, 0.66), child_pt, 20)
	var dx := absf(child_pt.x - parent_pt.x)
	var dy := child_pt.y - parent_pt.y
	var lift := clampf(absf(dy) * 0.55 + dx * 0.08, 36.0, 190.0)
	var dir_y := -1.0 if dy < 0.0 else 1.0
	var c1 := Vector2(parent_pt.x, parent_pt.y + dir_y * lift)
	var c2 := Vector2(child_pt.x, child_pt.y - dir_y * lift)
	return _sample_cubic_bezier(parent_pt, c1, c2, child_pt, 24)


func _point_along_polyline(pts: PackedVector2Array, frac: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	if pts.size() == 1:
		return pts[0]
	var f := clampf(frac, 0.0, 1.0) * float(pts.size() - 1)
	var idx := clampi(int(floorf(f)), 0, pts.size() - 2)
	return pts[idx].lerp(pts[idx + 1], f - float(idx))


func _play_unlock_celebration(node_id: String, def: Dictionary) -> void:
	var btn: Button = _node_buttons.get(node_id)
	var center := _node_center(def["pos"])
	if is_instance_valid(btn):
		btn.pivot_offset = btn.size * 0.5
		btn.modulate = Color(1.55, 1.48, 1.22, 1.0)
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.26, 0.88), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 1.12), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08) if _hovered_id == node_id else Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var ftw := create_tween()
		ftw.tween_property(btn, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Expanding golden shockwave ring + dual sparkle shower
	var sz := CAPSTONE_SIZE if (node_id == "open_door" or node_id == "store_tier") else ICON_SIZE
	_unlock_rings.append({"center": center, "t": 0.0, "dur": 0.52, "base_r": sz.x * 0.48, "col": COL_GOLD_BRIGHT})
	if is_instance_valid(_tree_area):
		Juice.spawn_burst(_tree_area, center, COL_GOLD_BRIGHT, 16, 130.0)
		Juice.spawn_burst(_tree_area, center, COL_STAT_POS, 8, 95.0)

	# Race golden surge waves along incoming prerequisite lines AND outward toward newly available children
	for pre_id in def.get("prereqs", []):
		var pdef := Registry.get_node_def(str(pre_id))
		if not pdef.is_empty():
			_path_surges.append({"pts": _build_curve_between(_node_center(pdef["pos"]), center), "t": 0.0, "dur": 0.42})

	var money := _get_money()
	for child_def in Registry.get_all_nodes():
		if node_id in child_def.get("prereqs", []):
			var cid := str(child_def["id"])
			var cev := Registry.evaluate_node(cid, money, _pending_levels)
			if str(cev["state"]).begins_with("available"):
				_path_surges.append({"pts": _build_curve_between(center, _node_center(child_def["pos"])), "t": 0.0, "dur": 0.48})
				var cbtn: Button = _node_buttons.get(cid)
				if is_instance_valid(cbtn):
					cbtn.pivot_offset = cbtn.size * 0.5
					var ctw := create_tween()
					ctw.tween_interval(0.18)
					ctw.tween_property(cbtn, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					ctw.tween_property(cbtn, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _sample_cubic_bezier(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, steps: int = 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(steps + 1)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		pts[i] = (u * u * u) * p0 + (3.0 * u * u * t) * c1 + (3.0 * u * t * t) * c2 + (t * t * t) * p3
	return pts


func _draw_paths() -> void:
	if not is_instance_valid(_path_drawer):
		return
	var money := _get_money()
	var pulse := 0.5 + 0.5 * sin(_anim_time * 3.2)

	# Connector lines + soft glow + flowing energy beads tracing along active paths
	var path_idx := 0
	for n in Registry.get_all_nodes():
		var child_id := str(n["id"])
		var child_pt := _node_center(n["pos"])
		var child_unlocked := Registry.is_node_unlocked_in_tree(child_id, _pending_levels)
		var child_ev := Registry.evaluate_node(child_id, money, _pending_levels)
		var child_avail := str(child_ev["state"]).begins_with("available")

		for pre_id in n.get("prereqs", []):
			var pre_str := str(pre_id)
			var pdef := Registry.get_node_def(pre_str)
			if pdef.is_empty():
				continue
			path_idx += 1
			var parent_pt := _node_center(pdef["pos"])
			var parent_unlocked := Registry.is_node_unlocked_in_tree(pre_str, _pending_levels)
			var pts := _build_curve_between(parent_pt, child_pt)

			var is_lit := parent_unlocked and child_unlocked
			var is_avail_edge := parent_unlocked and child_avail
			var is_hovered_edge := (_hovered_id != "" and (_hovered_id == child_id or _hovered_id == pre_str))
			var dim_mult := 0.24 if (_hovered_id != "" and not is_hovered_edge) else 1.0

			var fill_col := COL_PATH_LOCKED
			if is_lit:
				fill_col = COL_PATH_LIT.lightened(0.16 if is_hovered_edge else 0.0)
			elif is_avail_edge:
				fill_col = COL_PATH_AVAIL.lightened(0.18 if is_hovered_edge else 0.0)
			elif is_hovered_edge:
				fill_col = Color(0.76, 0.62, 0.40, 0.92)
			fill_col.a *= dim_mult

			if is_lit or is_avail_edge or is_hovered_edge:
				var glow_alpha := ((0.24 if is_lit else (0.18 if is_avail_edge else 0.14)) + pulse * 0.08 + (0.18 if is_hovered_edge else 0.0)) * dim_mult
				_path_drawer.draw_polyline(pts, Color(fill_col.r, fill_col.g, fill_col.b, glow_alpha), 13.0 if is_hovered_edge else 12.0, true)

			var out_col := Color(COL_PATH_OUTLINE.r, COL_PATH_OUTLINE.g, COL_PATH_OUTLINE.b, COL_PATH_OUTLINE.a * dim_mult)
			_path_drawer.draw_polyline(pts, out_col, 7.5, true)
			_path_drawer.draw_polyline(pts, fill_col, 4.4 if is_hovered_edge else (3.8 if (is_lit or is_avail_edge) else 3.0), true)

			# Travelling light bead tracing upward along unlocked & available branches
			if is_lit or is_avail_edge:
				var speed := 0.42 if is_lit else 0.30
				var phase := fmod(_anim_time * speed + float(path_idx) * 0.19, 1.0)
				var bead_pt := _point_along_polyline(pts, phase)
				var bead_col := Color(1.0, 0.94, 0.68, 0.92) if is_lit else Color(0.72, 1.0, 0.76, 0.88)
				var fade_ends := sin(phase * PI) * dim_mult
				_path_drawer.draw_circle(bead_pt, 6.5, Color(bead_col.r, bead_col.g, bead_col.b, 0.28 * fade_ends))
				_path_drawer.draw_circle(bead_pt, 3.2, Color(bead_col.r, bead_col.g, bead_col.b, 0.95 * fade_ends))


func _draw_fx() -> void:
	if not is_instance_valid(_fx_drawer):
		return
	# Unlock surge waves racing along curves
	for s in _path_surges:
		var prog := clampf(float(s["t"]) / maxf(0.01, float(s["dur"])), 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - prog, 2.2)
		var pts: PackedVector2Array = s["pts"]
		var head := _point_along_polyline(pts, eased)
		var tail := _point_along_polyline(pts, maxf(0.0, eased - 0.18))
		var alpha := 1.0 - prog
		_fx_drawer.draw_line(tail, head, Color(1.0, 0.92, 0.58, 0.65 * alpha), 7.0, true)
		_fx_drawer.draw_circle(head, 9.0, Color(1.0, 0.95, 0.70, 0.42 * alpha))
		_fx_drawer.draw_circle(head, 4.5, Color(1.0, 1.0, 0.92, 0.98 * alpha))

	# Unlock expanding shockwave rings
	for r in _unlock_rings:
		var prog := clampf(float(r["t"]) / maxf(0.01, float(r["dur"])), 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - prog, 3.0)
		var radius := float(r["base_r"]) * lerpf(0.85, 2.15, eased)
		var col: Color = r["col"]
		var alpha := (1.0 - prog) * 0.85
		_fx_drawer.draw_arc(r["center"], radius, 0.0, TAU, 40, Color(col.r, col.g, col.b, alpha), lerpf(4.5, 1.2, prog), true)


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

	# Borderless dark semi-transparent warm espresso canvas (matches RestockMenu philosophy)
	_board_panel = PanelContainer.new()
	_board_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_panel.offset_left = 0.0
	_board_panel.offset_right = 0.0
	_board_panel.offset_top = 0.0
	_board_panel.offset_bottom = 0.0
	var canvas_st := UIStyle.create_flat_stylebox(Color(0.052, 0.044, 0.038, 0.90), 0, 36, 26)
	canvas_st.set_border_width_all(0)
	_board_panel.add_theme_stylebox_override("panel", canvas_st)
	_root.add_child(_board_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_board_panel.add_child(vbox)

	# Clean floating top bar: Elevated HUD Money on LEFT, Store Upgrades + 48x48 Close on RIGHT
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vbox.add_child(top)
	top.custom_minimum_size = Vector2(0, 56)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	_pending_lbl = Label.new()
	_pending_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pending_lbl.add_theme_font_override("font", _bold_font)
	_pending_lbl.add_theme_font_size_override("font_size", 16)
	_pending_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_pending_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_pending_lbl.add_theme_constant_override("outline_size", 3)
	top.add_child(_pending_lbl)

	var title := Label.new()
	title.text = "Store Upgrades"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_CREAM)
	title.add_theme_color_override("font_outline_color", COL_OUTLINE)
	title.add_theme_constant_override("outline_size", 4)
	top.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Close [U / Esc]"
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", _bold_font)
	close_btn.add_theme_font_size_override("font_size", 20)
	var cb_n := UIStyle.create_flat_stylebox(Color(0.22, 0.14, 0.13, 0.95), 10, 8, 8)
	cb_n.border_color = COL_STAT_NEG
	cb_n.set_border_width_all(1)
	var cb_h: StyleBoxFlat = cb_n.duplicate()
	cb_h.bg_color = Color(0.32, 0.18, 0.16, 1.0)
	cb_h.border_color = COL_STAT_NEG.lightened(0.18)
	close_btn.add_theme_stylebox_override("normal", cb_n)
	close_btn.add_theme_stylebox_override("hover", cb_h)
	close_btn.add_theme_stylebox_override("pressed", cb_n)
	close_btn.add_theme_color_override("font_color", COL_CREAM)
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.pressed.connect(close_tree)
	top.add_child(close_btn)

	# Seamless tree area directly on the warm parchment canvas
	_tree_area = Control.new()
	_tree_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_area.resized.connect(_layout_nodes)
	vbox.add_child(_tree_area)

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

	_fx_drawer = Control.new()
	_fx_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_drawer.z_index = 15
	_fx_drawer.draw.connect(_draw_fx)
	_tree_area.add_child(_fx_drawer)

	# Floating tooltip (warm espresso + brass border, restored description + Event-Card stats + Peso price)
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.z_index = 40
	_tooltip.custom_minimum_size = Vector2(380, 0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tst := UIStyle.create_flat_stylebox(Color(0.06, 0.05, 0.042, 0.96), 10, 20, 14)
	tst.border_color = COL_BRASS
	tst.set_border_width_all(2)
	tst.shadow_color = Color(0, 0, 0, 0.55)
	tst.shadow_size = 12
	_tooltip.add_theme_stylebox_override("panel", tst)
	_root.add_child(_tooltip)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(tv)

	var thead := HBoxContainer.new()
	thead.add_theme_constant_override("separation", 10)
	thead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(thead)

	_tip_title = Label.new()
	_tip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_title.add_theme_font_override("font", _bold_font)
	_tip_title.add_theme_font_size_override("font_size", 22)
	_tip_title.add_theme_color_override("font_color", COL_CREAM)
	_tip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thead.add_child(_tip_title)

	_tip_level = Label.new()
	_tip_level.add_theme_font_override("font", _bold_font)
	_tip_level.add_theme_font_size_override("font_size", 15)
	_tip_level.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_tip_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thead.add_child(_tip_level)

	_tip_desc = Label.new()
	_tip_desc.custom_minimum_size = Vector2(340, 0)
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.add_theme_font_override("font", UIStyle.FONT_INDER)
	_tip_desc.add_theme_font_size_override("font_size", 17)
	_tip_desc.add_theme_color_override("font_color", Color(0.86, 0.80, 0.70))
	_tip_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_desc)

	_tip_stats_box = VBoxContainer.new()
	_tip_stats_box.add_theme_constant_override("separation", 4)
	_tip_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_stats_box)

	_tip_price_row = HBoxContainer.new()
	_tip_price_row.add_theme_constant_override("separation", 6)
	_tip_price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_price_row)

	var peso_tip := TextureRect.new()
	peso_tip.texture = PESO_ICON_TEX
	peso_tip.custom_minimum_size = Vector2(24, 24)
	peso_tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	peso_tip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	peso_tip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	peso_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_price_row.add_child(peso_tip)

	_tip_price_lbl = Label.new()
	_tip_price_lbl.add_theme_font_override("font", _bold_font)
	_tip_price_lbl.add_theme_font_size_override("font_size", 22)
	_tip_price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_price_row.add_child(_tip_price_lbl)

	_tip_status = Label.new()
	_tip_status.add_theme_font_override("font", _bold_font)
	_tip_status.add_theme_font_size_override("font_size", 15)
	_tip_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_status.custom_minimum_size = Vector2(340, 0)
	_tip_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	var lock_lbl := Label.new()
	lock_lbl.name = "CenterLock"
	lock_lbl.text = "🔒"
	lock_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_size_override("font_size", 28)
	lock_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84, 0.96))
	lock_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.09, 0.05, 0.92))
	lock_lbl.add_theme_constant_override("outline_size", 6)
	lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_lbl.visible = false
	btn.add_child(lock_lbl)

	# Compact under-node pill (Price tag for actionable nodes, or "Paint" for owned Signage/Poster)
	var pill := PanelContainer.new()
	pill.name = "SubPill"
	pill.visible = false
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.anchor_top = 1.0
	pill.anchor_bottom = 1.0
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = 4.0
	var pst := UIStyle.create_flat_stylebox(Color(0.068, 0.058, 0.050, 0.94), 6, 7, 1)
	pst.border_color = COL_BRASS
	pst.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", pst)
	btn.add_child(pill)

	var plbl := Label.new()
	plbl.name = "Lbl"
	plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plbl.add_theme_font_override("font", _bold_font)
	plbl.add_theme_font_size_override("font_size", 12)
	plbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(plbl)

	btn.mouse_entered.connect(func():
		_hovered_id = node_id
		Juice.play_sfx("ui_hover", 1.12, -6.0)
		_tween_node_hover(node_id, btn, true)
		_layout_nodes()
		_show_tooltip_for(node_id)
	)
	btn.mouse_exited.connect(func():
		_tween_node_hover(node_id, btn, false)
		if _hovered_id == node_id:
			_hovered_id = ""
			if is_instance_valid(_tooltip):
				_tooltip.visible = false
			_layout_nodes()
	)
	btn.pressed.connect(func(): _on_node_pressed(node_id))
	return btn


func _tween_node_hover(node_id: String, btn: Button, hovered: bool) -> void:
	if not is_instance_valid(btn):
		return
	var prev: Tween = _hover_tweens.get(node_id)
	if prev and prev.is_valid():
		prev.kill()
	btn.pivot_offset = btn.size * 0.5
	var tw := create_tween()
	var target_s := Vector2(1.09, 1.09) if hovered else Vector2.ONE
	tw.tween_property(btn, "scale", target_s, 0.14).set_trans(Tween.TRANS_BACK if hovered else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tweens[node_id] = tw
