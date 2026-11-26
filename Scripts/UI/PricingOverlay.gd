extends Node3D

## Alt Lens 3D World Pricing Overlay.
## Floating Price Tag in Sari-Saring Katha's Dark Warm Espresso + Antique Gold + Fredoka
## visual language: inline Tier prefix (T1..T4) + item name + compact status icons inside
## the main tag, smart safe-ceiling tolerance gauge, profit delta with status readout below,
## and icon-backed right-side tooltips for In Demand, Frozen/Chilled/Warm, and active buffs.

const COL_ESPRESSO := Color(0.058, 0.050, 0.043, 0.96)
const COL_ESPRESSO_CARD := Color(0.068, 0.058, 0.050, 0.95)
const COL_GOLD := Color(0.835, 0.624, 0.278, 0.90)
const COL_GOLD_SOFT := Color(0.98, 0.87, 0.54, 1.0)
const COL_CREAM := Color(1.0, 0.94, 0.83, 1.0)
const COL_CREAM_MUTED := Color(0.84, 0.77, 0.66, 0.88)
const COL_DISCOUNT := Color(0.50, 0.88, 0.58, 1.0)
const COL_RISKY := Color(0.98, 0.64, 0.26, 1.0)
const COL_DANGER := Color(0.96, 0.42, 0.34, 1.0)
const COL_WARM := Color(1.0, 0.56, 0.34, 1.0)
const COL_CHILLED := Color(0.48, 0.88, 1.0, 1.0)

const ICON_IN_DEMAND := "res://Assets/ui/icons/sparkles.png"
const ICON_FROZEN := "res://Assets/ui/icons/snowflake.png"
const ICON_WARM := "res://Assets/ui/icons/thermometer-sun.png"
const ICON_VISITOR := "res://Assets/ui/icons/user-round-exclamation-point.png"

const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

## Vertical offset (in SubViewport pixels) lifting the floating tag cleanly above the crosshair
const TAG_LIFT_Y := 154.0


class TagPointer extends Control:
	func _draw() -> void:
		var cx := size.x * 0.5
		var top_y := 0.0
		var tip_y := size.y - 5.0
		var half_w := 12.0
		var tri := PackedVector2Array([
			Vector2(cx - half_w, top_y),
			Vector2(cx + half_w, top_y),
			Vector2(cx, tip_y),
		])
		draw_colored_polygon(tri, COL_ESPRESSO)
		draw_polyline(PackedVector2Array([
			Vector2(cx - half_w, top_y),
			Vector2(cx, tip_y),
			Vector2(cx + half_w, top_y),
		]), COL_GOLD, 2.0, true)
		var d := 3.2
		var tip := Vector2(cx, tip_y + 1.0)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(0.0, -d),
			tip + Vector2(d, 0.0),
			tip + Vector2(0.0, d),
			tip + Vector2(-d, 0.0),
		]), COL_GOLD_SOFT)


