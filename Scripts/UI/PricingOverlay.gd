extends Node3D

## Alt Lens 3D World Pricing Overlay.
## Styled in Sari-Saring Katha's Reyna Mayari visual language: deep espresso panel,
## soft antique-gold borders, taller/compact bidirectional price gauge (-5 to +5)
## colored dynamically by effective tolerance, and compact right-side tooltips for
## active Price Tolerance sources (Events, Mayari Cards, Sto. Niño, & active customers).

const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

const COL_ESPRESSO := Color(0.062, 0.054, 0.046, 0.96)
const COL_GOLD := Color(0.835, 0.624, 0.278, 0.92)
const COL_GOLD_SOFT := Color(0.96, 0.85, 0.52, 1.0)
const COL_CREAM := Color(1.0, 0.935, 0.815, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.76, 0.65, 0.86)
const COL_DISCOUNT := Color(0.50, 0.88, 0.58, 1.0)
const COL_RISKY := Color(0.98, 0.68, 0.28, 1.0)
const COL_DANGER := Color(0.96, 0.42, 0.34, 1.0)
const COL_WARM := Color(1.0, 0.56, 0.34, 1.0)
const COL_CHILLED := Color(0.48, 0.88, 1.0, 1.0)


class PriceStepGauge extends Control:
	var step: int = 0
	var min_step: int = ItemData.MIN_STEP
	var max_step: int = ItemData.MAX_STEP
	var accent_color: Color = Color(0.96, 0.85, 0.52, 1.0)

	func _draw_diamond(center: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
		])
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var pad_x := 10.0
		var bar_h := 24.0
		var bar_y := (size.y - bar_h) * 0.5
		var bar_w := maxf(20.0, size.x - pad_x * 2.0)
		var bar_rect := Rect2(pad_x, bar_y, bar_w, bar_h)
		var span := float(max_step - min_step)
		if span <= 0.0:
			return

		var zero_t := float(0 - min_step) / span
		var step_t := clampf(float(step - min_step) / span, 0.0, 1.0)
		var zero_x := pad_x + zero_t * bar_w
		var cur_x := pad_x + step_t * bar_w

		# Deep obsidian recessed track
		draw_rect(bar_rect, Color(0.035, 0.030, 0.026, 0.98), true)

		# Subtle step ruler notches (-5 .. +5)
		for i in range(min_step + 1, max_step):
			var nt := float(i - min_step) / span
			var nx := pad_x + nt * bar_w
			var is_zero := (i == 0)
			var tick_col := Color(0.96, 0.86, 0.58, 0.60) if is_zero else Color(1.0, 0.92, 0.78, 0.14)
			var y_inset := 1.0 if is_zero else 5.0
			draw_line(Vector2(nx, bar_y + y_inset), Vector2(nx, bar_y + bar_h - y_inset), tick_col, 1.8 if is_zero else 1.0, true)

		# Bidirectional fill from center (0) to current step
		var inset := 2.0
		if absf(cur_x - zero_x) > 1.0:
			var x0 := minf(zero_x, cur_x)
			var x1 := maxf(zero_x, cur_x)
			var fill_rect := Rect2(x0, bar_y + inset, x1 - x0, bar_h - inset * 2.0)
			draw_rect(fill_rect, accent_color, true)
			# Subtle upper sheen like Mayari's Silver Ledger gauge
			draw_rect(Rect2(x0, bar_y + inset, x1 - x0, 5.0), Color(1.0, 0.96, 0.84, 0.25), true)

		# Antique-gold outer frame + crisp dark inner bevel
		var frame_col := Color(0.835, 0.624, 0.278, 0.88)
		draw_rect(bar_rect, frame_col, false, 2.0)
		draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)

		# End-cap diamond ornaments (left & right)
		_draw_diamond(Vector2(pad_x, bar_y + bar_h * 0.5), 5.0, frame_col)
		_draw_diamond(Vector2(pad_x + bar_w, bar_y + bar_h * 0.5), 5.0, frame_col)

		# Center wholesale diamond marker below track
		_draw_diamond(Vector2(zero_x, bar_y + bar_h + 6.5), 3.2, Color(0.86, 0.72, 0.42, 0.78))

		# Glowing diamond thumb at active step
		var thumb_c := Vector2(cur_x, bar_y + bar_h * 0.5)
		_draw_diamond(thumb_c, 11.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.28))
		_draw_diamond(thumb_c, 8.0, Color(0.06, 0.05, 0.04, 0.96))
		_draw_diamond(thumb_c, 5.8, accent_color.lightened(0.25))


