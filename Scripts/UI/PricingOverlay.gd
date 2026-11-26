extends Node3D

## Alt Lens 3D World Pricing Overlay.
## Styled in Sari-Saring Katha's Reyna Mayari visual language: deep espresso panel,
## soft antique-gold borders & diamond ornaments, emboldened Inder typography,
## pill status badges, and a bidirectional center-zero price gauge (-5 to +5).

const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

const COL_ESPRESSO := Color(0.062, 0.054, 0.046, 0.96)
const COL_GOLD := Color(0.835, 0.624, 0.278, 0.92)
const COL_GOLD_SOFT := Color(0.96, 0.85, 0.52, 1.0)
const COL_CREAM := Color(1.0, 0.935, 0.815, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.76, 0.65, 0.86)
const COL_DISCOUNT := Color(0.50, 0.88, 0.58, 1.0)
const COL_MARKUP_LO := Color(0.98, 0.84, 0.42, 1.0)
const COL_MARKUP_HI := Color(0.96, 0.42, 0.34, 1.0)
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
		var bar_h := 16.0
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
			var tick_col := Color(0.96, 0.86, 0.58, 0.55) if is_zero else Color(1.0, 0.92, 0.78, 0.14)
			var y_inset := 1.0 if is_zero else 4.0
			draw_line(Vector2(nx, bar_y + y_inset), Vector2(nx, bar_y + bar_h - y_inset), tick_col, 1.6 if is_zero else 1.0, true)

		# Bidirectional fill from center (0) to current step
		var inset := 2.0
		if absf(cur_x - zero_x) > 1.0:
			var x0 := minf(zero_x, cur_x)
			var x1 := maxf(zero_x, cur_x)
			var fill_rect := Rect2(x0, bar_y + inset, x1 - x0, bar_h - inset * 2.0)
			draw_rect(fill_rect, accent_color, true)
			# Subtle upper sheen like Mayari's Silver Ledger gauge
			draw_rect(Rect2(x0, bar_y + inset, x1 - x0, 4.0), Color(1.0, 0.96, 0.84, 0.26), true)

		# Antique-gold outer frame + crisp dark inner bevel
		var frame_col := Color(0.835, 0.624, 0.278, 0.88)
		draw_rect(bar_rect, frame_col, false, 2.0)
		draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)

		# End-cap diamond ornaments (left & right)
		_draw_diamond(Vector2(pad_x, bar_y + bar_h * 0.5), 4.5, frame_col)
		_draw_diamond(Vector2(pad_x + bar_w, bar_y + bar_h * 0.5), 4.5, frame_col)

		# Center wholesale marker below track
		_draw_diamond(Vector2(zero_x, bar_y + bar_h + 6.5), 3.0, Color(0.86, 0.72, 0.42, 0.75))

		# Glowing diamond thumb at active step
		var thumb_c := Vector2(cur_x, bar_y + bar_h * 0.5)
		_draw_diamond(thumb_c, 9.5, Color(accent_color.r, accent_color.g, accent_color.b, 0.28))
		_draw_diamond(thumb_c, 7.0, Color(0.06, 0.05, 0.04, 0.96))
		_draw_diamond(thumb_c, 5.2, accent_color.lightened(0.25))


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
	pricing_viewport.size = Vector2(480, 310)
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(pricing_viewport)

	pricing_panel = PanelContainer.new()
	pricing_viewport.add_child(pricing_panel)
	pricing_panel.size = Vector2(480, 310)
	pricing_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_ESPRESSO
	style.set_corner_radius_all(12)
	style.border_color = COL_GOLD
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_size = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	pricing_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	pricing_panel.add_child(vbox)

	# Branded eyebrow header ("✦ PRICE LENS ✦")
	var eyebrow := Label.new()
	eyebrow.text = "✦  PRICE LENS  ✦"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", _bold_font)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", COL_GOLD)
	vbox.add_child(eyebrow)

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
	name_label.add_theme_font_size_override("font_size", 29)
	name_label.add_theme_color_override("font_color", COL_CREAM)
	vbox.add_child(name_label)

	# Price Row with refined gold chevrons
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	vbox.add_child(hbox)

	left_arrow = Label.new()
	left_arrow.text = "‹"
	left_arrow.add_theme_font_override("font", _bold_font)
	left_arrow.add_theme_font_size_override("font_size", 42)
	left_arrow.add_theme_color_override("font_color", COL_GOLD_SOFT)
	left_arrow.pivot_offset = Vector2(10, 22)
	hbox.add_child(left_arrow)

	price_label = Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_override("font", _bold_font)
	price_label.add_theme_font_size_override("font_size", 48)
	price_label.add_theme_color_override("font_color", COL_GOLD_SOFT)
	price_label.add_theme_constant_override("outline_size", 3)
	price_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 0.95))
	hbox.add_child(price_label)

	right_arrow = Label.new()
	right_arrow.text = "›"
	right_arrow.add_theme_font_override("font", _bold_font)
	right_arrow.add_theme_font_size_override("font_size", 42)
	right_arrow.add_theme_color_override("font_color", COL_GOLD_SOFT)
	right_arrow.pivot_offset = Vector2(10, 22)
	hbox.add_child(right_arrow)

	# Reyna Mayari-style bidirectional Price Gauge (-5 .. 0 .. +5)
	_gauge = PriceStepGauge.new()
	_gauge.custom_minimum_size = Vector2(390, 32)
	_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_gauge)

	# Footer row: Markup/Discount delta + Stock readout
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 18)
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

	# Gauge & delta readout styling
	var diff: float = display_price - base_price
	var accent: Color = COL_GOLD_SOFT
	if is_warm_now:
		accent = COL_WARM
		var sign_prefix := "+" if diff >= 0.0 else "-"
		comparison_label.text = "%s₱%.2f (was ₱%.2f)" % [sign_prefix, absf(diff), final_price]
	elif step > 0:
		var factor := float(step) / float(ItemData.MAX_STEP)
		accent = COL_MARKUP_LO.lerp(COL_MARKUP_HI, factor)
		comparison_label.text = "+₱%.2f" % diff
	elif step < 0:
		accent = COL_DISCOUNT
		comparison_label.text = "-₱%.2f" % absf(diff)
	else:
		accent = COL_GOLD_SOFT
		comparison_label.text = "BASE COST"

	price_label.add_theme_color_override("font_color", COL_WARM if is_warm_now else COL_GOLD_SOFT)
	comparison_label.add_theme_color_override("font_color", accent)

	_gauge.step = step
	_gauge.min_step = ItemData.MIN_STEP
	_gauge.max_step = ItemData.MAX_STEP
	_gauge.accent_color = accent
	_gauge.queue_redraw()

	# Arrow dimming at step bounds
	left_arrow.modulate = Color(1, 1, 1, 0.28) if step <= ItemData.MIN_STEP else Color(1, 1, 1, 1.0)
	right_arrow.modulate = Color(1, 1, 1, 0.28) if step >= ItemData.MAX_STEP else Color(1, 1, 1, 1.0)

	# In Demand Badge
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
