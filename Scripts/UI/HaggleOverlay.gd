class_name HaggleOverlay
extends CanvasLayer

## Modern, minimalistic Tawad / Haggle Overlay triggered when a customer balks at a high price.
## Lets the player slide a long interactive price-step gauge downward to offer a temporary
## one-time discount (does not permanently alter the shelf price), showing live acceptance
## odds based on the customer's perceived effective step.

signal haggle_finished(accepted: bool, offered_step: int)

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

const COL_BG := Color(0.062, 0.054, 0.046, 0.96)
const COL_GOLD := Color(0.835, 0.624, 0.278, 0.92)
const COL_GOLD_SOFT := Color(0.96, 0.85, 0.52, 1.0)
const COL_CREAM := Color(1.0, 0.935, 0.815, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.76, 0.65, 0.86)
const COL_GOOD := Color(0.50, 0.88, 0.58, 1.0)
const COL_WARN := Color(0.98, 0.68, 0.28, 1.0)
const COL_BAD := Color(0.96, 0.42, 0.34, 1.0)

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.02, 0.018, 0.016, 0.88);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.12, 1.0));
	float vig = smoothstep(0.14, 0.76, dist);
	COLOR = vec4(tint.rgb, mix(0.42, tint.a, vig));
}
"""


class HaggleGauge extends Control:
	signal step_changed(new_step: int)

	var min_step: int = ItemData.MIN_STEP
	var max_step: int = ItemData.MAX_STEP
	var original_step: int = 3
	var current_step: int = 2
	var accent_color: Color = Color(0.96, 0.85, 0.52, 1.0)
	var _dragging: bool = false

	func _draw_diamond(center: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
		])
		draw_colored_polygon(pts, col)

	func _step_to_x(st: int) -> float:
		var pad_x := 22.0
		var bar_w := maxf(40.0, size.x - pad_x * 2.0)
		var span := float(max_step - min_step)
		if span <= 0.0:
			return pad_x
		var t := clampf(float(st - min_step) / span, 0.0, 1.0)
		return pad_x + t * bar_w

	func _x_to_step(px: float) -> int:
		var pad_x := 22.0
		var bar_w := maxf(40.0, size.x - pad_x * 2.0)
		var t := clampf((px - pad_x) / bar_w, 0.0, 1.0)
		var raw := int(roundf(lerpf(float(min_step), float(max_step), t)))
		return clampi(raw, min_step, original_step)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				var next_st := _x_to_step((event as InputEventMouseButton).position.x)
				if next_st != current_step:
					current_step = next_st
					queue_redraw()
					step_changed.emit(current_step)
		elif event is InputEventMouseMotion and _dragging:
			var next_st := _x_to_step((event as InputEventMouseMotion).position.x)
			if next_st != current_step:
				current_step = next_st
				queue_redraw()
				step_changed.emit(current_step)

	func _draw() -> void:
		var pad_x := 22.0
		var bar_h := 30.0
		var bar_y := (size.y - bar_h) * 0.5
		var bar_w := maxf(40.0, size.x - pad_x * 2.0)
		var bar_rect := Rect2(pad_x, bar_y, bar_w, bar_h)

		# Recessed dark track
		draw_rect(bar_rect, Color(0.032, 0.028, 0.024, 0.98), true)

		# Locked zone above original_step (cannot haggle upward)
		var orig_x := _step_to_x(original_step)
		if orig_x < pad_x + bar_w - 1.0:
			draw_rect(Rect2(orig_x, bar_y + 2.0, (pad_x + bar_w) - orig_x, bar_h - 4.0), Color(0.18, 0.14, 0.12, 0.45), true)

		# Step ticks (-5 .. +5)
		for i in range(min_step + 1, max_step):
			var nx := _step_to_x(i)
			var is_zero := (i == 0)
			var tick_col := Color(0.96, 0.86, 0.58, 0.65) if is_zero else Color(1.0, 0.92, 0.78, 0.18)
			var y_in := 1.0 if is_zero else 6.0
			draw_line(Vector2(nx, bar_y + y_in), Vector2(nx, bar_y + bar_h - y_in), tick_col, 2.0 if is_zero else 1.2, true)

		# Fill from wholesale 0 to current_step
		var zero_x := _step_to_x(0)
		var cur_x := _step_to_x(current_step)
		if absf(cur_x - zero_x) > 1.0:
			var x0 := minf(zero_x, cur_x)
			var x1 := maxf(zero_x, cur_x)
			draw_rect(Rect2(x0, bar_y + 2.0, x1 - x0, bar_h - 4.0), accent_color, true)
			draw_rect(Rect2(x0, bar_y + 2.0, x1 - x0, 6.0), Color(1.0, 0.96, 0.86, 0.25), true)

		# Outer gold frame
		var frame_col := Color(0.835, 0.624, 0.278, 0.90)
		draw_rect(bar_rect, frame_col, false, 2.0)
		draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)

		# End caps & wholesale 0 marker
		_draw_diamond(Vector2(pad_x, bar_y + bar_h * 0.5), 6.0, frame_col)
		_draw_diamond(Vector2(pad_x + bar_w, bar_y + bar_h * 0.5), 6.0, frame_col)
		_draw_diamond(Vector2(zero_x, bar_y + bar_h + 9.0), 4.0, Color(0.86, 0.72, 0.42, 0.82))

		# Original price marker (subtle vertical pin)
		draw_line(Vector2(orig_x, bar_y - 6.0), Vector2(orig_x, bar_y + bar_h + 6.0), Color(0.96, 0.48, 0.40, 0.72), 2.0, true)

		# Active glowing diamond thumb
		var thumb_c := Vector2(cur_x, bar_y + bar_h * 0.5)
		_draw_diamond(thumb_c, 15.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.30))
		_draw_diamond(thumb_c, 11.0, Color(0.06, 0.05, 0.04, 0.96))
		_draw_diamond(thumb_c, 8.0, accent_color.lightened(0.25))


var _item_data: ItemData
var _customer_data: CustomerData
var _original_step: int = 3
var _offered_step: int = 2
var _tolerance: int = 0
var _resolved: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

var _bold_font: FontVariation
var _root: Control
var _panel: PanelContainer
var _gauge: HaggleGauge
var _price_lbl: Label
var _diff_lbl: Label
var _chance_lbl: Label
var _chance_bar: ProgressBar
var _status_lbl: Label
var _offer_btn: Button
var _walk_btn: Button


static func compute_haggle_accept_chance(offered_step: int, tolerance: int) -> float:
	var eff_step: int = offered_step - tolerance
	var base: float = 1.0
	if eff_step <= 0:
		base = 1.0
	elif eff_step == 1:
		base = 0.92
	elif eff_step == 2:
		base = 0.80
	elif eff_step == 3:
		base = 0.55
	elif eff_step == 4:
		base = 0.30
	else:
		base = 0.12

	var relief: float = StoryManager.get_storefront_price_relief() if is_instance_valid(StoryManager) else 0.0
	var card_mod: float = 0.0
	if is_instance_valid(StoryManager):
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_UNRUSHED_HOUR):
			card_mod += 0.20
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			card_mod -= 0.15
	return clampf(base + relief + card_mod, 0.05, 1.0)


func setup(item_data: ItemData, customer_data: CustomerData) -> void:
	_item_data = item_data
	_customer_data = customer_data
	_original_step = item_data.current_step
	_offered_step = maxi(ItemData.MIN_STEP, _original_step - 1)
	_tolerance = 0
	if is_instance_valid(StoreEventManager):
		_tolerance += StoreEventManager.get_item_tolerance_offset(item_data)
	if is_instance_valid(StoryManager):
		_tolerance += StoryManager.get_mayari_tolerance_offset()
	if customer_data != null and is_instance_valid(CharacterProgressionManager):
		_tolerance += CharacterProgressionManager.get_reputation_tolerance_bonus(customer_data, item_data)


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_to_group("minigame_overlay_active")

	_bold_font = FontVariation.new()
	_bold_font.base_font = INDER_FONT
	_bold_font.variation_embolden = 0.55

	_build_ui()
	_refresh_ui()
	Juice.pop_panel_in(_panel)


func _unhandled_input(event: InputEvent) -> void:
	if _resolved:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			get_viewport().set_input_as_handled()
			_nudge_step(-1)
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			get_viewport().set_input_as_handled()
			_nudge_step(1)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_on_offer_pressed()
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_walk_pressed()


func _nudge_step(delta: int) -> void:
	if _resolved:
		return
	var next_st := clampi(_offered_step + delta, ItemData.MIN_STEP, _original_step)
	if next_st != _offered_step:
		_offered_step = next_st
		Juice.play_sfx("ui_hover", 1.05 + float(_offered_step) * 0.03, -4.0)
		_refresh_ui()


func _price_for_step(st: int) -> float:
	if _item_data == null:
		return 0.0
	var saved := _item_data.current_step
	_item_data.current_step = st
	var p := _item_data.get_final_price()
	_item_data.current_step = saved
	return p


func _refresh_ui() -> void:
	if _item_data == null:
		return
	var offered_price := _price_for_step(_offered_step)
	var orig_price := _price_for_step(_original_step)
	var chance := compute_haggle_accept_chance(_offered_step, _tolerance)
	var pct := int(roundf(chance * 100.0))

	var col := COL_GOOD if chance >= 0.75 else (COL_WARN if chance >= 0.45 else COL_BAD)

	_gauge.min_step = ItemData.MIN_STEP
	_gauge.max_step = ItemData.MAX_STEP
	_gauge.original_step = _original_step
	_gauge.current_step = _offered_step
	_gauge.accent_color = col
	_gauge.queue_redraw()

	_price_lbl.text = "₱%.2f" % offered_price
	var savings := orig_price - offered_price
	if savings > 0.01:
		_diff_lbl.text = "-₱%.2f off  (this sale only)" % savings
		_diff_lbl.add_theme_color_override("font_color", COL_GOOD)
	else:
		_diff_lbl.text = "Current shelf price  (no discount)"
		_diff_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)

	_chance_lbl.text = "%d%% Accept Chance" % pct
	_chance_lbl.add_theme_color_override("font_color", col)
	_chance_bar.value = pct
	var fill_st := _chance_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_st:
		fill_st.bg_color = col

	_offer_btn.text = "Offer ₱%.2f" % offered_price


func _on_offer_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	_offer_btn.disabled = true
	_walk_btn.disabled = true

	var chance := compute_haggle_accept_chance(_offered_step, _tolerance)
	var accepted := randf() < chance
	if accepted:
		Juice.play_sfx("pickup", 1.22, 1.0)
		_status_lbl.text = "Deal! They accepted ₱%.2f." % _price_for_step(_offered_step)
		_status_lbl.add_theme_color_override("font_color", COL_GOOD)
		Juice.pop_control(_panel, 1.04, 0.22)
	else:
		Juice.play_sfx("error", 0.88, 0.5)
		_status_lbl.text = "Too steep — they turned it down!"
		_status_lbl.add_theme_color_override("font_color", COL_BAD)
		Juice.shake_control(_root, 9.0, 0.22)

	await get_tree().create_timer(0.55).timeout
	_finish(accepted, _offered_step)


func _on_walk_pressed() -> void:
	if _resolved:
		return
	_resolved = true
	Juice.play_sfx("tab_switch", 0.85, -3.0)
	_finish(false, _original_step)


func _finish(accepted: bool, offered_step: int) -> void:
	if is_in_group("minigame_overlay_active"):
		remove_from_group("minigame_overlay_active")
	Input.mouse_mode = _prev_mouse_mode
	haggle_finished.emit(accepted, offered_step)
	queue_free()


func _build_ui() -> void:
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.offset_left = -36
	vig.offset_top = -36
	vig.offset_right = 36
	vig.offset_bottom = 36
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vig.material = mat
	add_child(vig)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 390)
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -195
	_panel.offset_bottom = 195
	var st := UIStyle.create_flat_stylebox(COL_BG, 14, 34, 26)
	st.border_color = COL_GOLD
	st.set_border_width_all(2)
	st.shadow_size = 18
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_panel.add_theme_stylebox_override("panel", st)
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)

	var cname := _customer_data.character_name if (_customer_data and _customer_data.character_name != "") else "Neighbor"
	var iname := _item_data.item_name if _item_data else "Item"

	var title := Label.new()
	title.text = "Haggle — %s" % iname
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COL_GOLD_SOFT)
	vb.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.text = "%s hesitated at ₱%.2f. Lower your offer for this sale?" % [cname, _price_for_step(_original_step)]
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_override("font", INDER_FONT)
	_status_lbl.add_theme_font_size_override("font_size", 17)
	_status_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	vb.add_child(_status_lbl)

	# Price & Savings readout
	var price_box := VBoxContainer.new()
	price_box.alignment = BoxContainer.ALIGNMENT_CENTER
	price_box.add_theme_constant_override("separation", 2)
	vb.add_child(price_box)

	_price_lbl = Label.new()
	_price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_lbl.add_theme_font_override("font", _bold_font)
	_price_lbl.add_theme_font_size_override("font_size", 44)
	_price_lbl.add_theme_color_override("font_color", COL_CREAM)
	price_box.add_child(_price_lbl)

	_diff_lbl = Label.new()
	_diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_lbl.add_theme_font_override("font", INDER_FONT)
	_diff_lbl.add_theme_font_size_override("font_size", 15)
	price_box.add_child(_diff_lbl)

	# Long interactive Haggle Gauge with left/right step buttons
	var gauge_row := HBoxContainer.new()
	gauge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gauge_row.add_theme_constant_override("separation", 12)
	vb.add_child(gauge_row)

	var minus_btn := Button.new()
	minus_btn.text = "‹"
	minus_btn.focus_mode = Control.FOCUS_NONE
	minus_btn.custom_minimum_size = Vector2(44, 44)
	minus_btn.add_theme_font_override("font", _bold_font)
	minus_btn.add_theme_font_size_override("font_size", 28)
	minus_btn.pressed.connect(_nudge_step.bind(-1))
	gauge_row.add_child(minus_btn)

	_gauge = HaggleGauge.new()
	_gauge.custom_minimum_size = Vector2(580, 56)
	_gauge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_gauge.step_changed.connect(func(st_val: int):
		_offered_step = st_val
		Juice.play_sfx("ui_hover", 1.05 + float(st_val) * 0.03, -5.0)
		_refresh_ui()
	)
	gauge_row.add_child(_gauge)

	var plus_btn := Button.new()
	plus_btn.text = "›"
	plus_btn.focus_mode = Control.FOCUS_NONE
	plus_btn.custom_minimum_size = Vector2(44, 44)
	plus_btn.add_theme_font_override("font", _bold_font)
	plus_btn.add_theme_font_size_override("font_size", 28)
	plus_btn.pressed.connect(_nudge_step.bind(1))
	gauge_row.add_child(plus_btn)

	# Acceptance Chance bar + label
	var chance_box := VBoxContainer.new()
	chance_box.alignment = BoxContainer.ALIGNMENT_CENTER
	chance_box.add_theme_constant_override("separation", 6)
	vb.add_child(chance_box)

	_chance_lbl = Label.new()
	_chance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chance_lbl.add_theme_font_override("font", _bold_font)
	_chance_lbl.add_theme_font_size_override("font_size", 20)
	chance_box.add_child(_chance_lbl)

	_chance_bar = ProgressBar.new()
	_chance_bar.custom_minimum_size = Vector2(360, 10)
	_chance_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_chance_bar.max_value = 100.0
	_chance_bar.show_percentage = false
	_chance_bar.add_theme_stylebox_override("background", UIStyle.create_flat_stylebox(Color(0.12, 0.10, 0.09, 0.90), 5, 0, 0))
	_chance_bar.add_theme_stylebox_override("fill", UIStyle.create_flat_stylebox(COL_GOOD, 5, 0, 0))
	chance_box.add_child(_chance_bar)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vb.add_child(btn_row)

	_walk_btn = Button.new()
	_walk_btn.text = "Let Them Go"
	_walk_btn.focus_mode = Control.FOCUS_NONE
	_walk_btn.custom_minimum_size = Vector2(180, 46)
	_walk_btn.add_theme_font_override("font", INDER_FONT)
	_walk_btn.add_theme_font_size_override("font_size", 18)
	_walk_btn.pressed.connect(_on_walk_pressed)
	btn_row.add_child(_walk_btn)

	_offer_btn = Button.new()
	_offer_btn.text = "Offer"
	_offer_btn.focus_mode = Control.FOCUS_NONE
	_offer_btn.custom_minimum_size = Vector2(210, 46)
	_offer_btn.add_theme_font_override("font", _bold_font)
	_offer_btn.add_theme_font_size_override("font_size", 19)
	var ost := UIStyle.create_flat_stylebox(Color(0.36, 0.27, 0.12, 0.98), 8, 18, 8)
	ost.border_color = COL_GOLD_SOFT
	ost.set_border_width_all(2)
	_offer_btn.add_theme_stylebox_override("normal", ost)
	var ohov := ost.duplicate() as StyleBoxFlat
	ohov.bg_color = Color(0.46, 0.35, 0.16, 0.98)
	_offer_btn.add_theme_stylebox_override("hover", ohov)
	_offer_btn.add_theme_color_override("font_color", COL_CREAM)
	_offer_btn.pressed.connect(_on_offer_pressed)
	btn_row.add_child(_offer_btn)