var pricing_ui: Sprite3D
var pricing_viewport: SubViewport
var name_label: Label
var price_label: Label
var comparison_label: Label
var in_demand_pill: PanelContainer
var in_demand_label: Label
var chill_pill: PanelContainer
var chill_status_label: Label
var stock_label: Label
var pricing_panel: PanelContainer
var left_arrow: Label
var right_arrow: Label
var _gauge: PriceStepGauge
var _tolerance_col: VBoxContainer
var _bold_font: FontVariation

var _current_item: ItemData
var _last_basis_pos: Vector3 = Vector3.ZERO
var _last_is_container: bool = false
var _last_custom_name: String = ""
var _last_stock_text: String = ""
var _last_warm_state: bool = false


func _ready() -> void:
	name = "PricingOverlay"
	add_to_group("pricing_overlay")

	_bold_font = FontVariation.new()
	_bold_font.base_font = INDER_FONT
	_bold_font.variation_embolden = 0.55

	pricing_viewport = SubViewport.new()
	pricing_viewport.transparent_bg = true
	pricing_viewport.size = Vector2(720, 320)
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(pricing_viewport)

	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_hbox.add_theme_constant_override("separation", 10)
	pricing_viewport.add_child(root_hbox)

	pricing_panel = PanelContainer.new()
	pricing_panel.custom_minimum_size = Vector2(410, 274)
	pricing_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root_hbox.add_child(pricing_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_ESPRESSO
	style.set_corner_radius_all(12)
	style.border_color = COL_GOLD
	style.set_border_width_all(2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_size = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	pricing_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	pricing_panel.add_child(vbox)

	# Compact horizontal badge row (In Demand / Chilled / Frozen / Warm)
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 8)
	vbox.add_child(badge_row)

	in_demand_pill = _make_badge_pill(Color(0.28, 0.20, 0.06, 0.92), COL_GOLD_SOFT)
	in_demand_label = in_demand_pill.get_node("Lbl") as Label
	in_demand_label.text = "IN DEMAND"
	in_demand_label.add_theme_color_override("font_color", COL_GOLD_SOFT)
	badge_row.add_child(in_demand_pill)
	in_demand_pill.hide()

	chill_pill = _make_badge_pill(Color(0.08, 0.20, 0.26, 0.92), COL_CHILLED)
	chill_status_label = chill_pill.get_node("Lbl") as Label
	badge_row.add_child(chill_pill)
	chill_pill.hide()

	# Item Name
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", _bold_font)
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", COL_CREAM)
	vbox.add_child(name_label)

	# Price Row with refined gold chevrons
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	left_arrow = Label.new()
	left_arrow.text = "‹"
	left_arrow.add_theme_font_override("font", _bold_font)
	left_arrow.add_theme_font_size_override("font_size", 40)
	left_arrow.add_theme_color_override("font_color", COL_GOLD_SOFT)
	left_arrow.pivot_offset = Vector2(10, 22)
	hbox.add_child(left_arrow)

	price_label = Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_override("font", _bold_font)
	price_label.add_theme_font_size_override("font_size", 46)
	price_label.add_theme_color_override("font_color", COL_GOLD_SOFT)
	price_label.add_theme_constant_override("outline_size", 3)
	price_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 0.95))
	hbox.add_child(price_label)

	right_arrow = Label.new()
	right_arrow.text = "›"
	right_arrow.add_theme_font_override("font", _bold_font)
	right_arrow.add_theme_font_size_override("font_size", 40)
	right_arrow.add_theme_color_override("font_color", COL_GOLD_SOFT)
	right_arrow.pivot_offset = Vector2(10, 22)
	hbox.add_child(right_arrow)

	# Taller, shorter-width Mayari-style bidirectional Price Gauge (-5 .. 0 .. +5)
	_gauge = PriceStepGauge.new()
	_gauge.custom_minimum_size = Vector2(310, 36)
	_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_gauge)

	# Footer row: Markup/Discount delta + Stock readout
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	vbox.add_child(foot)

	comparison_label = Label.new()
	comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comparison_label.add_theme_font_override("font", _bold_font)
	comparison_label.add_theme_font_size_override("font_size", 21)
	comparison_label.add_theme_color_override("font_color", COL_CREAM_MUTED)
	foot.add_child(comparison_label)

	stock_label = Label.new()
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.add_theme_font_override("font", INDER_FONT)
	stock_label.add_theme_font_size_override("font_size", 21)
	stock_label.add_theme_color_override("font_color", COL_DISCOUNT)
	foot.add_child(stock_label)

	# Right-side column of compact Price Tolerance tooltips (name + effect only)
	_tolerance_col = VBoxContainer.new()
	_tolerance_col.custom_minimum_size = Vector2(260, 0)
	_tolerance_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tolerance_col.add_theme_constant_override("separation", 6)
	_tolerance_col.hide()
	root_hbox.add_child(_tolerance_col)

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


