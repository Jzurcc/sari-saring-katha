class_name MayariTallyOverlay
extends CanvasLayer

## Hades-inspired split-screen ritual for Reyna Mayari's Nightly Tally:
## - Beat 1 & Beat 2 share the EXACT same 3 card slots inside the center frame so confirming
##   your tribute physically flips the 3 shadow previews in place to reveal tomorrow's cards.
## - A single unified Silver Ledger Gauge at the bottom combines overall ledger progress
##   (solid antique gold) with tonight's interactive tribute (animated pastel stripes),
##   diamond end-caps & handlebar thumb, threshold indicators below, and a floating
##   [< [coin] amount >] control riding directly on top of the adjustable thumb line.

signal completed(offer_amount: float, tier: String, selected_card_ids: Array)

const MAYARI_SPRITE_PATH := "res://Assets/characters/sprites/ReynaMayariUI.png"
const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")
const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

# Sari-Saring Katha Brand Palette
const COL_ESPRESSO := Color(0.082, 0.074, 0.066, 0.94)
const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.82)
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.9)
const COL_STAT_POS := Color(0.56, 0.92, 0.52, 1.0)
const COL_STAT_NEG := Color(0.96, 0.48, 0.45, 1.0)
const COL_BOLD_CREAM := "#FFF6E5"

# Soft Pastel Tier Palette (Meager / Fair / Lavish / Sealed)
const COL_TIER_MEAGER := Color(0.52, 0.72, 0.92, 1.0) # Soft pastel omen blue
const COL_TIER_MEAGER_BRIGHT := Color(0.74, 0.87, 0.99, 1.0)
const COL_TIER_FAIR := Color(0.88, 0.79, 0.58, 1.0) # Soft buttercream gold
const COL_TIER_FAIR_BRIGHT := Color(0.98, 0.92, 0.76, 1.0)
const COL_TIER_LAVISH := Color(0.95, 0.82, 0.46, 1.0) # Soft warm favor gold
const COL_TIER_LAVISH_BRIGHT := Color(1.0, 0.93, 0.68, 1.0)
const COL_TIER_SEALED := Color(0.96, 0.91, 0.76, 1.0) # Luminous champagne
const COL_TIER_SEALED_BRIGHT := Color(1.0, 0.98, 0.90, 1.0)

## Rotated mystery diamond for Beat 1 preview shadow cards (matches Beat 2 emblem footprint).
class MysteryDiamond extends Control:
	var border_col: Color = Color(0.88, 0.79, 0.58, 0.72)
	var fill_col: Color = Color(0.06, 0.055, 0.05, 0.94)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		var pts := PackedVector2Array([
			c + Vector2(0.0, -r),
			c + Vector2(r, 0.0),
			c + Vector2(0.0, r),
			c + Vector2(-r, 0.0),
		])
		draw_colored_polygon(pts, fill_col)
		var ring := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		draw_polyline(ring, border_col, 2.0, true)
		var r_in := r * 0.78
		var in_pts := PackedVector2Array([
			c + Vector2(0.0, -r_in),
			c + Vector2(r_in, 0.0),
			c + Vector2(0.0, r_in),
			c + Vector2(-r_in, 0.0),
			c + Vector2(0.0, -r_in),
		])
		draw_polyline(in_pts, Color(border_col.r, border_col.g, border_col.b, 0.35), 1.0, true)