class PriceStepGauge extends Control:
	var step: int = 0
	var min_step: int = ItemData.MIN_STEP
	var max_step: int = ItemData.MAX_STEP
	var safe_max_step: int = 2
	var accent_color: Color = Color(0.98, 0.87, 0.54, 1.0)

	func _draw_diamond(center: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
		])
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var pad_x := 12.0
		var bar_h := 24.0
		var bar_y := (size.y - bar_h) * 0.5 + 1.0
		var bar_w := maxf(20.0, size.x - pad_x * 2.0)
		var bar_rect := Rect2(pad_x, bar_y, bar_w, bar_h)
		var span := float(max_step - min_step)
		if span <= 0.0:
			return

		var zero_t := float(0 - min_step) / span
		var step_t := clampf(float(step - min_step) / span, 0.0, 1.0)
		var safe_t := clampf(float(clampi(safe_max_step, min_step, max_step) - min_step) / span, 0.0, 1.0)
		var zero_x := pad_x + zero_t * bar_w
		var cur_x := pad_x + step_t * bar_w
		var safe_x := pad_x + safe_t * bar_w

		# Deep obsidian recessed track
		draw_rect(bar_rect, Color(0.032, 0.027, 0.023, 0.98), true)

		# Subtle safe-zone ceiling guide band along the top interior from wholesale (0) to safe max
		if safe_x > zero_x + 2.0:
			draw_rect(Rect2(zero_x, bar_y + 2.0, safe_x - zero_x, 3.0), Color(0.96, 0.84, 0.44, 0.30), true)

		# Subtle step ruler notches (-5 .. +5)
		for i in range(min_step + 1, max_step):
			var nt := float(i - min_step) / span
			var nx := pad_x + nt * bar_w
			var is_zero := (i == 0)
			var tick_col := Color(0.96, 0.86, 0.58, 0.62) if is_zero else Color(1.0, 0.92, 0.78, 0.14)
			var y_inset := 1.0 if is_zero else 5.0
			draw_line(Vector2(nx, bar_y + y_inset), Vector2(nx, bar_y + bar_h - y_inset), tick_col, 1.8 if is_zero else 1.0, true)

		# Bidirectional fill from center (0) to current step
		var inset := 2.0
		if absf(cur_x - zero_x) > 1.0:
			var x0 := minf(zero_x, cur_x)
			var x1 := maxf(zero_x, cur_x)
			var fill_rect := Rect2(x0, bar_y + inset, x1 - x0, bar_h - inset * 2.0)
			draw_rect(fill_rect, accent_color, true)
			draw_rect(Rect2(x0, bar_y + inset, x1 - x0, 5.0), Color(1.0, 0.96, 0.84, 0.25), true)

		# Antique-gold outer frame + crisp dark inner bevel
		var frame_col := Color(0.835, 0.624, 0.278, 0.86)
		draw_rect(bar_rect, frame_col, false, 2.0)
		draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)

		# Safe-zone ceiling notch (exact safe max step including active tolerance bonuses)
		var ceil_col := Color(1.0, 0.88, 0.50, 0.92)
		draw_line(Vector2(safe_x, bar_y - 4.0), Vector2(safe_x, bar_y + bar_h + 1.0), ceil_col, 2.0, true)
		_draw_diamond(Vector2(safe_x, bar_y - 5.5), 3.4, ceil_col)

		# End-cap diamond ornaments (left & right)
		_draw_diamond(Vector2(pad_x, bar_y + bar_h * 0.5), 4.8, frame_col)
		_draw_diamond(Vector2(pad_x + bar_w, bar_y + bar_h * 0.5), 4.8, frame_col)

		# Center wholesale diamond marker below track
		_draw_diamond(Vector2(zero_x, bar_y + bar_h + 6.5), 3.2, Color(0.86, 0.72, 0.42, 0.76))

		# Glowing diamond thumb at active step
		var thumb_c := Vector2(cur_x, bar_y + bar_h * 0.5)
		_draw_diamond(thumb_c, 11.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.28))
		_draw_diamond(thumb_c, 8.0, Color(0.05, 0.04, 0.035, 0.96))
		_draw_diamond(thumb_c, 5.6, accent_color.lightened(0.24))


var pricing_ui: Sprite3D
var pricing_viewport: SubViewport
var _tag_stack: VBoxContainer
var pricing_panel: PanelContainer
var tier_label: Label
var name_label: Label
var _in_demand_icon: TextureRect
var _temp_icon: TextureRect
var price_label: Label
var comparison_label: Label
var status_label: Label
var stock_label: Label
var left_arrow: Label
var right_arrow: Label
var _gauge: PriceStepGauge
var _tolerance_col: VBoxContainer

var _current_item: ItemData
var _last_step: int = -999
var _last_basis_pos: Vector3 = Vector3.ZERO
var _last_is_container: bool = false
var _last_custom_name: String = ""
var _last_stock_text: String = ""
var _last_warm_state: bool = false
var _juice_tween: Tween = null


