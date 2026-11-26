class_name HaggleOverlay
extends CanvasLayer

## Frameless, vignette-style Tawad / Haggle HUD triggered when a customer balks at a high price.
## Does NOT hijack the mouse — keeps FPS look intact while blocking other counter interactions.
## Scroll wheel (or A/D / Left/Right) adjusts the long price-step gauge; [F] confirms the offer
## and [Esc] lets the customer go. Acceptance/rejection plays directly on the customer's dialogue.

signal haggle_finished(accepted: bool, offered_step: int)

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

const COL_GOLD := Color(0.835, 0.624, 0.278, 0.92)
const COL_GOLD_SOFT := Color(0.96, 0.85, 0.52, 1.0)
const COL_CREAM := Color(1.0, 0.935, 0.815, 1.0)
const COL_CREAM_MUTED := Color(0.88, 0.82, 0.72, 0.90)
const COL_OUTLINE := Color(0.04, 0.03, 0.025, 0.94)
const COL_GOOD := Color(0.50, 0.88, 0.58, 1.0)
const COL_WARN := Color(0.98, 0.68, 0.28, 1.0)
const COL_BAD := Color(0.96, 0.42, 0.34, 1.0)

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.02, 0.018, 0.016, 0.82);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.12, 1.0));
	float vig = smoothstep(0.18, 0.78, dist);
	COLOR = vec4(tint.rgb, mix(0.22, tint.a, vig));
}
"""


class HaggleGauge extends Control:
	var min_step: int = ItemData.MIN_STEP
	var max_step: int = ItemData.MAX_STEP
	var original_step: int = 3
	var current_step: int = 2
	var accent_color: Color = Color(0.96, 0.85, 0.52, 1.0)

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

	func _draw() -> void:
		var pad_x := 22.0
		var bar_h := 28.0
		var bar_y := (size.y - bar_h) * 0.5
		var bar_w := maxf(40.0, size.x - pad_x * 2.0)
		var bar_rect := Rect2(pad_x, bar_y, bar_w, bar_h)

		# Recessed obsidian track
		draw_rect(bar_rect, Color(0.032, 0.028, 0.024, 0.92), true)

		# Locked region above original_step (cannot haggle upward)
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
			draw_rect(Rect2(x0, bar_y + 2.0, x1 - x0, 5.0), Color(1.0, 0.96, 0.86, 0.25), true)

		# Antique gold outer border
		var frame_col := Color(0.835, 0.624, 0.278, 0.92)
		draw_rect(bar_rect, frame_col, false, 2.0)

		# End caps & wholesale 0 marker
		_draw_diamond(Vector2(pad_x, bar_y + bar_h * 0.5), 5.5, frame_col)
		_draw_diamond(Vector2(pad_x + bar_w, bar_y + bar_h * 0.5), 5.5, frame_col)
		_draw_diamond(Vector2(zero_x, bar_y + bar_h + 8.0), 3.8, Color(0.86, 0.72, 0.42, 0.85))

		# Original price pin
		draw_line(Vector2(orig_x, bar_y - 6.0), Vector2(orig_x, bar_y + bar_h + 6.0), Color(0.96, 0.48, 0.40, 0.75), 2.0, true)

		# Active glowing diamond thumb
		var thumb_c := Vector2(cur_x, bar_y + bar_h * 0.5)
		_draw_diamond(thumb_c, 14.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.30))
		_draw_diamond(thumb_c, 10.0, Color(0.06, 0.05, 0.04, 0.96))
		_draw_diamond(thumb_c, 7.2, accent_color.lightened(0.25))


var _item_data: ItemData
var _customer_data: CustomerData
var _customer_node: Node3D
var _original_step: int = 3
var _offered_step: int = 2
var _tolerance: int = 0
var _resolved: bool = false
var _showing_intro: bool = false

var _bold_font: FontVariation
var _root: Control
var _fade_rect: ColorRect
var _content: VBoxContainer
var _intro_panel: PanelContainer
var _gauge: HaggleGauge
var _price_lbl: Label
var _diff_lbl: Label
var _chance_lbl: Label


static func compute_haggle_accept_chance(offered_step: int, tolerance: int, original_step: int = 3) -> float:
	# Offering the exact same price the customer already balked at almost never works
	var steps_dropped: int = original_step - offered_step
	if steps_dropped <= 0:
		return 0.05

	var eff_step: int = offered_step - tolerance
	var base: float
	match eff_step:
		5, 6, 7, 8, 9, 10:
			base = 0.05
		4:
			base = 0.10
		3:
			base = 0.22
		2:
			base = 0.38
		1:
			base = 0.56
		0:
			base = 0.74
		-1:
			base = 0.84
		-2:
			base = 0.91
		-3:
			base = 0.96
		_:
			base = 1.0

	# Sticker-shock penalty when customer was initially hit with a steep markup (+4 or +5)
	var shock_penalty: float = 0.0
	if original_step >= 5:
		shock_penalty = 0.19 if offered_step >= 0 else 0.10
	elif original_step == 4:
		shock_penalty = 0.09 if offered_step >= 0 else 0.04

	# Barely budging by 1 step feels stingy
	var stingy_penalty: float = 0.10 if steps_dropped == 1 else 0.0

	var relief: float = StoryManager.get_storefront_price_relief() if is_instance_valid(StoryManager) else 0.0
	var card_mod: float = 0.0
	if is_instance_valid(StoryManager):
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_UNRUSHED_HOUR):
			card_mod += 0.15
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			card_mod -= 0.15

	# Hard ceiling: base retail price (step >= 0) is never guaranteed, especially after +5 gouging
	var max_cap: float = 1.0
	if original_step >= 5:
		max_cap = 0.72 if offered_step >= 0 else 0.95
	elif original_step == 4:
		max_cap = 0.82 if offered_step >= 0 else 0.98
	elif offered_step >= 0:
		max_cap = 0.90

	return clampf(base - shock_penalty - stingy_penalty + (relief * 0.65) + card_mod, 0.05, max_cap)


func setup(item_data: ItemData, customer_data: CustomerData, customer_node: Node3D = null) -> void:
	_item_data = item_data
	_customer_data = customer_data
	_customer_node = customer_node
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
	add_to_group("minigame_overlay_active")
	add_to_group("haggle_overlay_active")

	_bold_font = FontVariation.new()
	_bold_font.base_font = INDER_FONT
	_bold_font.variation_embolden = 0.55

	_build_ui()
	_refresh_ui()
	var already_seen: bool = is_instance_valid(CharacterProgressionManager) and bool(CharacterProgressionManager.get_world_flag("haggle_tutorial_seen", false))
	_showing_intro = Juice.are_minigame_tutorials_enabled() and not already_seen
	_intro_panel.visible = _showing_intro
	_content.visible = not _showing_intro
	if _showing_intro:
		Juice.pop_panel_in(_intro_panel)

	# Quick black fade transition into haggle
	_fade_rect.color.a = 0.85
	var ftw := create_tween()
	ftw.tween_property(_fade_rect, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _resolved or not is_instance_valid(_customer_node):
		return
	var cam := get_viewport().get_camera_3d()
	if not is_instance_valid(cam):
		return
	var target_pos := _customer_node.global_position + Vector3(0.0, 1.35, 0.0)
	var marker := _customer_node.get_node_or_null("SpeechMarker") as Node3D
	if is_instance_valid(marker):
		target_pos = marker.global_position - Vector3(0.0, 0.22, 0.0)
	if cam.global_position.distance_squared_to(target_pos) > 0.01:
		var target_basis := cam.global_transform.looking_at(target_pos, Vector3.UP).basis
		cam.global_transform.basis = cam.global_transform.basis.slerp(target_basis, clampf(delta * 7.5, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if _resolved:
		return
	if event is InputEventMouseMotion:
		# Keep camera smoothly locked onto the customer while haggling
		get_viewport().set_input_as_handled()
		return
	if _showing_intro:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode in [KEY_F, KEY_SPACE, KEY_ENTER]:
				get_viewport().set_input_as_handled()
				_dismiss_intro()
			elif event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_decline_haggle()
		elif event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_dismiss_intro()
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			_nudge_step(1)
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			_nudge_step(-1)
			return
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			# Block tending to other customers while haggling
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_LEFT, KEY_A:
				get_viewport().set_input_as_handled()
				_nudge_step(-1)
			KEY_RIGHT, KEY_D:
				get_viewport().set_input_as_handled()
				_nudge_step(1)
			KEY_F, KEY_ENTER:
				get_viewport().set_input_as_handled()
				_confirm_offer()
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_decline_haggle()


func _dismiss_intro() -> void:
	if not _showing_intro:
		return
	_showing_intro = false
	_intro_panel.visible = false
	_content.visible = true
	if is_instance_valid(CharacterProgressionManager):
		CharacterProgressionManager.set_world_flag("haggle_tutorial_seen", true)
	Juice.play_sfx("tab_switch", 1.15)


func _nudge_step(delta: int) -> void:
	if _resolved:
		return
	var max_offer := maxi(ItemData.MIN_STEP, _original_step - 1)
	var next_st := clampi(_offered_step + delta, ItemData.MIN_STEP, max_offer)
	if next_st != _offered_step:
		_offered_step = next_st
		Juice.play_sfx("ui_hover", 1.05 + float(_offered_step) * 0.03, -4.0)
		_refresh_ui()


func _price_for_step(st: int) -> float:
	if _item_data == null:
		return 0.0
	return _item_data.get_price_for_step(st)


func _refresh_ui() -> void:
	if _item_data == null:
		return
	var offered_price := _price_for_step(_offered_step)
	var orig_price := _price_for_step(_original_step)
	var chance := compute_haggle_accept_chance(_offered_step, _tolerance, _original_step)
	var pct := int(roundf(chance * 100.0))

	var col := COL_GOOD if chance >= 0.75 else (COL_WARN if chance >= 0.45 else COL_BAD)

	_gauge.min_step = ItemData.MIN_STEP
	_gauge.max_step = ItemData.MAX_STEP
	_gauge.original_step = _original_step
	_gauge.current_step = _offered_step
	_gauge.accent_color = col
	_gauge.queue_redraw()

	_price_lbl.text = "₱%.2f" % offered_price
	var savings := maxf(0.0, orig_price - offered_price)
	_diff_lbl.text = "-₱%.2f off" % savings
	_diff_lbl.add_theme_color_override("font_color", COL_GOOD)

	_chance_lbl.text = "%d%%" % pct
	_chance_lbl.add_theme_color_override("font_color", col)


func _confirm_offer() -> void:
	if _resolved:
		return
	_resolved = true
	var chance := compute_haggle_accept_chance(_offered_step, _tolerance, _original_step)
	var accepted := randf() < chance
	Juice.play_sfx("pickup" if accepted else "error", 1.18 if accepted else 0.90, 0.5)
	_finish(accepted, _offered_step)


func _decline_haggle() -> void:
	if _resolved:
		return
	_resolved = true
	Juice.play_sfx("tab_switch", 0.85, -3.0)
	_finish(false, _original_step)


func _finish(accepted: bool, offered_step: int) -> void:
	if is_in_group("minigame_overlay_active"):
		remove_from_group("minigame_overlay_active")
	if is_in_group("haggle_overlay_active"):
		remove_from_group("haggle_overlay_active")
	haggle_finished.emit(accepted, offered_step)
	queue_free()


func _make_outlined_label(txt: String, font_res: Font, sz: int, col: Color, outline_sz: int = 5) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Soft fullscreen vignette (overscanned, no heavy box)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.offset_left = -24
	vig.offset_top = -24
	vig.offset_right = 24
	vig.offset_bottom = 24
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vig.material = mat
	_root.add_child(vig)

	# Frameless floating haggle HUD anchored cleanly at lower-center
	_content = VBoxContainer.new()
	_content.anchor_left = 0.5
	_content.anchor_right = 0.5
	_content.anchor_top = 1.0
	_content.anchor_bottom = 1.0
	_content.offset_left = -330
	_content.offset_right = 330
	_content.offset_top = -235
	_content.offset_bottom = -28
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 8)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)

	var iname := _item_data.item_name if _item_data else "Item"
	var title := _make_outlined_label("Haggle  •  %s" % iname, _bold_font, 24, COL_GOLD_SOFT, 5)
	_content.add_child(title)

	# Compact horizontal readout: Offered Price + Acceptance %
	var readout := HBoxContainer.new()
	readout.alignment = BoxContainer.ALIGNMENT_CENTER
	readout.add_theme_constant_override("separation", 24)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(readout)

	_price_lbl = _make_outlined_label("₱0.00", _bold_font, 40, COL_CREAM, 6)
	readout.add_child(_price_lbl)

	var chance_wrap := HBoxContainer.new()
	chance_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	chance_wrap.add_theme_constant_override("separation", 6)
	chance_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_child(chance_wrap)

	_chance_lbl = _make_outlined_label("80%", _bold_font, 32, COL_GOOD, 5)
	chance_wrap.add_child(_chance_lbl)

	var chance_sub := _make_outlined_label("chance", INDER_FONT, 17, COL_CREAM_MUTED, 4)
	chance_wrap.add_child(chance_sub)

	# Long frameless Haggle Gauge
	_gauge = HaggleGauge.new()
	_gauge.custom_minimum_size = Vector2(620, 52)
	_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_gauge)

	_diff_lbl = _make_outlined_label("", INDER_FONT, 16, COL_GOOD, 4)
	_content.add_child(_diff_lbl)

	var hint := _make_outlined_label("Scroll to adjust   •   [F] Offer   •   [Esc] Let Them Go", INDER_FONT, 16, COL_CREAM_MUTED, 4)
	_content.add_child(hint)

	# How-to-Play intro panel (respects Minigame Tutorials setting)
	_intro_panel = PanelContainer.new()
	_intro_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intro_panel.custom_minimum_size = Vector2(540, 250)
	_intro_panel.offset_left = -270
	_intro_panel.offset_right = 270
	_intro_panel.offset_top = -125
	_intro_panel.offset_bottom = 125
	var istyle := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.95), 14, 28, 22)
	istyle.border_color = Color(0.92, 0.72, 0.32, 0.92)
	istyle.set_border_width_all(2)
	_intro_panel.add_theme_stylebox_override("panel", istyle)
	_intro_panel.visible = false
	_root.add_child(_intro_panel)

	var iv := VBoxContainer.new()
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_theme_constant_override("separation", 14)
	_intro_panel.add_child(iv)

	var ititle := Label.new()
	ititle.text = "How to Play: Haggle (Tawad)"
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ititle.add_theme_font_override("font", _bold_font)
	ititle.add_theme_font_size_override("font_size", 30)
	ititle.add_theme_color_override("font_color", COL_GOLD_SOFT)
	iv.add_child(ititle)

	var idesc := Label.new()
	idesc.text = "This customer hesitated at the price! Use the Scroll Wheel to lower your offer for this sale only — lower prices raise their acceptance chance. Press [F] to Offer or [Esc] to let them go."
	idesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idesc.add_theme_font_override("font", INDER_FONT)
	idesc.add_theme_font_size_override("font_size", 20)
	idesc.add_theme_color_override("font_color", COL_CREAM)
	iv.add_child(idesc)

	var ihint := Label.new()
	ihint.text = "Press [F], [Space], or Click to begin"
	ihint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ihint.add_theme_font_override("font", _bold_font)
	ihint.add_theme_font_size_override("font_size", 17)
	ihint.add_theme_color_override("font_color", COL_GOLD_SOFT)
	iv.add_child(ihint)

	# Quick black fade curtain on top
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.015, 0.012, 0.010, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)