## Unified Silver Ledger + Interactive Tribute Gauge:
## - Paid ledger progress (solid warm antique gold) from 0 .. paid_x
## - Tonight's adjustable tribute (animated diagonal-striped pastel fill) from paid_x .. cur_x
## - Wallet-reachable zone subtly lit from cur_x .. max_offer_x
## - Diamond end-caps + glowing diamond handlebar thumb at cur_x
## - Floating [< [coin] amount >] pill riding directly on top of the thumb line
## - Thin vertical FAIR & LAVISH threshold lines with collision-free peso indicators below
class UnifiedLedgerGauge extends Control:
	signal value_changed(new_offer: float)
	signal nudge_requested(delta: float)
	signal milestone_hovered(milestone: Dictionary)

	const BAR_Y := 34.0
	const BAR_H := 22.0

	var total_paid: float = 0.0
	var goal: float = 2000.0
	var current_offer: float = 0.0
	var max_offer: float = 100.0
	var min_thresh: float = 40.0
	var gen_thresh: float = 65.0
	var fill_color: Color = Color(0.88, 0.79, 0.58, 1.0)
	var border_color: Color = Color(0.98, 0.92, 0.76, 0.92)
	var peso_tex: Texture2D = null
	var bold_font: Font = null
	var interactive: bool = true
	var milestones: Array[Dictionary] = []
	var _hovered_milestone_idx: int = -1
	var _pulse_time: float = 0.0
	var _pip_burst_timers: Dictionary = {} # idx -> float (0..1)
	var _prev_tonight_ids: Array[String] = []

	var _dragging: bool = false

	func _update_milestone_hover(local_pos: Vector2) -> void:
		var g := maxf(1.0, goal)
		var best_idx := -1
		var best_dist := 18.0
		for i in range(milestones.size()):
			var m_amt := float(milestones[i].get("amount", 0.0))
			if m_amt <= 0.0 or m_amt >= g - 0.01:
				continue
			var mx := _ratio_to_x(m_amt / g)
			var d := local_pos.distance_to(Vector2(mx, BAR_Y + BAR_H * 0.5))
			if d < best_dist:
				best_dist = d
				best_idx = i
		if best_idx != _hovered_milestone_idx:
			_hovered_milestone_idx = best_idx
			milestone_hovered.emit(milestones[best_idx] if best_idx >= 0 else {})
			_queue_all_redraw()
	var _stripe_scroll: float = 0.0
	var _preview_rect: ColorRect
	var _stripe_mat: ShaderMaterial
	var _overlay_canvas: Control

	# Floating thumb readout: [<] [coin] [amount] [>] riding above cur_x
	var _thumb_box: HBoxContainer
	var _minus_btn: Button
	var _plus_btn: Button
	var _amount_lbl: Label

	static var _gauge_shader: Shader = null

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_preview_rect = ColorRect.new()
		_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_rect.color = Color.WHITE
		if _gauge_shader == null:
			_gauge_shader = Shader.new()
			_gauge_shader.code = """
shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(0.88, 0.79, 0.58, 1.0);
uniform float scroll_offset = 0.0;
void fragment() {
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / 20.0 - scroll_offset;
	float band = smoothstep(0.40, 0.48, fract(diag)) * (1.0 - smoothstep(0.86, 0.94, fract(diag)));
	float sheen = smoothstep(0.35, 0.0, UV.y) * 0.14;
	vec3 col = base_color.rgb + vec3(band * 0.18 + sheen);
	COLOR = vec4(col, base_color.a);
}
"""
		_stripe_mat = ShaderMaterial.new()
		_stripe_mat.shader = _gauge_shader
		_preview_rect.material = _stripe_mat
		add_child(_preview_rect)

		# Foreground canvas drawn ON TOP of _preview_rect so milestone pips & thumb stay above the moving tally bar
		_overlay_canvas = Control.new()
		_overlay_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay_canvas.draw.connect(_draw_foreground)
		add_child(_overlay_canvas)

		# Floating [< [coin] 75 >] riding right on top of the thumb line
		_thumb_box = HBoxContainer.new()
		_thumb_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_thumb_box.add_theme_constant_override("separation", 4)
		_thumb_box.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(_thumb_box)

		_minus_btn = _make_tiny_arrow("‹")
		_minus_btn.pressed.connect(func(): nudge_requested.emit(-5.0))
		_thumb_box.add_child(_minus_btn)

		var coin := TextureRect.new()
		coin.texture = peso_tex
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(16, 16)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb_box.add_child(coin)

		_amount_lbl = Label.new()
		_amount_lbl.text = "0"
		_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_amount_lbl.add_theme_font_override("font", bold_font if bold_font else UIStyle.FONT_INDER)
		_amount_lbl.add_theme_font_size_override("font_size", 18)
		_amount_lbl.add_theme_color_override("font_color", border_color)
		_amount_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.045, 0.03, 0.95))
		_amount_lbl.add_theme_constant_override("outline_size", 3)
		_amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb_box.add_child(_amount_lbl)

		_plus_btn = _make_tiny_arrow("›")
		_plus_btn.pressed.connect(func(): nudge_requested.emit(5.0))
		_thumb_box.add_child(_plus_btn)

		resized.connect(_sync_visuals)
		mouse_exited.connect(func():
			if _hovered_milestone_idx != -1:
				_hovered_milestone_idx = -1
				milestone_hovered.emit({})
				_queue_all_redraw()
		)

	func _make_tiny_arrow(glyph: String) -> Button:
		var b := Button.new()
		b.text = glyph
		b.custom_minimum_size = Vector2(22, 22)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var s := UIStyle.create_flat_stylebox(Color(0.11, 0.095, 0.082, 0.92), 5, 0, 0)
		s.border_color = Color(0.835, 0.624, 0.278, 0.48)
		s.set_border_width_all(1)
		var h: StyleBoxFlat = s.duplicate()
		h.bg_color = Color(0.22, 0.18, 0.13, 0.98)
		h.border_color = Color(1.0, 0.92, 0.72, 0.95)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", s)
		b.add_theme_stylebox_override("disabled", s)
		b.add_theme_font_override("font", UIStyle.FONT_INDER)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color(0.86, 0.80, 0.70, 0.90))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		return b

	func set_interactive(enabled: bool) -> void:
		interactive = enabled
		if is_instance_valid(_minus_btn):
			_minus_btn.disabled = not enabled
		if is_instance_valid(_plus_btn):
			_plus_btn.disabled = not enabled

	func _queue_all_redraw() -> void:
		queue_redraw()
		if is_instance_valid(_overlay_canvas):
			_overlay_canvas.queue_redraw()

	func _process(delta: float) -> void:
		_stripe_scroll += delta * 0.55
		if _stripe_mat:
			_stripe_mat.set_shader_parameter("scroll_offset", _stripe_scroll)
			_stripe_mat.set_shader_parameter("base_color", fill_color)
		var needs_redraw := not _prev_tonight_ids.is_empty()
		if needs_redraw:
			_pulse_time += delta
		var expired: Array = []
		for k in _pip_burst_timers.keys():
			_pip_burst_timers[k] = float(_pip_burst_timers[k]) - delta * 2.2
			if float(_pip_burst_timers[k]) <= 0.0:
				expired.append(k)
			needs_redraw = true
		for k in expired:
			_pip_burst_timers.erase(k)
		if needs_redraw:
			_queue_all_redraw()

	func _ratio_to_x(r: float) -> float:
		var pad := 2.0
		return pad + maxf(0.0, size.x - pad * 2.0) * clampf(r, 0.0, 1.0)

	func _sync_visuals() -> void:
		if not is_instance_valid(_preview_rect):
			return
		var g := maxf(1.0, goal)
		var paid_x := _ratio_to_x(total_paid / g)
		var cur_x := _ratio_to_x((total_paid + current_offer) / g)
		var pad := 2.0
		var w := maxf(0.0, cur_x - paid_x)
		_preview_rect.position = Vector2(paid_x, BAR_Y + pad)
		_preview_rect.size = Vector2(w, BAR_H - pad * 2.0)
		_preview_rect.visible = w > 1.0

		if is_instance_valid(_thumb_box):
			_amount_lbl.text = "%d" % int(roundf(current_offer))
			_amount_lbl.add_theme_color_override("font_color", border_color)
			var bw := maxf(_thumb_box.get_combined_minimum_size().x, 96.0)
			var bx := clampf(cur_x - bw * 0.5, 0.0, maxf(0.0, size.x - bw))
			_thumb_box.position = Vector2(bx, 2.0)
			_thumb_box.size = Vector2(bw, 24.0)

	func set_state(paid: float, g: float, cur_offer: float, mx_offer: float, min_t: float, gen_t: float, col: Color, b_col: Color) -> void:
		total_paid = paid
		goal = maxf(1.0, g)
		current_offer = cur_offer
		max_offer = mx_offer
		min_thresh = min_t
		gen_thresh = gen_t
		fill_color = col
		border_color = b_col

		# Detect milestone pips newly touched by tonight's offer preview for burst animation
		var cur_tonight: Array[String] = []
		for i in range(milestones.size()):
			var m: Dictionary = milestones[i]
			var m_amt := float(m.get("amount", 0.0))
			if m_amt <= 0.0 or m_amt >= goal - 0.01:
				continue
			var already := total_paid >= m_amt - 0.01
			var tonight := (not already) and (total_paid + current_offer >= m_amt - 0.01)
			if tonight:
				var mid := str(m.get("id", str(i)))
				cur_tonight.append(mid)
				if not (mid in _prev_tonight_ids):
					_pip_burst_timers[i] = 1.0
		_prev_tonight_ids = cur_tonight

		_sync_visuals()
		_queue_all_redraw()

	func pop_amount() -> void:
		if not is_instance_valid(_amount_lbl):
			return
		_amount_lbl.pivot_offset = _amount_lbl.size * 0.5
		var tw := create_tween()
		tw.tween_property(_amount_lbl, "scale", Vector2(1.14, 1.14), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_amount_lbl, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			_update_milestone_hover(mm.position)
			if interactive and max_offer > 0.01 and _dragging:
				_emit_from_x(mm.position.x)
			return
		if not interactive or max_offer <= 0.01:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed and mb.position.y >= BAR_Y - 10.0 and mb.position.y <= BAR_Y + BAR_H + 14.0:
					_dragging = true
					_emit_from_x(mb.position.x)
				elif not mb.pressed:
					_dragging = false

	func _emit_from_x(local_x: float) -> void:
		var g := maxf(1.0, goal)
		var paid_x := _ratio_to_x(total_paid / g)
		var max_x := _ratio_to_x((total_paid + max_offer) / g)
		var span := maxf(1.0, max_x - paid_x)
		var ratio := clampf((local_x - paid_x) / span, 0.0, 1.0)
		value_changed.emit(ratio * max_offer)

	func _draw() -> void:
		var bar_rect := Rect2(0.0, BAR_Y, size.x, BAR_H)
		var g := maxf(1.0, goal)
		var pad := 2.0
		var paid_x := _ratio_to_x(total_paid / g)
		var cur_x := _ratio_to_x((total_paid + current_offer) / g)
		var max_x := _ratio_to_x((total_paid + max_offer) / g)

		# Deep obsidian full Silver Ledger track
		draw_rect(bar_rect, Color(0.04, 0.036, 0.032, 0.96), true)

		# Subtle wallet-reachable zone between paid_x and max_x
		if max_x > paid_x + 1.0:
			draw_rect(Rect2(paid_x, BAR_Y + pad, max_x - paid_x, BAR_H - pad * 2.0), Color(1.0, 0.92, 0.76, 0.065), true)

		# Subtle ruler notches along the full ledger track
		for i in range(1, 15):
			var nx := size.x * (float(i) / 15.0)
			draw_line(Vector2(nx, BAR_Y + 4.5), Vector2(nx, BAR_Y + BAR_H - 4.5), Color(1.0, 0.92, 0.78, 0.08), 1.0, true)

		# Solid warm antique gold for already-paid ledger progress
		if paid_x > pad + 1.0:
			draw_rect(Rect2(pad, BAR_Y + pad, paid_x - pad, BAR_H - pad * 2.0), Color(0.76, 0.59, 0.32, 0.94), true)
			draw_rect(Rect2(pad, BAR_Y + pad, paid_x - pad, 4.0), Color(1.0, 0.92, 0.72, 0.22), true)

		# Crisp vertical cap marking max affordable tonight
		if max_x < size.x - 4.0 and max_x > paid_x + 2.0:
			draw_line(Vector2(max_x, BAR_Y + 1.0), Vector2(max_x, BAR_Y + BAR_H - 1.0), Color(0.86, 0.78, 0.64, 0.38), 1.5, true)

	func _draw_foreground() -> void:
		if not is_instance_valid(_overlay_canvas):
			return
		var bar_rect := Rect2(0.0, BAR_Y, size.x, BAR_H)
		var g := maxf(1.0, goal)
		var pad := 2.0
		var paid_x := _ratio_to_x(total_paid / g)
		var cur_x := _ratio_to_x((total_paid + current_offer) / g)

		# Crisp outer & inner gold frame
		var frame_col := Color(0.835, 0.624, 0.278, 0.85)
		_overlay_canvas.draw_rect(bar_rect, frame_col, false, 2.0)
		_overlay_canvas.draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)

		# End-cap diamond ornaments (left & right)
		_draw_diamond_on(_overlay_canvas, Vector2(0.0, BAR_Y + BAR_H * 0.5), 4.5, frame_col)
		_draw_diamond_on(_overlay_canvas, Vector2(size.x, BAR_Y + BAR_H * 0.5), 4.5, frame_col)

		# Seam line where already-paid meets tonight's tribute
		if paid_x > pad + 2.0:
			_overlay_canvas.draw_line(Vector2(paid_x, BAR_Y - 2.0), Vector2(paid_x, BAR_Y + BAR_H + 2.0), Color(1.0, 0.94, 0.80, 0.65), 1.5, true)

		# Thin vertical threshold lines & diamond pips below the bar (no text labels)
		var show_min := min_thresh > 0.0 and total_paid + min_thresh < g - 0.01
		var show_gen := gen_thresh > min_thresh + 0.01 and total_paid + gen_thresh < g - 0.01
		var min_x := _ratio_to_x((total_paid + min_thresh) / g)
		var gen_x := _ratio_to_x((total_paid + gen_thresh) / g)

		if show_min:
			var reached_min := current_offer >= min_thresh - 0.01
			_draw_threshold_pip(_overlay_canvas, min_x, reached_min, Color(0.98, 0.92, 0.76, 1.0))
		if show_gen:
			var reached_gen := current_offer >= gen_thresh - 0.01
			_draw_threshold_pip(_overlay_canvas, gen_x, reached_gen, Color(1.0, 0.93, 0.68, 1.0))

		# Milestone diamond pips ON TOP of the moving tally bar (15% / 30% / 50% / 75%)
		for i in range(milestones.size()):
			var m: Dictionary = milestones[i]
			var m_amt := float(m.get("amount", 0.0))
			if m_amt <= 0.0 or m_amt >= g - 0.01:
				continue
			var mx := _ratio_to_x(m_amt / g)
			var pip_c := Vector2(mx, BAR_Y + BAR_H * 0.5)
			var already_unlocked := total_paid >= m_amt - 0.01
			var unlocked_tonight := (not already_unlocked) and (total_paid + current_offer >= m_amt - 0.01)
			var pip_col := Color(0.56, 0.96, 0.62, 1.0) if unlocked_tonight else (Color(1.0, 0.88, 0.52, 0.96) if already_unlocked else Color(0.70, 0.60, 0.44, 0.58))
			var pulse := 0.5 + 0.5 * sin(_pulse_time * 5.2 + float(i) * 0.9)
			var pip_r := 6.6 if _hovered_milestone_idx == i else ((5.8 + pulse * 1.1) if unlocked_tonight else (5.2 if already_unlocked else 4.2))
			_overlay_canvas.draw_line(Vector2(mx, BAR_Y + 1.0), Vector2(mx, BAR_Y + BAR_H - 1.0), Color(pip_col.r, pip_col.g, pip_col.b, 0.82 if unlocked_tonight else 0.45), 1.6 if unlocked_tonight else 1.2, true)
			if unlocked_tonight:
				var halo_r := pip_r + 4.2 + pulse * 2.4
				_draw_diamond_on(_overlay_canvas, pip_c, halo_r, Color(0.56, 0.98, 0.64, 0.24 + pulse * 0.16))
				_draw_diamond_outline_on(_overlay_canvas, pip_c, halo_r, Color(0.78, 1.0, 0.82, 0.58 + pulse * 0.30), 1.4)
				_overlay_canvas.draw_line(Vector2(mx, BAR_Y - 5.0), Vector2(mx, BAR_Y - 1.0), Color(0.72, 1.0, 0.78, 0.75 + pulse * 0.25), 1.6, true)
				_overlay_canvas.draw_line(Vector2(mx, BAR_Y + BAR_H + 1.0), Vector2(mx, BAR_Y + BAR_H + 5.0), Color(0.72, 1.0, 0.78, 0.75 + pulse * 0.25), 1.6, true)
			if _pip_burst_timers.has(i):
				var bt := clampf(float(_pip_burst_timers[i]), 0.0, 1.0)
				var burst_r := pip_r + (1.0 - bt) * 18.0
				_draw_diamond_outline_on(_overlay_canvas, pip_c, burst_r, Color(0.86, 1.0, 0.82, bt * 0.95), 2.2)
			_draw_diamond_on(_overlay_canvas, pip_c, pip_r + 1.6, Color(0.05, 0.04, 0.035, 0.92))
			_draw_diamond_on(_overlay_canvas, pip_c, pip_r, pip_col)
			if unlocked_tonight:
				_draw_diamond_on(_overlay_canvas, pip_c, pip_r * 0.42, Color(0.96, 1.0, 0.94, 0.95))

		# Connector stem from floating readout down into glowing diamond handlebar thumb
		_overlay_canvas.draw_line(Vector2(cur_x, BAR_Y - 8.0), Vector2(cur_x, BAR_Y), Color(border_color.r, border_color.g, border_color.b, 0.72), 1.5, true)
		var ptr_c := Vector2(cur_x, BAR_Y + BAR_H * 0.5)
		_draw_diamond_on(_overlay_canvas, ptr_c, 10.5, Color(0.05, 0.04, 0.035, 0.98))
		_draw_diamond_on(_overlay_canvas, ptr_c, 7.8, fill_color.lightened(0.20))
		_draw_diamond_on(_overlay_canvas, ptr_c, 3.4, Color(1.0, 0.97, 0.90, 0.96))

	func _draw_threshold_pip(target: CanvasItem, x: float, reached: bool, lit_col: Color) -> void:
		var line_col := lit_col if reached else Color(0.78, 0.72, 0.62, 0.44)
		target.draw_line(Vector2(x, BAR_Y - 4.0), Vector2(x, BAR_Y + BAR_H + 11.0), line_col, 1.5, true)
		_draw_diamond_on(target, Vector2(x, BAR_Y + BAR_H + 11.0), 3.6, line_col)

	func _draw_diamond_on(target: CanvasItem, center: Vector2, r: float, col: Color) -> void:
		target.draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
		]), col)

	func _draw_diamond_outline_on(target: CanvasItem, center: Vector2, r: float, col: Color, width: float = 1.5) -> void:
		target.draw_polyline(PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
			center + Vector2(0.0, -r),
		]), col, width, true)