func _ready() -> void:
	name = "PricingOverlay"
	add_to_group("pricing_overlay")

	pricing_viewport = SubViewport.new()
	pricing_viewport.transparent_bg = true
	pricing_viewport.size = Vector2(1600, 820)
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(pricing_viewport)

	# Full-rect root so main price tag stays locked horizontally centered even as tooltips appear on the right
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pricing_viewport.add_child(root_ctrl)

	# Elevated floating Price Tag + downward anchor pointer (sits cleanly above the crosshair)
	_tag_stack = VBoxContainer.new()
	_tag_stack.anchor_left = 0.5
	_tag_stack.anchor_right = 0.5
	_tag_stack.anchor_top = 0.5
	_tag_stack.anchor_bottom = 0.5
	_tag_stack.offset_left = -225.0
	_tag_stack.offset_right = 225.0
	_tag_stack.offset_top = -TAG_LIFT_Y - 140.0
	_tag_stack.offset_bottom = -TAG_LIFT_Y + 135.0
	_tag_stack.alignment = BoxContainer.ALIGNMENT_END
	_tag_stack.add_theme_constant_override("separation", 0)
	root_ctrl.add_child(_tag_stack)

	pricing_panel = PanelContainer.new()
	pricing_panel.custom_minimum_size = Vector2(450, 236)
	var style := StyleBoxFlat.new()
	style.bg_color = COL_ESPRESSO
	style.set_corner_radius_all(12)
	style.border_color = COL_GOLD
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_size = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	pricing_panel.add_theme_stylebox_override("panel", style)
	_tag_stack.add_child(pricing_panel)

	var pointer := TagPointer.new()
	pointer.custom_minimum_size = Vector2(36, 16)
	pointer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tag_stack.add_child(pointer)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	pricing_panel.add_child(vbox)

	# Header Row: inline Tier prefix (T1..T4, same size as name) + Item Name + compact icon-only badges
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 10)
	vbox.add_child(header_row)

	tier_label = Label.new()
	tier_label.text = "T1"
	tier_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	tier_label.add_theme_font_size_override("font_size", 32)
	tier_label.add_theme_color_override("font_color", UIStyle.get_tier_color(1))
	header_row.add_child(tier_label)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", COL_CREAM)
	header_row.add_child(name_label)

	_in_demand_icon = _make_status_icon(ICON_IN_DEMAND, COL_GOLD_SOFT, 26.0)
	_in_demand_icon.hide()
	header_row.add_child(_in_demand_icon)

	_temp_icon = _make_status_icon(ICON_FROZEN, COL_CHILLED, 26.0)
	_temp_icon.hide()
	header_row.add_child(_temp_icon)

	# Hero Price Row with nudging chevrons
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	vbox.add_child(hbox)

	left_arrow = Label.new()
	left_arrow.text = "‹"
	left_arrow.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	left_arrow.add_theme_font_size_override("font_size", 42)
	left_arrow.add_theme_color_override("font_color", COL_GOLD_SOFT)
	left_arrow.pivot_offset = Vector2(10, 24)
	hbox.add_child(left_arrow)

	price_label = Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	price_label.add_theme_font_size_override("font_size", 50)
	price_label.add_theme_color_override("font_color", COL_GOLD_SOFT)
	price_label.add_theme_constant_override("outline_size", 3)
	price_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 0.95))
	hbox.add_child(price_label)

	right_arrow = Label.new()
	right_arrow.text = "›"
	right_arrow.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	right_arrow.add_theme_font_size_override("font_size", 42)
	right_arrow.add_theme_color_override("font_color", COL_GOLD_SOFT)
	right_arrow.pivot_offset = Vector2(10, 24)
	hbox.add_child(right_arrow)

	# Smart Tolerance Gauge (-5 .. 0 .. +5 with safe-max ceiling marker)
	_gauge = PriceStepGauge.new()
	_gauge.custom_minimum_size = Vector2(348, 40)
	_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_gauge)

	# Line 1 under gauge: Profit Delta (+₱19.50) + optional Stock readout
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 14)
	vbox.add_child(foot)

	comparison_label = Label.new()
	comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comparison_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	comparison_label.add_theme_font_size_override("font_size", 24)
	comparison_label.add_theme_color_override("font_color", COL_CREAM_MUTED)
	foot.add_child(comparison_label)

	stock_label = Label.new()
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	stock_label.add_theme_font_size_override("font_size", 22)
	stock_label.add_theme_color_override("font_color", COL_DISCOUNT)
	foot.add_child(stock_label)

	# Line 2 under profit delta: Status descriptor (Sweet Spot, Safe, Risky, Overpriced, etc.)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.add_theme_color_override("font_color", COL_GOLD_SOFT)
	vbox.add_child(status_label)

	# Right-side modernized tooltips (vertically aligned with the elevated tag)
	_tolerance_col = VBoxContainer.new()
	_tolerance_col.anchor_left = 0.5
	_tolerance_col.anchor_right = 0.5
	_tolerance_col.anchor_top = 0.5
	_tolerance_col.anchor_bottom = 0.5
	_tolerance_col.offset_left = 242.0
	_tolerance_col.offset_right = 640.0
	_tolerance_col.offset_top = -TAG_LIFT_Y - 210.0
	_tolerance_col.offset_bottom = -TAG_LIFT_Y + 190.0
	_tolerance_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_tolerance_col.add_theme_constant_override("separation", 10)
	_tolerance_col.hide()
	root_ctrl.add_child(_tolerance_col)

	pricing_ui = Sprite3D.new()
	pricing_ui.texture = pricing_viewport.get_texture()
	pricing_ui.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pricing_ui.no_depth_test = true
	pricing_ui.fixed_size = true
	pricing_ui.pixel_size = 0.00095
	pricing_ui.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	pricing_ui.transparent = true
	pricing_ui.shaded = false
	pricing_ui.render_priority = 100
	add_child(pricing_ui)

	EventBus.fridge_coldness_changed.connect(_on_fridge_coldness_changed)
	hide_ui()