func _make_badge_pill(bg_col: Color, border_col: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var st := UIStyle.create_flat_stylebox(bg_col, 6, 10, 2)
	st.border_color = border_col
	st.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", st)

	var lbl := Label.new()
	lbl.name = "Lbl"
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 15)
	pill.add_child(lbl)
	return pill


func _add_tolerance_tooltip(source_name: String, delta: int) -> void:
	var pill := PanelContainer.new()
	var border_col := COL_DISCOUNT if delta > 0 else COL_DANGER
	var st := UIStyle.create_flat_stylebox(COL_ESPRESSO, 8, 12, 7)
	st.border_color = Color(border_col.r, border_col.g, border_col.b, 0.78)
	st.set_border_width_all(2)
	pill.add_theme_stylebox_override("panel", st)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	pill.add_child(hb)

	var name_lbl := Label.new()
	name_lbl.text = source_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", INDER_FONT)
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", COL_CREAM)
	hb.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%+d" % delta
	val_lbl.add_theme_font_override("font", _bold_font)
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", border_col)
	hb.add_child(val_lbl)

	_tolerance_col.add_child(pill)


func _rebuild_tolerance_tooltips(item_data: ItemData) -> int:
	for ch in _tolerance_col.get_children():
		ch.queue_free()

	var total_tol := 0
	var count := 0

	# 1. Active Neighborhood Events (revealed or global)
	if is_instance_valid(StoreEventManager):
		var best_targeted_ev: StoreEventData = null
		var best_targeted_val := 0
		for ev in StoreEventManager.get_all_active_events():
			if ev == null:
				continue
			if ev.affects_item(item_data) and ev.tolerance_offset > best_targeted_val:
				best_targeted_val = ev.tolerance_offset
				best_targeted_ev = ev
			if ev.global_tolerance_offset != 0:
				_add_tolerance_tooltip(ev.event_name, ev.global_tolerance_offset)
				total_tol += ev.global_tolerance_offset
				count += 1
		if best_targeted_ev != null and best_targeted_val != 0:
			_add_tolerance_tooltip(best_targeted_ev.event_name, best_targeted_val)
			total_tol += best_targeted_val
			count += 1

	# 2. Active Mayari Moon Cards & Sto. Niño Blessings (stack separately)
	if is_instance_valid(StoryManager):
		var has_mayari_silver := (
			StoryManager.active_mayari_card == MayariCardRegistry.CARD_SILVER_TOLERANCE
			or (MayariCardRegistry.CARD_SILVER_TOLERANCE in StoryManager.active_mayari_cards)
		)
		if has_mayari_silver:
			_add_tolerance_tooltip("Silver Tolerance", 1)
			total_tol += 1
			count += 1
		if MayariCardRegistry.CARD_SILVER_TOLERANCE in StoryManager.active_blessing_cards:
			_add_tolerance_tooltip("Sto. Niño Blessing", 1)
			total_tol += 1
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH):
			_add_tolerance_tooltip("Eerie Mist Rush", -1)
			total_tol -= 1
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
			_add_tolerance_tooltip("Reluctant Care", -1)
			total_tol -= 1
			count += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			_add_tolerance_tooltip("Restless Crowd", -1)
			total_tol -= 1
			count += 1

	# 3. Active waiting counter customers with Reputation tolerance bonus for this item
	var best_cust_bonus := 0
	if is_instance_valid(CharacterProgressionManager):
		var seen_paths: Dictionary = {}
		for spawner in get_tree().get_nodes_in_group("customer_spawner"):
			if not ("counter_slots" in spawner):
				continue
			for cust in spawner.counter_slots:
				if not is_instance_valid(cust) or cust.customer_data == null or cust._is_resolving:
					continue
				var cpath: String = cust.customer_data.resource_path
				if seen_paths.has(cpath):
					continue
				seen_paths[cpath] = true
				var bonus := CharacterProgressionManager.get_reputation_tolerance_bonus(cust.customer_data, item_data)
				if bonus > 0:
					var cname: String = cust.customer_data.character_name if cust.customer_data.character_name != "" else cust.customer_data.get_clean_id().capitalize()
					_add_tolerance_tooltip(cname, bonus)
					best_cust_bonus = maxi(best_cust_bonus, bonus)
					count += 1

	_tolerance_col.visible = count > 0
	return total_tol + best_cust_bonus