var _bold_font: FontVariation

var _player_money: float = 0.0
var _total_paid: float = 0.0
var _goal: float = 2000.0
var _min_amount: float = 40.0
var _generous_amount: float = 65.0
var _max_offer: float = 0.0
var _current_offer: float = 0.0
var _last_tier: String = ""
var _is_locked: bool = false
var _phase: int = 0 # 0 = offering, 1 = flipping, 2 = card_draft

var _root: Control
var _backdrop: ColorRect
var _header_banner: PanelContainer
var _center_frame: PanelContainer
var _mayari_portrait: TextureRect
var _header_title_lbl: Label
var _header_sub_lbl: Label

# Shared 3 Card Slots (EXACT same size & position in Beat 1 and Beat 2!)
var _card_slots: Array[Control] = []
var _shadow_rows: Array[Dictionary] = []

# Unified Bottom Ledger Gauge Dock + Overlapping Bottom-Right Offer Button
var _gauge_dock: VBoxContainer
var _unified_gauge: UnifiedLedgerGauge
var _scroll_hint_box: HBoxContainer
var _confirm_btn: Button
var _confirm_style: StyleBoxFlat

# Beat 2: Revealed Hades Boon Rows (placed inside the exact same _card_slots!)
var _card_rows: Array[PanelContainer] = []
var _card_data_list: Array[Dictionary] = []
var _callout_col: VBoxContainer
var _callout_tween: Tween = null
var _callout_anchor: Control = null
var _hovered_idx: int = -1
var _card_picked: bool = false
var _cards_ready: bool = false
var _rerolls_left: int = 0
var _max_rerolls: int = 0
var _max_card_picks: int = 1
var _selected_indices: Array[int] = []
var _confirmed_shifted_odds: bool = false
var _reroll_btn: Button
var _accept_cards_btn: Button
var _accept_style: StyleBoxFlat

var _confirmed_offer: float = 0.0
var _confirmed_tier: String = "balanced"
var _touched_milestone_ids: Array[String] = []
var _hovered_milestone_dict: Dictionary = {}

func setup(player_money: float, total_paid: float, goal: float, min_amount: float, generous_amount: float) -> void:
	_player_money = maxf(0.0, player_money)
	_total_paid = clampf(total_paid, 0.0, goal)
	_goal = maxf(1.0, goal)
	_min_amount = min_amount
	_generous_amount = generous_amount
	var remaining := maxf(0.0, _goal - _total_paid)
	_max_offer = minf(_player_money, remaining)
	_current_offer = 0.0

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65
	_build_ui()
	_refresh_offering_ui(false)
	_play_entrance()

func _input(event: InputEvent) -> void:
	if _phase != 0 or _is_locked:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge_offer(5.0)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge_offer(-5.0)
			get_viewport().set_input_as_handled()

# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Clean uniform dark backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.035, 0.028, 0.024, 0.74)
	_backdrop.modulate.a = 0.0
	_root.add_child(_backdrop)

	# ── 1. TOP WIDE TITLE BANNER ──
	_header_banner = PanelContainer.new()
	_header_banner.anchor_left = 0.220
	_header_banner.anchor_right = 0.800
	_header_banner.anchor_top = 0.030
	_header_banner.anchor_bottom = 0.148
	var header_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_DEEP, 6, 32, 10)
	header_style.border_color = COL_GOLD
	header_style.set_border_width_all(2)
	header_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	header_style.shadow_size = 16
	_header_banner.add_theme_stylebox_override("panel", header_style)
	_root.add_child(_header_banner)

	var header_v := VBoxContainer.new()
	header_v.alignment = BoxContainer.ALIGNMENT_CENTER
	header_v.add_theme_constant_override("separation", 3)
	_header_banner.add_child(header_v)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	header_v.add_child(title_row)

	var left_orn := Label.new()
	left_orn.text = "◈"
	left_orn.add_theme_font_size_override("font_size", 22)
	left_orn.add_theme_color_override("font_color", COL_GOLD)
	title_row.add_child(left_orn)

	_header_title_lbl = Label.new()
	_header_title_lbl.text = "T H E   S I L V E R   L E D G E R"
	_header_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_header_title_lbl.add_theme_font_size_override("font_size", 32)
	_header_title_lbl.add_theme_color_override("font_color", COL_CREAM)
	_header_title_lbl.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
	_header_title_lbl.add_theme_constant_override("outline_size", 4)
	title_row.add_child(_header_title_lbl)

	var right_orn := Label.new()
	right_orn.text = "◈"
	right_orn.add_theme_font_size_override("font_size", 22)
	right_orn.add_theme_color_override("font_color", COL_GOLD)
	title_row.add_child(right_orn)

	_header_sub_lbl = Label.new()
	_header_sub_lbl.text = "Set tonight's tribute to Reyna Mayari."
	_header_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_header_sub_lbl.add_theme_font_size_override("font_size", 16)
	_header_sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	header_v.add_child(_header_sub_lbl)

	# ── 2. SHARED HADES CENTER FRAME (Exact same 3 card slots across Beat 1 -> Beat 2!) ──
	_center_frame = PanelContainer.new()
	_center_frame.anchor_left = 0.220
	_center_frame.anchor_right = 0.800
	_center_frame.anchor_top = 0.175
	_center_frame.anchor_bottom = 0.855
	var frame_style := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.046, 0.94), 8, 24, 14)
	frame_style.border_color = Color(0.835, 0.624, 0.278, 0.78)
	frame_style.set_border_width_all(2)
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	frame_style.shadow_size = 22
	_center_frame.add_theme_stylebox_override("panel", frame_style)
	_root.add_child(_center_frame)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 10)
	_center_frame.add_child(main_col)

	# 3 Shared Card Slots — IDENTICAL height & position in Beat 1 (shadow) and Beat 2 (revealed)
	var slots_col := VBoxContainer.new()
	slots_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_col.add_theme_constant_override("separation", 10)
	main_col.add_child(slots_col)

	_card_slots.clear()
	_shadow_rows.clear()
	for i in range(3):
		var slot := MarginContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size = Vector2(0, 102)
		slots_col.add_child(slot)
		_card_slots.append(slot)

		var s_row := _create_preview_shadow_row(i)
		slot.add_child(s_row["panel"])
		_shadow_rows.append(s_row)

	# Unified Silver Ledger + Tribute Gauge Dock at the bottom of the frame
	_gauge_dock = VBoxContainer.new()
	_gauge_dock.add_theme_constant_override("separation", 2)
	main_col.add_child(_gauge_dock)

	var dock_sep := ColorRect.new()
	dock_sep.custom_minimum_size = Vector2(0, 1)
	dock_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_sep.color = Color(0.835, 0.624, 0.278, 0.22)
	_gauge_dock.add_child(dock_sep)

	_unified_gauge = UnifiedLedgerGauge.new()
	_unified_gauge.peso_tex = PESO_ICON
	_unified_gauge.bold_font = _bold_font
	_unified_gauge.custom_minimum_size = Vector2(0, 74)
	_unified_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unified_gauge.milestones = StoryManager.LEDGER_MILESTONES
	_unified_gauge.value_changed.connect(_on_slider_changed)
	_unified_gauge.nudge_requested.connect(_nudge_offer)
	_unified_gauge.milestone_hovered.connect(_on_milestone_hovered)
	_gauge_dock.add_child(_unified_gauge)

	# Scroll keybind indicator (rounded square with ↕) tucked cleanly below the gauge bar
	_scroll_hint_box = HBoxContainer.new()
	_scroll_hint_box.anchor_left = 0.220
	_scroll_hint_box.anchor_right = 0.220
	_scroll_hint_box.anchor_top = 0.855
	_scroll_hint_box.anchor_bottom = 0.855
	_scroll_hint_box.offset_left = 18.0
	_scroll_hint_box.offset_right = 190.0
	_scroll_hint_box.offset_top = 8.0
	_scroll_hint_box.offset_bottom = 38.0
	_scroll_hint_box.z_index = 12
	_scroll_hint_box.add_theme_constant_override("separation", 8)
	_scroll_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scroll_hint_box)

	var sq_badge := PanelContainer.new()
	sq_badge.custom_minimum_size = Vector2(28, 28)
	sq_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sq_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sq_style := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.94), 6, 0, 0)
	sq_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.82)
	sq_style.set_border_width_all(1)
	sq_style.border_width_bottom = 2
	sq_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sq_style.shadow_size = 6
	sq_badge.add_theme_stylebox_override("panel", sq_style)
	_scroll_hint_box.add_child(sq_badge)

	var sym_lbl := Label.new()
	sym_lbl.text = "↕"
	sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sym_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sym_lbl.add_theme_font_override("font", _bold_font)
	sym_lbl.add_theme_font_size_override("font_size", 16)
	sym_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	sym_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq_badge.add_child(sym_lbl)

	var scroll_lbl := Label.new()
	scroll_lbl.text = "Scroll to adjust"
	scroll_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scroll_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	scroll_lbl.add_theme_font_size_override("font_size", 13)
	scroll_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	scroll_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_hint_box.add_child(scroll_lbl)

	# ── 3. BOTTOM-RIGHT OVERLAPPING OFFER BUTTON (Straddling the frame's bottom border!) ──
	_confirm_btn = Button.new()
	_confirm_btn.anchor_left = 0.800
	_confirm_btn.anchor_right = 0.800
	_confirm_btn.anchor_top = 0.855
	_confirm_btn.anchor_bottom = 0.855
	_confirm_btn.offset_left = -246.0
	_confirm_btn.offset_right = -18.0
	_confirm_btn.offset_top = -24.0
	_confirm_btn.offset_bottom = 24.0
	_confirm_btn.z_index = 12
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_confirm_btn.add_theme_font_override("font", _bold_font)
	_confirm_btn.add_theme_font_size_override("font_size", 18)
	_confirm_style = UIStyle.create_flat_stylebox(Color(0.42, 0.34, 0.20, 0.98), 8, 20, 8)
	_confirm_style.border_color = COL_CREAM
	_confirm_style.set_border_width_all(2)
	_confirm_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	_confirm_style.shadow_size = 14
	_confirm_style.shadow_offset = Vector2(0, 4)
	_apply_confirm_style(COL_TIER_FAIR)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_root.add_child(_confirm_btn)

	# ── 3B. BEAT 2 REROLL & ACCEPT CARDS BUTTONS (Straddling frame's bottom border) ──
	_reroll_btn = Button.new()
	_reroll_btn.anchor_left = 0.220
	_reroll_btn.anchor_right = 0.220
	_reroll_btn.anchor_top = 0.855
	_reroll_btn.anchor_bottom = 0.855
	_reroll_btn.offset_left = 18.0
	_reroll_btn.offset_right = 180.0
	_reroll_btn.offset_top = -28.0
	_reroll_btn.offset_bottom = 28.0
	_reroll_btn.z_index = 12
	_reroll_btn.visible = false
	_reroll_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.add_theme_font_override("font", _bold_font)
	_reroll_btn.add_theme_font_size_override("font_size", 18)
	var rr_style := UIStyle.create_flat_stylebox(Color(0.14, 0.12, 0.10, 0.97), 8, 16, 8)
	rr_style.border_color = COL_GOLD
	rr_style.set_border_width_all(2)
	rr_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	rr_style.shadow_size = 12
	var rr_hov: StyleBoxFlat = rr_style.duplicate()
	rr_hov.bg_color = Color(0.24, 0.19, 0.13, 0.98)
	rr_hov.border_color = COL_GOLD_BRIGHT
	_reroll_btn.add_theme_stylebox_override("normal", rr_style)
	_reroll_btn.add_theme_stylebox_override("hover", rr_hov)
	_reroll_btn.add_theme_stylebox_override("pressed", rr_style)
	_reroll_btn.add_theme_stylebox_override("disabled", rr_style)
	_reroll_btn.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_reroll_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	_root.add_child(_reroll_btn)

	_accept_cards_btn = Button.new()
	_accept_cards_btn.anchor_left = 0.800
	_accept_cards_btn.anchor_right = 0.800
	_accept_cards_btn.anchor_top = 0.855
	_accept_cards_btn.anchor_bottom = 0.855
	_accept_cards_btn.offset_left = -246.0
	_accept_cards_btn.offset_right = -18.0
	_accept_cards_btn.offset_top = -24.0
	_accept_cards_btn.offset_bottom = 24.0
	_accept_cards_btn.z_index = 12
	_accept_cards_btn.visible = false
	_accept_cards_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_accept_cards_btn.focus_mode = Control.FOCUS_NONE
	_accept_cards_btn.add_theme_font_override("font", _bold_font)
	_accept_cards_btn.add_theme_font_size_override("font_size", 18)
	_accept_style = UIStyle.create_flat_stylebox(Color(0.36, 0.28, 0.14, 0.98), 8, 20, 8)
	_accept_style.border_color = COL_GOLD_BRIGHT
	_accept_style.set_border_width_all(2)
	_accept_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	_accept_style.shadow_size = 14
	var acc_hov: StyleBoxFlat = _accept_style.duplicate()
	acc_hov.bg_color = Color(0.46, 0.36, 0.18, 0.98)
	acc_hov.border_color = COL_CREAM
	var acc_dis: StyleBoxFlat = _accept_style.duplicate()
	acc_dis.bg_color = Color(0.14, 0.12, 0.10, 0.85)
	acc_dis.border_color = Color(0.45, 0.38, 0.28, 0.45)
	_accept_cards_btn.add_theme_stylebox_override("normal", _accept_style)
	_accept_cards_btn.add_theme_stylebox_override("hover", acc_hov)
	_accept_cards_btn.add_theme_stylebox_override("pressed", _accept_style)
	_accept_cards_btn.add_theme_stylebox_override("disabled", acc_dis)
	_accept_cards_btn.add_theme_color_override("font_color", COL_CREAM)
	_accept_cards_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_accept_cards_btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.60, 0.52, 0.65))
	_accept_cards_btn.pressed.connect(_on_accept_cards_pressed)
	_root.add_child(_accept_cards_btn)

	# ── 4. BOTTOM-LEFT REYNA MAYARI PORTRAIT (Uncropped, slightly smaller & tucked left/down) ──
	_mayari_portrait = TextureRect.new()
	if ResourceLoader.exists(MAYARI_SPRITE_PATH):
		_mayari_portrait.texture = load(MAYARI_SPRITE_PATH)
	_mayari_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mayari_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mayari_portrait.anchor_left = -0.085
	_mayari_portrait.anchor_right = 0.355
	_mayari_portrait.anchor_top = 0.16
	_mayari_portrait.anchor_bottom = 1.24
	_mayari_portrait.z_index = 10
	_mayari_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mayari_portrait)

	# ── 5. RIGHT-SIDE HADES KEYWORD CALLOUT STACK (Appears on Beat 2 card hover) ──
	_callout_col = VBoxContainer.new()
	_callout_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_callout_col.custom_minimum_size = Vector2(220, 0)
	_callout_col.z_index = 30
	_callout_col.add_theme_constant_override("separation", 10)
	_callout_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout_col.visible = false
	_callout_col.modulate.a = 0.0
	_root.add_child(_callout_col)