func _make_status_icon(icon_path: String, tint: Color, px: float = 24.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = HadesEmblem.load_lucide_icon(icon_path)
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = tint
	return tr


func _add_effect_tooltip(source_name: String, stats: Array, source_kind: String = "favor", icon_path: String = "") -> void:
	if stats.is_empty():
		return

	var accent_col := COL_GOLD
	var title_col := COL_GOLD_SOFT
	match source_kind:
		"event":
			var pal: Dictionary = HadesEmblem.palette("event")
			accent_col = pal["accent"]
			title_col = pal["bright"]
		"omen":
			var pal: Dictionary = HadesEmblem.palette("omen")
			accent_col = pal["accent"]
			title_col = pal["bright"]
		"blessing":
			var pal: Dictionary = HadesEmblem.palette("blessing")
			accent_col = pal["accent"]
			title_col = pal["bright"]
		"chilled":
			accent_col = COL_CHILLED
			title_col = COL_CHILLED
		"warm":
			accent_col = COL_WARM
			title_col = COL_WARM
		"customer":
			accent_col = COL_CREAM
			title_col = COL_CREAM
		_:
			var pal: Dictionary = HadesEmblem.palette("favor")
			accent_col = pal["accent"]
			title_col = pal["bright"]

	var card := PanelContainer.new()
	var st_box := UIStyle.create_flat_stylebox(COL_ESPRESSO_CARD, 10, 18, 12)
	st_box.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.85)
	st_box.border_width_left = 4
	st_box.border_width_top = 1
	st_box.border_width_right = 1
	st_box.border_width_bottom = 1
	st_box.shadow_size = 8
	st_box.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	card.add_theme_stylebox_override("panel", st_box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	card.add_child(vb)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 9)
	vb.add_child(title_row)

	if icon_path != "":
		var ico := _make_status_icon(icon_path, title_col, 24.0)
		if ico.texture != null:
			title_row.add_child(ico)

	var title_lbl := Label.new()
	title_lbl.text = source_name
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	title_lbl.add_theme_font_size_override("font_size", 25)
	title_lbl.add_theme_color_override("font_color", title_col)
	title_row.add_child(title_lbl)

	for st in stats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vb.add_child(row)

		var lbl := Label.new()
		lbl.text = "▸ " + str(st.get("label", ""))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		lbl.add_theme_font_size_override("font_size", 21)
		lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		row.add_child(lbl)

		var val := Label.new()
		val.text = str(st.get("value", ""))
		val.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		val.add_theme_font_size_override("font_size", 22)
		var tone := str(st.get("tone", "pos"))
		var val_col := COL_DISCOUNT if tone == "pos" else (COL_DANGER if tone == "neg" else COL_GOLD_SOFT)
		val.add_theme_color_override("font_color", val_col)
		row.add_child(val)

	_tolerance_col.add_child(card)