func _on_fridge_coldness_changed(_coldness: float, _is_open: bool, is_warm: bool) -> void:
	if is_warm != _last_warm_state:
		_last_warm_state = is_warm
		if _current_item and _current_item.type == ItemData.ItemType.FRIDGE and pricing_ui.visible:
			show_item(_current_item, _last_basis_pos, _last_is_container, _last_custom_name, _last_stock_text)


func show_item(item_data: ItemData, basis_position: Vector3, is_container: bool = false, custom_name: String = "", stock_text: String = "") -> void:
	if not item_data:
		_current_item = null
		hide_ui()
		return

	_current_item = item_data
	_last_basis_pos = basis_position
	_last_is_container = is_container
	_last_custom_name = custom_name
	_last_stock_text = stock_text
	_last_warm_state = StoryManager.is_fridge_warm

	var final_price: float = item_data.get_final_price()
	var base_price: float = item_data.price
	var step: int = item_data.current_step
	var is_fridge_item: bool = item_data.type == ItemData.ItemType.FRIDGE
	var is_warm_now: bool = is_fridge_item and StoryManager.is_fridge_warm
	var display_price: float = maxf(1.0, snapped(final_price * StoryManager.FRIDGE_WARM_VALUE_MULTIPLIER, 0.5)) if is_warm_now else final_price

	name_label.text = custom_name if custom_name != "" else item_data.item_name
	price_label.text = "₱%.2f" % display_price

	if is_fridge_item:
		var pst := chill_pill.get_theme_stylebox("panel") as StyleBoxFlat
		if is_warm_now:
			chill_status_label.text = "WARM -25%"
			chill_status_label.add_theme_color_override("font_color", COL_WARM)
			if pst:
				pst.bg_color = Color(0.28, 0.12, 0.06, 0.92)
				pst.border_color = COL_WARM
		else:
			chill_status_label.text = "FROZEN" if item_data.category == "frozen" else "CHILLED"
			chill_status_label.add_theme_color_override("font_color", COL_CHILLED)
			if pst:
				pst.bg_color = Color(0.08, 0.20, 0.26, 0.92)
				pst.border_color = COL_CHILLED
		chill_pill.show()
	else:
		chill_pill.hide()

	# Rebuild right-side tolerance tooltips & compute effective step for color feedback
	var total_tol := _rebuild_tolerance_tooltips(item_data)
	var effective_step := step - total_tol

	var diff: float = display_price - base_price
	var accent: Color = COL_GOLD_SOFT
	if is_warm_now:
		accent = COL_WARM
		var sign_prefix := "+" if diff >= 0.0 else "-"
		comparison_label.text = "%s₱%.2f (was ₱%.2f)" % [sign_prefix, absf(diff), final_price]
	elif step < 0:
		accent = COL_DISCOUNT
		comparison_label.text = "-₱%.2f" % absf(diff)
	elif step == 0:
		accent = COL_GOLD_SOFT if effective_step <= 1 else (COL_RISKY if effective_step == 2 else COL_DANGER)
		comparison_label.text = "BASE COST"
	else:
		comparison_label.text = "+₱%.2f" % diff
		if effective_step <= 1:
			accent = COL_GOLD_SOFT
		elif effective_step == 2:
			accent = COL_RISKY
		else:
			accent = COL_DANGER

	price_label.add_theme_color_override("font_color", COL_WARM if is_warm_now else COL_GOLD_SOFT)
	comparison_label.add_theme_color_override("font_color", accent)

	_gauge.step = step
	_gauge.min_step = ItemData.MIN_STEP
	_gauge.max_step = ItemData.MAX_STEP
	_gauge.accent_color = accent
	_gauge.queue_redraw()

	left_arrow.modulate = Color(1, 1, 1, 0.28) if step <= ItemData.MIN_STEP else Color(1, 1, 1, 1.0)
	right_arrow.modulate = Color(1, 1, 1, 0.28) if step >= ItemData.MAX_STEP else Color(1, 1, 1, 1.0)

	var in_demand: bool = false
	if is_instance_valid(StoreEventManager) and StoreEventManager.has_method("is_item_in_demand"):
		in_demand = StoreEventManager.is_item_in_demand(item_data)
	in_demand_pill.visible = in_demand

	if stock_text != "":
		stock_label.text = "•  " + stock_text
		stock_label.show()
	else:
		stock_label.hide()

	if is_container:
		pricing_ui.global_position = basis_position + Vector3(0, 0.5, 0.1)
	else:
		var h: float = item_data.display_height_meters
		pricing_ui.global_position = basis_position + Vector3(0, h * 0.5, 0.12)

	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	pricing_ui.show()


func hide_ui() -> void:
	_current_item = null
	pricing_ui.hide()