func _create_preview_shadow_row(index: int) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UIStyle.create_flat_stylebox(Color(0.048, 0.045, 0.042, 0.92), 6, 16, 10)
	style.content_margin_right = 20
	style.border_color = Color(0.88, 0.79, 0.58, 0.48)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", style)
	card.set_meta("shadow_style", style)
	card.mouse_entered.connect(_on_shadow_row_hovered.bind(index, true))
	card.mouse_exited.connect(_on_shadow_row_hovered.bind(index, false))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 52)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# Same footprint as Beat 2's HadesEmblem so the flip lines up seamlessly!
	var diamond := MysteryDiamond.new()
	diamond.custom_minimum_size = Vector2(88, 88)
	diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(diamond)

	var q_lbl := Label.new()
	q_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	q_lbl.text = "?"
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_override("font", _bold_font)
	q_lbl.add_theme_font_size_override("font_size", 36)
	q_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diamond.add_child(q_lbl)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 4)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(mid)

	var top_line := HBoxContainer.new()
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(top_line)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(title_lbl)

	var tag_col := VBoxContainer.new()
	tag_col.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_col.add_theme_constant_override("separation", 0)
	tag_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(tag_col)

	var tag_lbl := Label.new()
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_override("font", _bold_font)
	tag_lbl.add_theme_font_size_override("font_size", 16)
	tag_col.add_child(tag_lbl)

	var tag_sub_lbl := Label.new()
	tag_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag_sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_sub_lbl.add_theme_font_override("font", _bold_font)
	tag_sub_lbl.add_theme_font_size_override("font_size", 16)
	tag_sub_lbl.visible = false
	tag_col.add_child(tag_sub_lbl)

	var desc_lbl := Label.new()
	desc_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.76, 0.71, 0.64, 0.76))
	mid.add_child(desc_lbl)

	var stat_lbl := Label.new()
	stat_lbl.text = "▸  ? ? ?"
	stat_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	stat_lbl.add_theme_font_size_override("font_size", 15)
	stat_lbl.add_theme_color_override("font_color", Color(0.78, 0.74, 0.68, 0.50))
	mid.add_child(stat_lbl)

	return {
		"panel": card,
		"style": style,
		"diamond": diamond,
		"q_lbl": q_lbl,
		"title_lbl": title_lbl,
		"tag_lbl": tag_lbl,
		"tag_sub_lbl": tag_sub_lbl,
		"desc_lbl": desc_lbl,
		"stat_lbl": stat_lbl,
	}

func _apply_confirm_style(accent: Color) -> void:
	var base_bg := Color(accent.r * 0.44, accent.g * 0.40, accent.b * 0.30, 0.98)
	_confirm_style.bg_color = base_bg
	_confirm_style.border_color = accent.lightened(0.20)
	var hov: StyleBoxFlat = _confirm_style.duplicate()
	hov.bg_color = base_bg.lightened(0.15)
	hov.border_color = COL_CREAM
	var prs: StyleBoxFlat = _confirm_style.duplicate()
	prs.bg_color = base_bg.darkened(0.1)
	_confirm_btn.add_theme_stylebox_override("normal", _confirm_style)
	_confirm_btn.add_theme_stylebox_override("hover", hov)
	_confirm_btn.add_theme_stylebox_override("pressed", prs)
	_confirm_btn.add_theme_color_override("font_color", COL_CREAM)
	_confirm_btn.add_theme_color_override("font_hover_color", Color.WHITE)

# ── Offering Logic & Refresh ─────────────────────────────────────────────────

func _nudge_offer(delta: float) -> void:
	if _is_locked:
		return
	var next_val := clampf(roundf((_current_offer + delta) / 5.0) * 5.0, 0.0, _max_offer)
	if delta > 0.0 and _max_offer - _current_offer < 5.0:
		next_val = _max_offer
	if not is_equal_approx(next_val, _current_offer):
		EventBus.request_sfx.emit("interact")
		_current_offer = next_val
		_refresh_offering_ui(true)

func _on_slider_changed(val: float) -> void:
	if _is_locked:
		return
	var next_val := _max_offer if absf(val - _max_offer) < 2.5 else clampf(roundf(val / 5.0) * 5.0, 0.0, _max_offer)
	if not is_equal_approx(next_val, _current_offer):
		_current_offer = next_val
		_refresh_offering_ui(true)

func _evaluate_tier(offer: float) -> String:
	if _total_paid + offer >= _goal - 0.01:
		return "cleared"
	if offer >= _generous_amount - 0.01:
		return "generous"
	if offer >= _min_amount - 0.01:
		return "balanced"
	return "shortfall"