func _rebuild_tolerance_tooltips(item_data: ItemData, is_fridge_item: bool, is_warm_now: bool, in_demand: bool) -> int:
	for ch in _tolerance_col.get_children():
		ch.queue_free()

	var total_tol := 0
	var count := 0

	# 0. Item State Tooltips (In Demand, Frozen / Chilled, Warm -25%) with their Lucide icons
	if in_demand:
		_add_effect_tooltip("In Demand", [
			{"label": "Customer Interest", "value": "High", "tone": "gold"},
		], "favor", ICON_IN_DEMAND)
		count += 1

	if is_fridge_item:
		if is_warm_now:
			_add_effect_tooltip("Warm", [
				{"label": "Sale Value", "value": "-25%", "tone": "neg"},
			], "warm", ICON_WARM)
			count += 1
		else:
			var cold_title := "Frozen" if item_data.category == "frozen" else "Chilled"
			_add_effect_tooltip(cold_title, [
				{"label": "Condition", "value": "Fresh", "tone": "pos"},
			], "chilled", ICON_FROZEN)
			count += 1

	# 1. Active Neighborhood Events (ONLY radio-revealed events — never spoil unrevealed broadcasts!)
	if is_instance_valid(StoreEventManager):
		var best_targeted_val := 0
		for ev in StoreEventManager.get_active_events():
			if ev == null:
				continue
			var ev_stats: Array[Dictionary] = []
			var affects := ev.affects_item(item_data)
			var combined_tol := 0
			if affects and ev.tolerance_offset != 0:
				combined_tol += ev.tolerance_offset
				best_targeted_val = maxi(best_targeted_val, ev.tolerance_offset)
			if ev.global_tolerance_offset != 0:
				combined_tol += ev.global_tolerance_offset
				total_tol += ev.global_tolerance_offset
			if combined_tol != 0:
				ev_stats.append({
					"label": "Price Tolerance",
					"value": "%+d" % combined_tol,
					"tone": "pos" if combined_tol > 0 else "neg",
				})
			if affects:
				var demand_pct := int(roundf((ev.demand_multiplier - 1.0) * 100.0))
				if demand_pct != 0:
					ev_stats.append({
						"label": "Item Demand",
						"value": "%+d%%" % demand_pct,
						"tone": "pos" if demand_pct > 0 else "neg",
					})
			if ev.tip_bonus_pct > 0.001:
				ev_stats.append({
					"label": "Sale Tip Bonus",
					"value": "+%d%%" % int(roundf(ev.tip_bonus_pct * 100.0)),
					"tone": "pos",
				})
			if not is_equal_approx(ev.xp_multiplier, 1.0):
				var xp_pct := int(roundf((ev.xp_multiplier - 1.0) * 100.0))
				if xp_pct != 0:
					ev_stats.append({
						"label": "Sale XP Gain",
						"value": "%+d%%" % xp_pct,
						"tone": "pos" if xp_pct > 0 else "neg",
					})
			if not is_equal_approx(ev.restock_cost_multiplier, 1.0):
				var cost_pct := int(roundf((ev.restock_cost_multiplier - 1.0) * 100.0))
				if cost_pct != 0:
					ev_stats.append({
						"label": "Restock Cost",
						"value": "%+d%%" % cost_pct,
						"tone": "pos" if cost_pct < 0 else "neg",
					})
			if item_data.type == ItemData.ItemType.FRIDGE and not is_equal_approx(ev.fridge_drain_multiplier, 1.0):
				var drain_pct := int(roundf((ev.fridge_drain_multiplier - 1.0) * 100.0))
				if drain_pct != 0:
					ev_stats.append({
						"label": "Fridge Drain",
						"value": "%+d%%" % drain_pct,
						"tone": "pos" if drain_pct < 0 else "neg",
					})
			if not ev_stats.is_empty():
				_add_effect_tooltip(ev.event_name, ev_stats, "event", ev.get_icon_path())
				count += 1
		total_tol += best_targeted_val

	# 2. Active Mayari Moon Cards & Sto. Niño Blessings (stack separately)
	if is_instance_valid(StoryManager):
		var has_mayari_silver := (
			StoryManager.active_mayari_card == MayariCardRegistry.CARD_SILVER_TOLERANCE
			or (MayariCardRegistry.CARD_SILVER_TOLERANCE in StoryManager.active_mayari_cards)
		)
		if has_mayari_silver:
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_SILVER_TOLERANCE).get("icon", ""))
			_add_effect_tooltip("Silver Tolerance", [{"label": "Price Tolerance", "value": "+1", "tone": "pos"}], "favor", c_ico)
			total_tol += 1
			count += 1
		if MayariCardRegistry.CARD_SILVER_TOLERANCE in StoryManager.active_blessing_cards:
			var b_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_SILVER_TOLERANCE).get("icon", ""))
			_add_effect_tooltip("Sto. Niño Blessing", [{"label": "Price Tolerance", "value": "+1", "tone": "pos"}], "blessing", b_ico)
			total_tol += 1
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH):
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH).get("icon", ""))
			_add_effect_tooltip("Eerie Mist Rush", [{"label": "Price Tolerance", "value": "-1", "tone": "neg"}], "omen", c_ico)
			total_tol -= 1
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_RELUCTANT_CARE).get("icon", ""))
			_add_effect_tooltip("Reluctant Care", [{"label": "Price Tolerance", "value": "-1", "tone": "neg"}], "omen", c_ico)
			total_tol -= 1
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_RESTLESS_CROWD).get("icon", ""))
			_add_effect_tooltip("Restless Crowd", [
				{"label": "Price Tolerance", "value": "-1", "tone": "neg"},
				{"label": "Sale Bonus (≤ +1)", "value": "+15%", "tone": "pos"},
			], "omen", c_ico)
			total_tol -= 1
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_DISEMBODIED_WIND) and (item_data.category == "bottle" or item_data.category == "frozen"):
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_DISEMBODIED_WIND).get("icon", ""))
			var dw_stats: Array[Dictionary] = []
			if not StoryManager.is_fridge_warm:
				dw_stats.append({"label": "Cold Sale Bonus", "value": "+12%", "tone": "pos"})
			dw_stats.append({"label": "Fridge Drain", "value": "+40%", "tone": "neg"})
			_add_effect_tooltip("Disembodied Wind", dw_stats, "omen", c_ico)
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_MOONLIGHT_TIPS):
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_MOONLIGHT_TIPS).get("icon", ""))
			_add_effect_tooltip("Moonlight Tips", [{"label": "Tip Bonus", "value": "+12%", "tone": "pos"}], "favor", c_ico)
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_FADING_MEMORY):
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_FADING_MEMORY).get("icon", ""))
			_add_effect_tooltip("Fading Memory", [{"label": "Tip Bonus", "value": "+10%", "tone": "pos"}], "favor", c_ico)
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_STATIC_AIRWAVES) and is_instance_valid(StoreEventManager):
			var ev_cnt := StoreEventManager.get_active_events().size()
			if ev_cnt > 0:
				var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_STATIC_AIRWAVES).get("icon", ""))
				_add_effect_tooltip("Static Airwaves", [{"label": "Sale Bonus", "value": "+%d%%" % (ev_cnt * 10), "tone": "pos"}], "favor", c_ico)
				count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_CURBSIDE_GLOW) and StoryManager.get_featured_category_boost_count(item_data.category) > 0:
			var c_ico := str(MayariCardRegistry.get_card(MayariCardRegistry.CARD_CURBSIDE_GLOW).get("icon", ""))
			_add_effect_tooltip("Curbside Glow", [{"label": "Sale Bonus", "value": "+15%", "tone": "pos"}], "favor", c_ico)
			count += 1

	# 3. Active waiting counter customers who are currently requesting items
	var best_cust_bonus := 0
	if is_instance_valid(CharacterProgressionManager):
		var seen_paths: Dictionary = {}
		for spawner in get_tree().get_nodes_in_group("customer_spawner"):
			if not ("counter_slots" in spawner):
				continue
			for cust in spawner.counter_slots:
				if not is_instance_valid(cust) or cust.customer_data == null or cust._is_resolving:
					continue
				if cust.transaction_context == null or cust.transaction_context.desired_items.is_empty():
					continue
				var cpath: String = cust.customer_data.resource_path
				if seen_paths.has(cpath):
					continue
				seen_paths[cpath] = true
				var bonus := CharacterProgressionManager.get_reputation_tolerance_bonus(cust.customer_data, item_data)
				var is_fav := item_data.category != "" and CharacterProgressionManager.is_favorite_discovered(cpath, item_data.category)
				if bonus > 0 or is_fav:
					var cname: String = cust.customer_data.character_name if cust.customer_data.character_name != "" else cust.customer_data.get_clean_id().capitalize()
					var card_title := ("%s's Favorite" % cname) if is_fav else cname
					var disp_bonus := maxi(1, bonus) if is_fav else bonus
					_add_effect_tooltip(card_title, [{"label": "Price Tolerance", "value": "%+d" % disp_bonus, "tone": "pos"}], "customer", ICON_VISITOR)
					best_cust_bonus = maxi(best_cust_bonus, bonus)
					count += 1

	_tolerance_col.visible = count > 0
	return total_tol + best_cust_bonus


func _get_step_status_word(step: int, eff_tol: int, is_warm: bool) -> String:
	if is_warm:
		return "Warm"
	if step < 0:
		return "Discount"
	var eff_step: int = step - eff_tol
	if step == 0 and eff_step <= 2:
		return "Base"
	if eff_step <= 1:
		return "Safe"
	if eff_step == 2:
		return "Sweet Spot"
	if eff_step == 3:
		return "Risky"
	return "Overpriced"


func _play_step_juice(dir: int) -> void:
	if _juice_tween and _juice_tween.is_valid():
		_juice_tween.kill()
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	price_label.pivot_offset = price_label.size * 0.5
	price_label.scale = Vector2(1.09, 1.09)
	var arrow := right_arrow if dir > 0 else left_arrow
	arrow.scale = Vector2(1.26, 1.26)
	_juice_tween = create_tween().set_parallel(true)
	_juice_tween.tween_property(price_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_juice_tween.tween_property(arrow, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_juice_tween.chain().tween_callback(func():
		if is_instance_valid(pricing_viewport):
			pricing_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	)


func _on_fridge_coldness_changed(_coldness: float, _is_open: bool, is_warm: bool) -> void:
	if is_warm != _last_warm_state:
		_last_warm_state = is_warm
		if _current_item and _current_item.type == ItemData.ItemType.FRIDGE and pricing_ui.visible:
			show_item(_current_item, _last_basis_pos, _last_is_container, _last_custom_name, _last_stock_text)


func show_item(item_data: ItemData, basis_position: Vector3, is_container: bool = false, custom_name: String = "", stock_text: String = "") -> void:
	if not item_data:
		_current_item = null
		_last_step = -999
		hide_ui()
		return

	var same_item := (_current_item == item_data and pricing_ui.visible)
	var prev_step := _last_step

	_current_item = item_data
	_last_basis_pos = basis_position
	_last_is_container = is_container
	_last_custom_name = custom_name
	_last_stock_text = stock_text
	_last_warm_state = StoryManager.is_fridge_warm

	var final_price: float = item_data.get_final_price()
	var base_price: float = item_data.price
	var step: int = item_data.current_step
	_last_step = step
	var is_fridge_item: bool = item_data.type == ItemData.ItemType.FRIDGE
	var is_warm_now: bool = is_fridge_item and StoryManager.is_fridge_warm
	var display_price: float = maxf(1.0, snapped(final_price * StoryManager.FRIDGE_WARM_VALUE_MULTIPLIER, 0.5)) if is_warm_now else final_price

	# Inline T1..T4 prefix in pastel tier color at the same size as item name
	var tier_num: int = item_data.get_effective_tier()
	tier_label.text = "T%d" % tier_num
	tier_label.add_theme_color_override("font_color", UIStyle.get_tier_color(tier_num))
	name_label.text = custom_name if custom_name != "" else item_data.item_name
	price_label.text = "₱%.2f" % display_price

	var in_demand: bool = false
	if is_instance_valid(StoreEventManager) and StoreEventManager.has_method("is_item_in_demand"):
		in_demand = StoreEventManager.is_item_in_demand(item_data)

	# Icon-only status indicators inside the main tag
	_in_demand_icon.visible = in_demand
	if is_fridge_item:
		if is_warm_now:
			_temp_icon.texture = HadesEmblem.load_lucide_icon(ICON_WARM)
			_temp_icon.modulate = COL_WARM
		else:
			_temp_icon.texture = HadesEmblem.load_lucide_icon(ICON_FROZEN)
			_temp_icon.modulate = COL_CHILLED
		_temp_icon.show()
	else:
		_temp_icon.hide()

	# Rebuild right-side tooltips (including In Demand, Frozen/Chilled/Warm with icons)
	var total_tol := _rebuild_tolerance_tooltips(item_data, is_fridge_item, is_warm_now, in_demand)

	var diff: float = display_price - base_price
	var accent: Color = UIStyle.get_price_step_color(step, total_tol)
	var status_word := _get_step_status_word(step, total_tol, is_warm_now)
	var delta_str := ""
	if is_warm_now:
		accent = COL_WARM
		var sign_prefix := "+" if diff >= 0.0 else "-"
		delta_str = "%s₱%.2f (was ₱%.2f)" % [sign_prefix, absf(diff), final_price]
	elif step < 0:
		delta_str = "-₱%.2f" % absf(diff)
	elif step == 0:
		delta_str = "+₱0"
	else:
		delta_str = "+₱%.2f" % diff

	comparison_label.text = delta_str
	var sale_bonus := StoryManager.get_item_sale_bonus(item_data, display_price, true) if is_instance_valid(StoryManager) else 0.0
	if sale_bonus > 0.0:
		comparison_label.text += "  (+₱%.0f Bonus)" % sale_bonus
	comparison_label.add_theme_color_override("font_color", accent)

	status_label.text = status_word
	status_label.add_theme_color_override("font_color", accent)

	price_label.add_theme_color_override("font_color", COL_WARM if is_warm_now else COL_GOLD_SOFT)

	_gauge.step = step
	_gauge.min_step = ItemData.MIN_STEP
	_gauge.max_step = ItemData.MAX_STEP
	_gauge.safe_max_step = clampi(2 + total_tol, ItemData.MIN_STEP, ItemData.MAX_STEP)
	_gauge.accent_color = accent
	_gauge.queue_redraw()

	left_arrow.modulate = Color(1, 1, 1, 0.24) if step <= ItemData.MIN_STEP else Color(1, 1, 1, 1.0)
	right_arrow.modulate = Color(1, 1, 1, 0.24) if step >= ItemData.MAX_STEP else Color(1, 1, 1, 1.0)

	if stock_text != "":
		stock_label.text = "• " + stock_text
		stock_label.show()
	else:
		stock_label.hide()

	if is_container:
		pricing_ui.global_position = basis_position
	else:
		var h: float = item_data.display_height_meters
		pricing_ui.global_position = basis_position + Vector3(0, h * 0.5, 0.0)

	pricing_ui.show()
	if same_item and prev_step != -999 and step != prev_step:
		_play_step_juice(signi(step - prev_step))
	else:
		pricing_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func hide_ui() -> void:
	_current_item = null
	_last_step = -999
	if _juice_tween and _juice_tween.is_valid():
		_juice_tween.kill()
	pricing_ui.hide()