func _refresh_offering_ui(animate_pop: bool) -> void:
	var tier := _evaluate_tier(_current_offer)

	var accent: Color = COL_TIER_FAIR
	var accent_bright: Color = COL_TIER_FAIR_BRIGHT
	var shadow_title := "UNREVEALED FATE"
	var shadow_desc := "The moon's gaze is unreadable tonight. Fortune or trial waits beneath the veil."
	var shadow_tag := "55% OMEN"
	var shadow_tag_sub := "45% FAVOR"
	var shadow_tag_col := COL_TIER_MEAGER_BRIGHT
	var shadow_tag_sub_col := COL_TIER_LAVISH_BRIGHT
	var shadow_bg := Color(0.060, 0.058, 0.064, 0.94)
	var shadow_q := "?"

	match tier:
		"cleared":
			accent = COL_TIER_SEALED
			accent_bright = COL_TIER_SEALED_BRIGHT
			shadow_title = "FINAL BLESSING"
			shadow_desc = "The Silver Ledger closes in peace. A final lunar blessing awaits beneath the veil."
			shadow_tag = "100% FAVOR"
			shadow_tag_sub = ""
			shadow_tag_col = accent_bright
			shadow_bg = Color(0.095, 0.084, 0.056, 0.94)
			shadow_q = "✦"
			_confirm_btn.text = "Seal Ledger"
		"generous":
			accent = COL_TIER_LAVISH
			accent_bright = COL_TIER_LAVISH_BRIGHT
			shadow_title = "UNREVEALED FAVOR"
			shadow_desc = "The Pale Queen smiles upon your offering. A warm blessing stirs beneath the veil."
			shadow_tag = "100% FAVOR"
			shadow_tag_sub = ""
			shadow_tag_col = accent_bright
			shadow_bg = Color(0.092, 0.080, 0.050, 0.94)
			shadow_q = "?"
			_confirm_btn.text = "Offer Lavishly"
		"balanced":
			accent = COL_TIER_FAIR
			accent_bright = COL_TIER_FAIR_BRIGHT
			shadow_title = "UNREVEALED FATE"
			shadow_desc = "The moon's gaze is unreadable tonight. Fortune or trial waits beneath the veil."
			var shifted_fair := StoryManager.has_shifted_mayari_odds(_total_paid + _current_offer)
			shadow_tag = "65% FAVOR" if shifted_fair else "55% OMEN"
			shadow_tag_sub = "35% OMEN" if shifted_fair else "45% FAVOR"
			shadow_tag_col = COL_TIER_LAVISH_BRIGHT if shifted_fair else COL_TIER_MEAGER_BRIGHT
			shadow_tag_sub_col = COL_TIER_MEAGER_BRIGHT if shifted_fair else COL_TIER_LAVISH_BRIGHT
			shadow_bg = Color(0.062, 0.060, 0.066, 0.94)
			shadow_q = "?"
			_confirm_btn.text = "Offer Fairly"
		_:
			accent = COL_TIER_MEAGER
			accent_bright = COL_TIER_MEAGER_BRIGHT
			shadow_title = "UNREVEALED OMEN"
			shadow_desc = "Empty hands draw the moon's cold eye. A heavy omen gathers beneath the veil." if _current_offer <= 0.01 else "A meager tribute chills the evening air. A lunar trial gathers beneath the veil."
			var shifted_meager := StoryManager.has_shifted_mayari_odds(_total_paid + _current_offer)
			shadow_tag = "75% OMEN" if shifted_meager else "100% OMEN"
			shadow_tag_sub = "25% FAVOR" if shifted_meager else ""
			shadow_tag_col = accent_bright
			shadow_tag_sub_col = COL_TIER_LAVISH_BRIGHT
			shadow_bg = Color(0.048, 0.062, 0.090, 0.94)
			shadow_q = "?"
			_confirm_btn.text = "Offer Nothing" if _current_offer <= 0.01 else "Offer Meagerly"

	var tier_changed := (_last_tier != "" and tier != _last_tier)
	for i in range(_shadow_rows.size()):
		var sr: Dictionary = _shadow_rows[i]
		var st: StyleBoxFlat = sr["style"]
		var dm: MysteryDiamond = sr["diamond"]
		var ql: Label = sr["q_lbl"]
		var tl: Label = sr["title_lbl"]
		var tg: Label = sr["tag_lbl"]
		var tgs: Label = sr["tag_sub_lbl"]
		var dl: Label = sr["desc_lbl"]

		var p_card: PanelContainer = sr["panel"]
		p_card.set_meta("shadow_accent", accent)
		p_card.set_meta("shadow_bright", accent_bright)
		st.bg_color = shadow_bg
		st.border_color = Color(accent.r, accent.g, accent.b, 0.56)
		dm.border_col = Color(accent.r, accent.g, accent.b, 0.76)
		dm.fill_col = shadow_bg.darkened(0.28)
		dm.queue_redraw()
		ql.text = shadow_q
		ql.add_theme_color_override("font_color", Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.88))
		tl.text = shadow_title
		tl.add_theme_color_override("font_color", Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.90))
		tg.text = shadow_tag
		tg.add_theme_color_override("font_color", Color(shadow_tag_col.r, shadow_tag_col.g, shadow_tag_col.b, 0.92))
		tgs.text = shadow_tag_sub
		tgs.visible = not shadow_tag_sub.is_empty()
		tgs.add_theme_color_override("font_color", Color(shadow_tag_sub_col.r, shadow_tag_sub_col.g, shadow_tag_sub_col.b, 0.92))
		dl.text = shadow_desc

		if tier_changed:
			var p: PanelContainer = sr["panel"]
			p.pivot_offset = p.size * 0.5
			var sp := create_tween()
			sp.tween_interval(i * 0.035)
			sp.tween_property(p, "scale", Vector2(1.016, 1.016), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			sp.tween_property(p, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)

	_apply_confirm_style(accent)
	_unified_gauge.set_state(_total_paid, _goal, _current_offer, _max_offer, _min_amount, _generous_amount, accent, accent_bright)

	# Track milestones newly touched by tonight's offer preview
	var touched_now: Array[Dictionary] = []
	var touched_ids: Array[String] = []
	var newly_touched := false
	for m in StoryManager.LEDGER_MILESTONES:
		var m_amt := float(m.get("amount", 0.0))
		if m_amt <= 0.0 or m_amt >= _goal - 0.01:
			continue
		if _total_paid < m_amt - 0.01 and _total_paid + _current_offer >= m_amt - 0.01:
			var mid := str(m.get("id", ""))
			touched_now.append(m)
			touched_ids.append(mid)
			if not (mid in _touched_milestone_ids):
				newly_touched = true
	var touched_changed := (touched_ids != _touched_milestone_ids)
	_touched_milestone_ids = touched_ids
	if animate_pop and newly_touched:
		EventBus.request_sfx.emit("purchase")
	if _phase == 0 and _hovered_milestone_dict.is_empty() and touched_changed:
		_show_milestone_callouts(touched_now)

	if animate_pop:
		_unified_gauge.pop_amount()
		if tier_changed:
			_last_tier = tier
			EventBus.request_sfx.emit("interact")
	elif _last_tier == "":
		_last_tier = tier

func _play_entrance() -> void:
	_mayari_portrait.modulate.a = 0.0
	_mayari_portrait.offset_left = -80.0
	_mayari_portrait.offset_right = -80.0
	_header_banner.modulate.a = 0.0
	_header_banner.offset_top = -24.0
	_header_banner.offset_bottom = -24.0
	_center_frame.modulate.a = 0.0
	_confirm_btn.modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_header_banner, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_header_banner, "offset_top", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_header_banner, "offset_bottom", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_center_frame, "modulate:a", 1.0, 0.30).set_delay(0.05).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_confirm_btn, "modulate:a", 1.0, 0.28).set_delay(0.10).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_mayari_portrait, "modulate:a", 1.0, 0.32).set_delay(0.06).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_mayari_portrait, "offset_left", 0.0, 0.40).set_delay(0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_mayari_portrait, "offset_right", 0.0, 0.40).set_delay(0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── Resolution & In-Place Card Flip Reveal ───────────────────────────────────

func _on_confirm_pressed() -> void:
	if _is_locked:
		return
	_is_locked = true
	_phase = 1
	_unified_gauge.set_interactive(false)
	_confirm_btn.disabled = true

	_confirmed_offer = _current_offer
	_confirmed_tier = _evaluate_tier(_confirmed_offer)
	EventBus.request_sfx.emit("money_decrease" if _confirmed_offer > 0.0 else "interact")

	# Fade out the bottom gauge dock and overlapping CTA while keeping the 3 slots locked in place!
	var fade_tw := create_tween().set_parallel(true)
	fade_tw.tween_property(_gauge_dock, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	fade_tw.tween_property(_confirm_btn, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(_scroll_hint_box):
		fade_tw.tween_property(_scroll_hint_box, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	await fade_tw.finished
	if not is_inside_tree():
		return

	_confirm_btn.visible = false
	if is_instance_valid(_scroll_hint_box):
		_scroll_hint_box.visible = false
	_gauge_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_launch_hades_card_flip()

# ── Beat 2: In-Place Card Flip Reveal ────────────────────────────────────────

func _launch_hades_card_flip() -> void:
	_phase = 2
	var projected_paid := minf(_goal, _total_paid + _confirmed_offer)
	_confirmed_shifted_odds = StoryManager.has_shifted_mayari_odds(projected_paid)
	_rerolls_left = StoryManager.get_nightly_reroll_count(projected_paid)
	_max_rerolls = _rerolls_left
	_max_card_picks = StoryManager.get_max_mayari_card_picks(projected_paid)
	_selected_indices.clear()
	_show_keyword_callouts([])

	_card_data_list = MayariCardRegistry.draw_three_cards(_confirmed_tier, _confirmed_shifted_odds)
	_card_rows.clear()
	_card_picked = false
	_hovered_idx = -1
	_cards_ready = false

	var pick_phrase := "Choose 1 or 2" if _max_card_picks >= 2 else "Choose one"
	match _confirmed_tier:
		"cleared":
			_header_title_lbl.text = "T H E   P A C T   I S   S E A L E D"
			_header_sub_lbl.text = "%s final Favor%s for tomorrow." % [pick_phrase, "(s)" if _max_card_picks >= 2 else ""]
		"generous":
			_header_title_lbl.text = "F A V O R   O F   B I R I N G A N"
			_header_sub_lbl.text = "%s Favor%s for tomorrow." % [pick_phrase, "(s)" if _max_card_picks >= 2 else ""]
		"shortfall":
			_header_title_lbl.text = "O M E N   O F   B I R I N G A N"
			_header_sub_lbl.text = "%s card%s to endure tomorrow." % [pick_phrase, "(s)" if _max_card_picks >= 2 else ""]
		_:
			_header_title_lbl.text = "M O O N   O F   B I R I N G A N"
			_header_sub_lbl.text = "The moon deals a mixed hand — %s for tomorrow." % ("choose 1 or 2" if _max_card_picks >= 2 else "choose one")

	# Pre-create the 3 revealed cards inside the EXACT same slots with visible=true & alpha=0
	# so MarginContainer lays them out at the EXACT same rect as the shadow cards before flipping!
	for i in range(mini(_card_data_list.size(), _card_slots.size())):
		var row := _create_hades_boon_row(_card_data_list[i], i)
		row.visible = true
		row.modulate.a = 0.0
		_card_slots[i].add_child(row)
		_card_rows.append(row)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	# Staggered vertical card flip IN PLACE: shadow collapses scale.y 1 -> 0 around slot center,
	# swaps directly to pre-laid-out revealed card at the exact same center, and unfolds 0 -> 1!
	var last_tw: Tween = null
	for i in range(_card_rows.size()):
		var slot: Control = _card_slots[i]
		var slot_sz: Vector2 = slot.size
		var shadow_panel: PanelContainer = _shadow_rows[i]["panel"]
		var revealed_row: PanelContainer = _card_rows[i]
		shadow_panel.pivot_offset = slot_sz * 0.5
		revealed_row.visible = false
		revealed_row.modulate.a = 1.0
		revealed_row.pivot_offset = slot_sz * 0.5
		revealed_row.scale = Vector2(1.0, 0.0)

		var tw := create_tween()
		tw.tween_interval(i * 0.11)
		tw.tween_property(shadow_panel, "scale:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			shadow_panel.visible = false
			revealed_row.visible = true
			revealed_row.pivot_offset = slot.size * 0.5
			revealed_row.scale = Vector2(1.0, 0.0)
			EventBus.request_sfx.emit("interact")
		)
		tw.tween_property(revealed_row, "scale:y", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last_tw = tw

	if last_tw:
		await last_tw.finished
	_cards_ready = true
	_refresh_draft_controls()

func _create_hades_boon_row(c_data: Dictionary, index: int) -> PanelContainer:
	var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
	var pal: Dictionary = HadesEmblem.palette("favor" if is_fav else "omen")
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]
	var row_bg: Color = pal["bg"]

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style := UIStyle.create_flat_stylebox(row_bg, 6, 16, 10)
	style.content_margin_right = 20
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)
	card.set_meta("card_style", style)
	card.set_meta("accent", accent)
	card.set_meta("accent_bright", accent_bright)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 52)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(88, 88)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	emblem.fill_color = Color(0.0, 0.0, 0.0, 0.0)
	hbox.add_child(emblem)

	HadesEmblem.populate_emblem_glyph(
		emblem,
		str(c_data.get("icon", "")),
		str(c_data.get("sigil", "☽")),
		accent_bright,
		36.0,
		36
	)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 3)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_col)

	var top_line := HBoxContainer.new()
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(top_line)

	var title_lbl := Label.new()
	title_lbl.text = str(c_data.get("title", "Moon Card")).to_upper()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 25)
	title_lbl.add_theme_color_override("font_color", accent_bright)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(title_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = "FAVOR" if is_fav else "OMEN"
	rarity_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_override("font", _bold_font)
	rarity_lbl.add_theme_font_size_override("font_size", 22)
	rarity_lbl.add_theme_color_override("font_color", accent_bright)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(rarity_lbl)

	var desc_rt := RichTextLabel.new()
	desc_rt.bbcode_enabled = true
	desc_rt.fit_content = true
	desc_rt.scroll_active = false
	desc_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_rt.add_theme_font_override("normal_font", UIStyle.FONT_INDER)
	desc_rt.add_theme_font_override("bold_font", _bold_font)
	desc_rt.add_theme_font_size_override("normal_font_size", 18)
	desc_rt.add_theme_font_size_override("bold_font_size", 18)
	desc_rt.add_theme_color_override("default_color", COL_CREAM_MUTED)
	var raw_desc := str(c_data.get("description_rich", c_data.get("description", "")))
	desc_rt.text = raw_desc.replace("[b]", "[b][color=%s]" % COL_BOLD_CREAM).replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

	var stats: Array = c_data.get("stats", [])
	if stats.is_empty():
		var hook_lbl := Label.new()
		hook_lbl.text = "▸  " + str(c_data.get("tagline", ""))
		hook_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		hook_lbl.add_theme_font_size_override("font_size", 18)
		hook_lbl.add_theme_color_override("font_color", COL_CREAM)
		hook_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(hook_lbl)
	elif stats.size() >= 3:
		# 2-column compact grid for 3-4 stat cards so card height stays uniform
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 2)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(grid)
		for st in stats:
			var stat_dict: Dictionary = st
			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 8)
			s_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(s_row)

			var s_name := Label.new()
			s_name.text = "▸ " + str(stat_dict.get("label", ""))
			s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
			s_name.add_theme_font_size_override("font_size", 15)
			s_name.add_theme_color_override("font_color", COL_CREAM)
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", _bold_font)
			s_val.add_theme_font_size_override("font_size", 16)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := COL_STAT_POS if tone == "pos" else (COL_STAT_NEG if tone == "neg" else COL_GOLD_BRIGHT)
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)
	else:
		var stats_box := VBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 1 if stats.size() == 2 else 2)
		stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(stats_box)
		var lbl_sz := 16 if stats.size() == 2 else 18
		var val_sz := 17 if stats.size() == 2 else 19
		for st in stats:
			var stat_dict: Dictionary = st
			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 12)
			s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_box.add_child(s_row)

			var s_name := Label.new()
			s_name.text = "▸ " + str(stat_dict.get("label", ""))
			s_name.custom_minimum_size = Vector2(345, 0)
			s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
			s_name.add_theme_font_size_override("font_size", lbl_sz)
			s_name.add_theme_color_override("font_color", COL_CREAM)
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", _bold_font)
			s_val.add_theme_font_size_override("font_size", val_sz)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := COL_STAT_POS if tone == "pos" else (COL_STAT_NEG if tone == "neg" else COL_GOLD_BRIGHT)
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)

	card.mouse_entered.connect(_on_row_hovered.bind(index, true))
	card.mouse_exited.connect(_on_row_hovered.bind(index, false))
	card.gui_input.connect(_on_row_gui_input.bind(index))
	return card

func _on_shadow_row_hovered(index: int, is_hovered: bool) -> void:
	if _phase != 0 or _is_locked or index < 0 or index >= _shadow_rows.size():
		return
	var active_idx := index if is_hovered else -1
	if is_hovered:
		EventBus.request_sfx.emit("interact")
	for i in range(_shadow_rows.size()):
		var p: PanelContainer = _shadow_rows[i]["panel"]
		if not is_instance_valid(p):
			continue
		var st: StyleBoxFlat = _shadow_rows[i]["style"]
		var acc: Color = p.get_meta("shadow_accent", COL_GOLD)
		var brt: Color = p.get_meta("shadow_bright", COL_GOLD_BRIGHT)
		p.pivot_offset = p.size * 0.5
		var tw := create_tween()
		if i == active_idx:
			st.border_color = brt
			st.border_width_left = 6
			st.border_width_top = 2
			st.border_width_right = 2
			st.border_width_bottom = 2
			tw.tween_property(p, "scale", Vector2(1.020, 1.020), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(p, "modulate", Color(1.07, 1.05, 1.02, 1.0), 0.12)
		else:
			st.border_color = Color(acc.r, acc.g, acc.b, 0.56)
			st.border_width_left = 4
			st.border_width_top = 1
			st.border_width_right = 1
			st.border_width_bottom = 1
			var dim := Color(0.84, 0.80, 0.76, 0.92) if active_idx != -1 else Color.WHITE
			tw.tween_property(p, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(p, "modulate", dim, 0.14)

func _on_row_hovered(index: int, is_hovered: bool) -> void:
	if _card_picked or not _cards_ready or index < 0 or index >= _card_rows.size():
		return
	if is_hovered:
		if _hovered_idx == index:
			return
		_hovered_idx = index
		EventBus.request_sfx.emit("interact")
		_show_keyword_callouts(_card_data_list[index].get("keywords", []), _card_rows[index])
	elif _hovered_idx == index:
		if is_instance_valid(_card_rows[index]) and _card_rows[index].get_global_rect().has_point(get_viewport().get_mouse_position()):
			return
		_hovered_idx = -1
		_show_keyword_callouts([])

	for i in range(_card_rows.size()):
		var row := _card_rows[i]
		if not is_instance_valid(row):
			continue
		var style: StyleBoxFlat = row.get_meta("card_style")
		var accent: Color = row.get_meta("accent")
		var accent_bright: Color = row.get_meta("accent_bright")
		var is_sel := i in _selected_indices
		row.pivot_offset = row.size * 0.5
		var tw := create_tween()
		if _hovered_idx == i or is_sel:
			style.border_color = COL_CREAM if is_sel else accent_bright
			style.border_width_top = 3 if is_sel else 2
			style.border_width_right = 3 if is_sel else 2
			style.border_width_bottom = 3 if is_sel else 2
			style.border_width_left = 6
			var sc := Vector2(1.026, 1.026) if _hovered_idx == i else Vector2(1.014, 1.014)
			tw.tween_property(row, "scale", sc, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(row, "modulate", Color.WHITE, 0.12)
		else:
			style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_width_left = 4
			var dim := Color(0.76, 0.72, 0.68, 0.88) if (_hovered_idx != -1 or not _selected_indices.is_empty()) else Color.WHITE
			tw.tween_property(row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(row, "modulate", dim, 0.14)

func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if _card_picked or not _cards_ready:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_row(index)

func _position_callout_beside(anchor_ctrl: Control) -> void:
	if not is_instance_valid(_callout_col) or not is_instance_valid(anchor_ctrl):
		return
	var vp_sz := get_viewport().get_visible_rect().size
	var rect := anchor_ctrl.get_global_rect()
	var c_sz := _callout_col.get_combined_minimum_size()
	var cw := clampf(c_sz.x, 260.0, 310.0)
	var ch := maxf(c_sz.y, 72.0)
	_callout_col.size = Vector2(cw, ch)
	var tx := minf(rect.end.x + 14.0, vp_sz.x - cw - 10.0)
	var mid_y := rect.position.y + rect.size.y * 0.5
	var ty := clampf(mid_y - ch * 0.5, 16.0, vp_sz.y - ch - 16.0)
	_callout_col.position = Vector2(tx, ty)

func _show_keyword_callouts(keyword_ids: Array, anchor_ctrl: Control = null) -> void:
	if not is_instance_valid(_callout_col):
		return
	if not keyword_ids.is_empty() and anchor_ctrl != null and anchor_ctrl == _callout_anchor and _callout_col.visible:
		return
	_callout_anchor = anchor_ctrl if not keyword_ids.is_empty() else null
	if _callout_tween and _callout_tween.is_valid():
		_callout_tween.kill()

	for child in _callout_col.get_children():
		_callout_col.remove_child(child)
		child.queue_free()

	var shown := 0
	for kw_id in keyword_ids:
		var info := MayariCardRegistry.get_keyword(str(kw_id))
		if info.is_empty():
			continue
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(280, 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs := UIStyle.create_flat_stylebox(Color(0.062, 0.054, 0.046, 0.95), 6, 14, 10)
		bs.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.78)
		bs.border_width_left = 3
		bs.border_width_top = 1
		bs.border_width_right = 1
		bs.border_width_bottom = 1
		bs.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		bs.shadow_size = 12
		box.add_theme_stylebox_override("panel", bs)

		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 4)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bv)

		var kt := Label.new()
		kt.text = str(info.get("title", ""))
		kt.add_theme_font_override("font", _bold_font)
		kt.add_theme_font_size_override("font_size", 21)
		kt.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		kt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(kt)

		var kd := Label.new()
		kd.text = str(info.get("desc", ""))
		kd.custom_minimum_size = Vector2(248, 0)
		kd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kd.add_theme_font_override("font", UIStyle.FONT_INDER)
		kd.add_theme_font_size_override("font_size", 18)
		kd.add_theme_color_override("font_color", COL_CREAM_MUTED)
		kd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(kd)

		_callout_col.add_child(box)
		shown += 1

	if shown == 0:
		_callout_col.visible = false
		_callout_col.modulate.a = 0.0
		return

	_callout_col.visible = true
	_callout_col.reset_size()
	if is_instance_valid(anchor_ctrl):
		_position_callout_beside(anchor_ctrl)
	_callout_col.modulate.a = 0.0
	var final_x := _callout_col.position.x
	_callout_col.position.x = final_x - 8.0
	_callout_tween = create_tween().set_parallel(true)
	_callout_tween.tween_property(_callout_col, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	_callout_tween.tween_property(_callout_col, "position:x", final_x, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_milestone_hovered(m: Dictionary) -> void:
	if _phase != 0 or not is_instance_valid(_callout_col):
		return
	_hovered_milestone_dict = m
	if not m.is_empty():
		_show_milestone_callouts([m])
		return
	# When unhovering a pip, keep showing any milestones currently touched by the offer preview!
	var touched_now: Array[Dictionary] = []
	for lm in StoryManager.LEDGER_MILESTONES:
		var m_amt := float(lm.get("amount", 0.0))
		if m_amt > 0.0 and m_amt < _goal - 0.01 and _total_paid < m_amt - 0.01 and _total_paid + _current_offer >= m_amt - 0.01:
			touched_now.append(lm)
	_show_milestone_callouts(touched_now)

func _show_milestone_callouts(milestone_list: Array[Dictionary]) -> void:
	if _phase != 0 or not is_instance_valid(_callout_col):
		return
	_callout_anchor = null
	if _callout_tween and _callout_tween.is_valid():
		_callout_tween.kill()
	for child in _callout_col.get_children():
		_callout_col.remove_child(child)
		child.queue_free()
	if milestone_list.is_empty():
		_callout_col.visible = false
		_callout_col.modulate.a = 0.0
		return

	for m in milestone_list:
		var m_amt := float(m.get("amount", 0.0))
		var pct := int(roundf(float(m.get("ratio", 0.0)) * 100.0))
		var already := _total_paid >= m_amt - 0.01
		var tonight := (not already) and (_total_paid + _current_offer >= m_amt - 0.01)
		var status_str := "Unlocked ✓" if already else ("✦ Unlocks Tonight!" if tonight else "₱%d more needed" % int(ceilf(m_amt - _total_paid)))
		var status_col := COL_STAT_POS if (already or tonight) else COL_GOLD_BRIGHT

		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(236, 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs := UIStyle.create_flat_stylebox(Color(0.062, 0.054, 0.046, 0.96), 6, 14, 10)
		bs.border_color = status_col
		bs.border_width_left = 3
		bs.border_width_top = 1
		bs.border_width_right = 1
		bs.border_width_bottom = 1
		bs.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		bs.shadow_size = 12
		box.add_theme_stylebox_override("panel", bs)

		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 4)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bv)

		var kt := Label.new()
		kt.text = "%d%% · %s" % [pct, str(m.get("title", ""))]
		kt.custom_minimum_size = Vector2(204, 0)
		kt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kt.add_theme_font_override("font", _bold_font)
		kt.add_theme_font_size_override("font_size", 15)
		kt.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		bv.add_child(kt)

		var ks := Label.new()
		ks.text = status_str
		ks.add_theme_font_override("font", _bold_font)
		ks.add_theme_font_size_override("font_size", 12)
		ks.add_theme_color_override("font_color", status_col)
		bv.add_child(ks)

		var kd := Label.new()
		kd.text = str(m.get("desc", ""))
		kd.custom_minimum_size = Vector2(204, 0)
		kd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kd.add_theme_font_override("font", UIStyle.FONT_INDER)
		kd.add_theme_font_size_override("font_size", 13)
		kd.add_theme_color_override("font_color", COL_CREAM_MUTED)
		bv.add_child(kd)

		_callout_col.add_child(box)

	_callout_col.visible = true
	_callout_col.reset_size()
	if is_instance_valid(_gauge_dock):
		_position_callout_beside(_gauge_dock)
	_callout_col.modulate.a = 0.0
	_callout_tween = create_tween()
	_callout_tween.tween_property(_callout_col, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)

func _refresh_draft_controls() -> void:
	if is_instance_valid(_reroll_btn):
		_reroll_btn.visible = _cards_ready and not _card_picked and _rerolls_left > 0
		_reroll_btn.disabled = not _cards_ready or _card_picked or _rerolls_left <= 0
		_reroll_btn.text = ("↻ Reroll (%d)" % _rerolls_left) if _max_rerolls >= 2 else "↻ Reroll"
	if is_instance_valid(_accept_cards_btn):
		_accept_cards_btn.visible = _cards_ready and not _card_picked and _max_card_picks >= 2
		var cnt := _selected_indices.size()
		_accept_cards_btn.disabled = cnt == 0
		if cnt == 0:
			_accept_cards_btn.text = "Pick 1 or 2 Cards"
		elif cnt == 1:
			_accept_cards_btn.text = "Accept 1 Card"
		else:
			_accept_cards_btn.text = "Accept 2 Cards"

func _on_reroll_pressed() -> void:
	if not _cards_ready or _card_picked or _rerolls_left <= 0:
		return
	_rerolls_left -= 1
	_cards_ready = false
	_selected_indices.clear()
	_hovered_idx = -1
	_show_keyword_callouts([])
	_refresh_draft_controls()
	EventBus.request_sfx.emit("interact")

	var old_rows := _card_rows.duplicate()
	_card_data_list = MayariCardRegistry.draw_three_cards(_confirmed_tier, _confirmed_shifted_odds)
	_card_rows.clear()
	for i in range(mini(_card_data_list.size(), _card_slots.size())):
		var row := _create_hades_boon_row(_card_data_list[i], i)
		row.visible = true
		row.modulate.a = 0.0
		_card_slots[i].add_child(row)
		_card_rows.append(row)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	var last_tw: Tween = null
	for i in range(_card_rows.size()):
		var slot: Control = _card_slots[i]
		var slot_sz: Vector2 = slot.size
		var old_r: PanelContainer = old_rows[i] if i < old_rows.size() else null
		var new_r: PanelContainer = _card_rows[i]
		new_r.visible = false
		new_r.modulate.a = 1.0
		new_r.pivot_offset = slot_sz * 0.5
		new_r.scale = Vector2(1.0, 0.0)
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		if is_instance_valid(old_r):
			old_r.pivot_offset = slot_sz * 0.5
			tw.tween_property(old_r, "scale:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if is_instance_valid(old_r):
				old_r.queue_free()
			new_r.visible = true
			new_r.pivot_offset = slot.size * 0.5
			new_r.scale = Vector2(1.0, 0.0)
			EventBus.request_sfx.emit("interact")
		)
		tw.tween_property(new_r, "scale:y", 1.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last_tw = tw

	if last_tw:
		await last_tw.finished
	_cards_ready = true
	_refresh_draft_controls()

func _select_row(index: int) -> void:
	if _card_picked or index < 0 or index >= _card_data_list.size():
		return
	if _max_card_picks >= 2:
		if index in _selected_indices:
			_selected_indices.erase(index)
		elif _selected_indices.size() < _max_card_picks:
			_selected_indices.append(index)
		else:
			# Replace oldest selection so clicking a 3rd card feels responsive
			_selected_indices.pop_front()
			_selected_indices.append(index)
		EventBus.request_sfx.emit("interact")
		_refresh_draft_controls()
		_on_row_hovered(index, true)
		return
	_finalize_selected_rows([index])

func _on_accept_cards_pressed() -> void:
	if _card_picked or not _cards_ready or _selected_indices.is_empty():
		return
	_finalize_selected_rows(_selected_indices.duplicate())

func _finalize_selected_rows(indices: Array[int]) -> void:
	if _card_picked or indices.is_empty():
		return
	_card_picked = true
	_show_keyword_callouts([])
	_refresh_draft_controls()

	var chosen_ids: Array[String] = []
	var chosen_titles: Array[String] = []
	var chosen_tags: Array[String] = []
	var any_favor := false
	for idx in indices:
		if idx < 0 or idx >= _card_data_list.size():
			continue
		var c_data: Dictionary = _card_data_list[idx]
		var cid := str(c_data.get("id", ""))
		if cid != "":
			chosen_ids.append(cid)
			chosen_titles.append(str(c_data.get("title", "")).to_upper())
			chosen_tags.append(str(c_data.get("tagline", "")))
			if str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR:
				any_favor = true

	EventBus.request_sfx.emit("purchase" if any_favor else "interact")
	_header_title_lbl.text = "  ·  ".join(chosen_titles)
	_header_sub_lbl.text = "Active tomorrow · " + " | ".join(chosen_tags)

	for i in range(_card_rows.size()):
		var row := _card_rows[i]
		if not is_instance_valid(row):
			continue
		var tw := create_tween()
		if i in indices:
			var style: StyleBoxFlat = row.get_meta("card_style")
			style.border_color = COL_CREAM
			style.set_border_width_all(3)
			row.pivot_offset = row.size * 0.5
			tw.tween_property(row, "scale", Vector2(1.04, 1.04), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(row, "modulate", Color.WHITE, 0.15)
		else:
			tw.tween_property(row, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(0.68).timeout
	if not is_inside_tree():
		return
	await _fade_out_and_finish(chosen_ids)

func _fade_out_and_finish(selected_card_ids: Array[String]) -> void:
	var fade := create_tween()
	fade.tween_property(_backdrop, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	fade.parallel().tween_property(_mayari_portrait, "modulate:a", 0.0, 0.22)
	fade.parallel().tween_property(_header_banner, "modulate:a", 0.0, 0.22)
	fade.parallel().tween_property(_center_frame, "modulate:a", 0.0, 0.22)
	if is_instance_valid(_reroll_btn):
		fade.parallel().tween_property(_reroll_btn, "modulate:a", 0.0, 0.18)
	if is_instance_valid(_accept_cards_btn):
		fade.parallel().tween_property(_accept_cards_btn, "modulate:a", 0.0, 0.18)
	await fade.finished
	completed.emit(_confirmed_offer, _confirmed_tier, selected_card_ids)
	queue_free()
