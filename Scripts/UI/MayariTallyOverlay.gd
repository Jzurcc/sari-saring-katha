class_name MayariTallyOverlay
extends CanvasLayer

## Hades-inspired split-screen ritual for Reyna Mayari's Nightly Tally,
## styled strictly in Sari-Saring Katha's warm espresso & antique gold palette:
## - Left stage: Reyna Mayari's tall character art framed against a soft dark vignette.
## - Right stage: Compact header + Silver Ledger hairline, transitioning smoothly
##   from Beat 1 (Nightly Offering selector) -> Beat 2 (3 compact horizontal Hades-style
##   boon/omen rows stacked cleanly).

signal completed(offer_amount: float, tier: String, selected_card_id: String)

const MAYARI_SPRITE_PATH := "res://Assets/characters/sprites/ReynaMayari.png"
const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")
const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

# Sari-Saring Katha Brand Palette (matches OptionsOverlay / CustomerRequestHUD / UIStyle)
const COL_ESPRESSO := Color(0.082, 0.074, 0.066, 0.94)
const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)        # #D59F47 antique gold
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)         # UIStyle.COLOR_GOLD_TEXT
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.82)
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.9)
const COL_CHILL := Color(0.84, 0.37, 0.36, 1.0)
const COL_CHILL_SOFT := Color(0.95, 0.58, 0.54, 1.0)
const COL_SEALED := Color(1.0, 0.95, 0.82, 1.0)
const COL_STAT_POS := Color(0.56, 0.92, 0.52, 1.0)       # Luminous Hades-style green for buffs
const COL_STAT_NEG := Color(0.96, 0.48, 0.45, 1.0)       # Warm coral-red for penalties
const COL_BOLD_CREAM := "#FFF6E5"

# Soft Pastel Offering Tier Palette (Shortfall / Balanced / Generous / Cleared)
const COL_TIER_SHORTFALL := Color(0.89, 0.63, 0.62, 1.0)       # Soft dusty rose
const COL_TIER_SHORTFALL_BRIGHT := Color(0.97, 0.81, 0.80, 1.0)
const COL_TIER_BALANCED := Color(0.90, 0.80, 0.56, 1.0)        # Soft buttercream gold
const COL_TIER_BALANCED_BRIGHT := Color(0.98, 0.92, 0.76, 1.0)
const COL_TIER_GENEROUS := Color(0.62, 0.85, 0.71, 1.0)        # Soft pastel sage/mint
const COL_TIER_GENEROUS_BRIGHT := Color(0.82, 0.95, 0.86, 1.0)
const COL_TIER_CLEARED := Color(0.96, 0.90, 0.74, 1.0)         # Soft moonlight champagne
const COL_TIER_CLEARED_BRIGHT := Color(1.0, 0.97, 0.90, 1.0)

## Sleek Hades-style overall Silver Ledger progress gauge (paid + live tribute preview, no text numbers).
class LedgerGauge extends Control:
	const BAR_H := 18.0
	const BAR_Y := 4.0

	var paid_ratio: float = 0.0
	var preview_ratio: float = 0.0
	var preview_color: Color = Color(0.90, 0.80, 0.56, 1.0)

	var _stripe_scroll: float = 0.0
	var _preview_rect: ColorRect
	var _stripe_mat: ShaderMaterial

	static var _ledger_shader: Shader = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_rect = ColorRect.new()
		_preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_rect.color = Color.WHITE
		if _ledger_shader == null:
			_ledger_shader = Shader.new()
			_ledger_shader.code = """
shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(0.90, 0.80, 0.56, 1.0);
uniform float scroll_offset = 0.0;
void fragment() {
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / 18.0 - scroll_offset;
	float band = smoothstep(0.42, 0.50, fract(diag)) * (1.0 - smoothstep(0.86, 0.94, fract(diag)));
	float sheen = smoothstep(0.4, 0.0, UV.y) * 0.14;
	vec3 col = base_color.rgb + vec3(band * 0.16 + sheen);
	COLOR = vec4(col, base_color.a);
}
"""
		_stripe_mat = ShaderMaterial.new()
		_stripe_mat.shader = _ledger_shader
		_preview_rect.material = _stripe_mat
		add_child(_preview_rect)
		resized.connect(_sync_rects)

	func _process(delta: float) -> void:
		_stripe_scroll += delta * 0.55
		if _stripe_mat:
			_stripe_mat.set_shader_parameter("scroll_offset", _stripe_scroll)
			_stripe_mat.set_shader_parameter("base_color", preview_color)

	func set_progress(paid_r: float, preview_r: float, p_col: Color) -> void:
		paid_ratio = clampf(paid_r, 0.0, 1.0)
		preview_ratio = clampf(preview_r, paid_ratio, 1.0)
		preview_color = p_col
		_sync_rects()
		queue_redraw()

	func _sync_rects() -> void:
		if not is_instance_valid(_preview_rect):
			return
		var pad := 2.0
		var inner_w := maxf(0.0, size.x - pad * 2.0)
		var x0 := pad + inner_w * paid_ratio
		var x1 := pad + inner_w * preview_ratio
		var w := maxf(0.0, x1 - x0)
		_preview_rect.position = Vector2(x0, BAR_Y + pad)
		_preview_rect.size = Vector2(w, BAR_H - pad * 2.0)
		_preview_rect.visible = w > 1.0

	func _draw() -> void:
		var bar_rect := Rect2(0.0, BAR_Y, size.x, BAR_H)
		draw_rect(bar_rect, Color(0.04, 0.036, 0.032, 0.95), true)

		# Subtle ruler notches
		for i in range(1, 10):
			var nx := size.x * (float(i) / 10.0)
			draw_line(Vector2(nx, BAR_Y + 4.0), Vector2(nx, BAR_Y + BAR_H - 4.0), Color(1.0, 0.92, 0.78, 0.08), 1.0, true)

		# Already-paid solid warm antique gold fill
		var pad := 2.0
		var paid_w := maxf(0.0, (size.x - pad * 2.0) * paid_ratio)
		if paid_w > 1.0:
			draw_rect(Rect2(pad, BAR_Y + pad, paid_w, BAR_H - pad * 2.0), Color(0.76, 0.60, 0.34, 0.92), true)
			draw_rect(Rect2(pad, BAR_Y + pad, paid_w, 4.0), Color(1.0, 0.92, 0.72, 0.22), true)

		# Gold frame & end-cap diamonds
		var frame_col := Color(0.835, 0.624, 0.278, 0.78)
		draw_rect(bar_rect, frame_col, false, 1.5)
		_draw_diamond(Vector2(0.0, BAR_Y + BAR_H * 0.5), 4.0, frame_col)
		_draw_diamond(Vector2(size.x, BAR_Y + BAR_H * 0.5), 4.0, frame_col)

		# Subtle divider mark where already-paid meets tonight's preview
		if preview_ratio > paid_ratio + 0.004 and paid_ratio > 0.004:
			var split_x := pad + (size.x - pad * 2.0) * paid_ratio
			draw_line(Vector2(split_x, BAR_Y + 1.0), Vector2(split_x, BAR_Y + BAR_H - 1.0), Color(1.0, 0.95, 0.85, 0.65), 1.5, true)

	func _draw_diamond(center: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
		]), col)

## Custom Hades Heat-Gauge-inspired interactive tribute bar with thin vertical threshold lines,
## diamond pips, and peso-coin indicators directly below the bar. Click or drag anywhere to set tribute.
class TributeGauge extends Control:
	signal value_changed(new_value: float)

	const BAR_H := 24.0
	const BAR_Y := 12.0

	var max_val: float = 100.0
	var current_val: float = 0.0
	var min_thresh: float = 40.0
	var gen_thresh: float = 65.0
	var fill_color: Color = Color(0.90, 0.80, 0.56, 1.0)
	var border_color: Color = Color(0.98, 0.92, 0.76, 0.92)
	var peso_tex: Texture2D = null
	var interactive: bool = true

	var _dragging: bool = false
	var _stripe_scroll: float = 0.0
	var _fill_rect: ColorRect
	var _stripe_mat: ShaderMaterial

	static var _gauge_shader: Shader = null

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_fill_rect = ColorRect.new()
		_fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill_rect.color = Color.WHITE
		if _gauge_shader == null:
			_gauge_shader = Shader.new()
			_gauge_shader.code = """
shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(0.90, 0.80, 0.56, 1.0);
uniform float scroll_offset = 0.0;
void fragment() {
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / 22.0 - scroll_offset;
	float band = smoothstep(0.40, 0.48, fract(diag)) * (1.0 - smoothstep(0.86, 0.94, fract(diag)));
	float sheen = smoothstep(0.35, 0.0, UV.y) * 0.14;
	vec3 col = base_color.rgb + vec3(band * 0.16 + sheen);
	COLOR = vec4(col, base_color.a);
}
"""
		_stripe_mat = ShaderMaterial.new()
		_stripe_mat.shader = _gauge_shader
		_fill_rect.material = _stripe_mat
		add_child(_fill_rect)
		resized.connect(_sync_fill_rect)

	func _process(delta: float) -> void:
		_stripe_scroll += delta * 0.55
		if _stripe_mat:
			_stripe_mat.set_shader_parameter("scroll_offset", _stripe_scroll)
			_stripe_mat.set_shader_parameter("base_color", fill_color)

	func _sync_fill_rect() -> void:
		if not is_instance_valid(_fill_rect):
			return
		var pad := 2.0
		var ratio := clampf(current_val / maxf(0.01, max_val), 0.0, 1.0) if max_val > 0.01 else 0.0
		var w := maxf(0.0, (size.x - pad * 2.0) * ratio)
		_fill_rect.position = Vector2(pad, BAR_Y + pad)
		_fill_rect.size = Vector2(w, BAR_H - pad * 2.0)
		_fill_rect.visible = w > 1.0

	func set_state(cur: float, mx: float, min_t: float, gen_t: float, col: Color, b_col: Color) -> void:
		current_val = cur
		max_val = mx
		min_thresh = min_t
		gen_thresh = gen_t
		fill_color = col
		border_color = b_col
		_sync_fill_rect()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not interactive or max_val <= 0.01:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_dragging = mb.pressed
				if mb.pressed:
					_emit_from_x(mb.position.x)
		elif event is InputEventMouseMotion and _dragging:
			var mm := event as InputEventMouseMotion
			_emit_from_x(mm.position.x)

	func _emit_from_x(local_x: float) -> void:
		var ratio := clampf(local_x / maxf(1.0, size.x), 0.0, 1.0)
		value_changed.emit(ratio * max_val)

	func _draw() -> void:
		var bar_rect := Rect2(0.0, BAR_Y, size.x, BAR_H)
		# Deep obsidian recessed track
		draw_rect(bar_rect, Color(0.04, 0.036, 0.032, 0.96), true)

		# Subtle ruler notches along the track
		var steps := 12
		for i in range(1, steps):
			var nx := size.x * (float(i) / float(steps))
			draw_line(Vector2(nx, BAR_Y + 5.0), Vector2(nx, BAR_Y + BAR_H - 5.0), Color(1.0, 0.92, 0.78, 0.08), 1.0, true)

		# Crisp outer & inner frame
		draw_rect(bar_rect, border_color, false, 2.0)
		draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.5), false, 1.0)

		# End-cap diamond ornaments
		_draw_diamond(Vector2(0.0, BAR_Y + BAR_H * 0.5), 4.5, border_color)
		_draw_diamond(Vector2(size.x, BAR_Y + BAR_H * 0.5), 4.5, border_color)

		var font := UIStyle.FONT_INDER
		var muted_col := Color(0.75, 0.68, 0.58, 0.72)
		var base_y := BAR_Y + BAR_H + 24.0
		# Left edge: [coin] 0
		_draw_coin_amount(Vector2(0.0, base_y), "0", 13, muted_col, false)
		# Right edge: [coin] MAX
		_draw_coin_amount(Vector2(size.x, base_y), "%d" % int(roundf(max_val)), 13, muted_col, true)

		# Threshold lines & indicators below (Hades Heat Gauge style)
		if max_val > 0.01:
			if min_thresh > 0.0 and min_thresh < max_val - 0.01:
				var min_x := clampf(min_thresh / max_val, 0.08, 0.92) * size.x
				var reached_min := current_val >= min_thresh - 0.01
				_draw_threshold(min_x, "MIN", int(roundf(min_thresh)), reached_min, Color(0.98, 0.92, 0.76, 1.0))
			if gen_thresh > min_thresh + 0.01 and gen_thresh < max_val - 0.01:
				var gen_x := clampf(gen_thresh / max_val, 0.10, 0.92) * size.x
				var reached_gen := current_val >= gen_thresh - 0.01
				_draw_threshold(gen_x, "GENEROUS", int(roundf(gen_thresh)), reached_gen, Color(0.82, 0.95, 0.86, 1.0))

			# Active glowing diamond pointer riding on the fill edge
			var cur_x := clampf(current_val / max_val, 0.0, 1.0) * size.x
			var ptr_c := Vector2(cur_x, BAR_Y + BAR_H * 0.5)
			_draw_diamond(ptr_c, 10.0, Color(0.05, 0.04, 0.035, 0.98))
			_draw_diamond(ptr_c, 7.5, fill_color.lightened(0.22))
			_draw_diamond(ptr_c, 3.5, Color(1.0, 0.97, 0.90, 0.95))

	func _draw_coin_amount(anchor: Vector2, num_txt: String, font_sz: int, col: Color, right_align: bool) -> void:
		var font := UIStyle.FONT_INDER
		var icon_sz := 12.0
		var gap := 3.0
		var txt_w := font.get_string_size(num_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		var total_w := (icon_sz + gap if peso_tex else 0.0) + txt_w
		var start_x := (anchor.x - total_w) if right_align else anchor.x
		if peso_tex:
			draw_texture_rect(peso_tex, Rect2(start_x, anchor.y - icon_sz + 2.0, icon_sz, icon_sz), false, Color(1, 1, 1, col.a))
			start_x += icon_sz + gap
		draw_string(font, Vector2(start_x, anchor.y), num_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, col)

	func _draw_threshold(x: float, prefix: String, amount: int, reached: bool, lit_col: Color) -> void:
		var line_col := lit_col if reached else Color(0.78, 0.72, 0.62, 0.42)
		draw_line(Vector2(x, BAR_Y - 5.0), Vector2(x, BAR_Y + BAR_H + 12.0), line_col, 1.5, true)
		_draw_diamond(Vector2(x, BAR_Y + BAR_H + 12.0), 3.5, line_col)
		var lbl_col := lit_col if reached else Color(0.76, 0.70, 0.60, 0.64)
		var font := UIStyle.FONT_INDER
		var font_sz := 13
		var prefix_txt := prefix + " · "
		var num_txt := "%d" % amount
		var icon_sz := 12.0
		var gap := 2.0
		var pre_w := font.get_string_size(prefix_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		var num_w := font.get_string_size(num_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		var total_w := pre_w + (icon_sz + gap if peso_tex else 0.0) + num_w
		var start_x := clampf(x - total_w * 0.5, 36.0, size.x - total_w - 42.0)
		var y := BAR_Y + BAR_H + 32.0
		draw_string(font, Vector2(start_x, y), prefix_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, lbl_col)
		var cur_x := start_x + pre_w
		if peso_tex:
			draw_texture_rect(peso_tex, Rect2(cur_x, y - icon_sz + 2.0, icon_sz, icon_sz), false, Color(1, 1, 1, lbl_col.a))
			cur_x += icon_sz + gap
		draw_string(font, Vector2(cur_x, y), num_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, lbl_col)

	func _draw_diamond(center: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
		]), col)

var _bold_font: FontVariation

var _player_money: float = 0.0
var _total_paid: float = 0.0
var _goal: float = 750.0
var _min_amount: float = 40.0
var _generous_amount: float = 65.0
var _max_offer: float = 0.0
var _current_offer: float = 0.0
var _last_tier: String = ""
var _is_locked: bool = false
var _phase: int = 0 # 0 = offering, 1 = resolving, 2 = card_draft

var _root: Control
var _backdrop: ColorRect
var _header_banner: PanelContainer
var _offer_frame: PanelContainer
var _center_frame: PanelContainer
var _frame_prompt_lbl: Label
var _mayari_portrait: TextureRect
var _header_title_lbl: Label
var _header_sub_lbl: Label

# Beat 1: Compact Vignette Offering Panel
var _offer_container: VBoxContainer
var _ledger_gauge: LedgerGauge
var _tier_pill_style: StyleBoxFlat
var _tier_sigil_lbl: Label
var _aura_lbl: Label
var _outcome_lbl: Label
var _amount_row: HBoxContainer
var _amount_lbl: Label
var _wallet_after_lbl: Label
var _gauge: TributeGauge
var _confirm_btn: Button
var _confirm_style: StyleBoxFlat
var _minus_btn: Button
var _plus_btn: Button

# Beat 2: Hades-style 3 Horizontal Boon Rows
var _cards_container: VBoxContainer
var _card_rows: Array[PanelContainer] = []
var _card_data_list: Array[Dictionary] = []
var _hovered_idx: int = -1
var _card_picked: bool = false
var _cards_ready: bool = false

var _confirmed_offer: float = 0.0
var _confirmed_tier: String = "balanced"

func setup(player_money: float, total_paid: float, goal: float, min_amount: float, generous_amount: float) -> void:
	_player_money = maxf(0.0, player_money)
	_total_paid = clampf(total_paid, 0.0, goal)
	_goal = maxf(1.0, goal)
	_min_amount = min_amount
	_generous_amount = generous_amount
	var remaining := maxf(0.0, _goal - _total_paid)
	_max_offer = minf(_player_money, remaining)
	if _player_money >= remaining and remaining <= _generous_amount:
		_current_offer = remaining
	elif _player_money >= _min_amount:
		_current_offer = _min_amount
	else:
		_current_offer = floorf(_max_offer / 5.0) * 5.0

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	# Soft radial vignette backdrop (keeps center atmospheric, frames edges cleanly)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color.WHITE
	var vig_shader := Shader.new()
	vig_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.15, 1.0));
	float alpha = clamp(0.52 + smoothstep(0.18, 0.85, dist) * 0.36, 0.0, 0.90);
	COLOR = vec4(0.032, 0.026, 0.022, alpha);
}
"""
	var vig_mat := ShaderMaterial.new()
	vig_mat.shader = vig_shader
	_backdrop.material = vig_mat
	_backdrop.modulate.a = 0.0
	_root.add_child(_backdrop)

	# ── 1. TOP TITLE BANNER ──
	_header_banner = PanelContainer.new()
	_header_banner.anchor_left = 0.16
	_header_banner.anchor_right = 0.84
	_header_banner.anchor_top = 0.04
	_header_banner.anchor_bottom = 0.155
	var header_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_DEEP, 6, 32, 10)
	header_style.border_color = COL_GOLD
	header_style.border_width_top = 2
	header_style.border_width_bottom = 2
	header_style.border_width_left = 2
	header_style.border_width_right = 2
	header_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	header_style.shadow_size = 16
	_header_banner.add_theme_stylebox_override("panel", header_style)
	_root.add_child(_header_banner)

	var header_v := VBoxContainer.new()
	header_v.alignment = BoxContainer.ALIGNMENT_CENTER
	header_v.add_theme_constant_override("separation", 4)
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

	# ── 2A. BEAT 1: TIGHT CENTERED VIGNETTE OFFERING PANEL (No dead empty space!) ──
	_offer_frame = PanelContainer.new()
	_offer_frame.anchor_left = 0.5
	_offer_frame.anchor_right = 0.5
	_offer_frame.anchor_top = 0.54
	_offer_frame.anchor_bottom = 0.54
	_offer_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_offer_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	_offer_frame.custom_minimum_size = Vector2(604, 0)
	var offer_style := UIStyle.create_flat_stylebox(Color(0.062, 0.055, 0.048, 0.92), 10, 32, 22)
	offer_style.border_color = Color(0.835, 0.624, 0.278, 0.72)
	offer_style.set_border_width_all(2)
	offer_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	offer_style.shadow_size = 24
	_offer_frame.add_theme_stylebox_override("panel", offer_style)
	_root.add_child(_offer_frame)

	_build_offering_panel(_offer_frame)

	# ── 2B. BEAT 2: HADES BOON FRAME (Shown only during Card Selection!) ──
	_center_frame = PanelContainer.new()
	_center_frame.anchor_left = 0.24
	_center_frame.anchor_right = 0.80
	_center_frame.anchor_top = 0.175
	_center_frame.anchor_bottom = 0.895
	_center_frame.visible = false
	_center_frame.modulate.a = 0.0
	var frame_style := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.046, 0.94), 8, 32, 22)
	frame_style.border_color = Color(0.835, 0.624, 0.278, 0.78)
	frame_style.set_border_width_all(2)
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	frame_style.shadow_size = 22
	_center_frame.add_theme_stylebox_override("panel", frame_style)
	_root.add_child(_center_frame)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 12)
	_center_frame.add_child(main_col)

	_frame_prompt_lbl = Label.new()
	_frame_prompt_lbl.text = "CHOOSE ONE:"
	_frame_prompt_lbl.visible = true
	_frame_prompt_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_frame_prompt_lbl.add_theme_font_size_override("font_size", 22)
	_frame_prompt_lbl.add_theme_color_override("font_color", COL_CREAM)
	main_col.add_child(_frame_prompt_lbl)

	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.add_theme_constant_override("separation", 12)
	main_col.add_child(_cards_container)

	# ── 3. BOTTOM-LEFT REYNA MAYARI PORTRAIT (Appears ONLY in Beat 2 Card Selection!) ──
	_mayari_portrait = TextureRect.new()
	if ResourceLoader.exists(MAYARI_SPRITE_PATH):
		_mayari_portrait.texture = load(MAYARI_SPRITE_PATH)
	_mayari_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mayari_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mayari_portrait.anchor_left = -0.02
	_mayari_portrait.anchor_right = 0.42
	_mayari_portrait.anchor_top = 0.16
	_mayari_portrait.anchor_bottom = 1.22
	_mayari_portrait.z_index = 10
	_mayari_portrait.visible = false
	_mayari_portrait.modulate.a = 0.0
	_mayari_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mayari_portrait)

func _build_offering_panel(parent: Control) -> void:
	_offer_container = VBoxContainer.new()
	_offer_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_offer_container.add_theme_constant_override("separation", 14)
	parent.add_child(_offer_container)

	# 1. Silver Ledger Progress Gauge (Inside the panel, NO X/1500 text!)
	var ledger_box := VBoxContainer.new()
	ledger_box.add_theme_constant_override("separation", 4)
	_offer_container.add_child(ledger_box)

	var ledger_cap := Label.new()
	ledger_cap.text = "SILVER LEDGER"
	ledger_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ledger_cap.add_theme_font_override("font", UIStyle.FONT_INDER)
	ledger_cap.add_theme_font_size_override("font_size", 12)
	ledger_cap.add_theme_color_override("font_color", COL_CREAM_MUTED)
	ledger_box.add_child(ledger_cap)

	_ledger_gauge = LedgerGauge.new()
	_ledger_gauge.custom_minimum_size = Vector2(540, 26)
	_ledger_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ledger_box.add_child(_ledger_gauge)

	# Subtle hairline separator
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(520, 1)
	sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sep.color = Color(0.835, 0.624, 0.278, 0.22)
	_offer_container.add_child(sep)

	# 2. Clean Tier Status Pill (NO triangle, crisp normal spacing, soft pastel tint)
	var tier_pill := PanelContainer.new()
	tier_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tier_pill.custom_minimum_size = Vector2(460, 56)
	_tier_pill_style = UIStyle.create_flat_stylebox(Color(0.095, 0.086, 0.076, 0.92), 8, 18, 8)
	_tier_pill_style.border_color = COL_TIER_BALANCED
	_tier_pill_style.set_border_width_all(1)
	tier_pill.add_theme_stylebox_override("panel", _tier_pill_style)
	_offer_container.add_child(tier_pill)

	var pill_h := HBoxContainer.new()
	pill_h.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_h.add_theme_constant_override("separation", 12)
	tier_pill.add_child(pill_h)

	_tier_sigil_lbl = Label.new()
	_tier_sigil_lbl.text = "☽"
	_tier_sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tier_sigil_lbl.add_theme_font_size_override("font_size", 24)
	pill_h.add_child(_tier_sigil_lbl)

	var pill_txt := VBoxContainer.new()
	pill_txt.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_txt.add_theme_constant_override("separation", 1)
	pill_h.add_child(pill_txt)

	_aura_lbl = Label.new()
	_aura_lbl.add_theme_font_override("font", _bold_font)
	_aura_lbl.add_theme_font_size_override("font_size", 19)
	pill_txt.add_child(_aura_lbl)

	_outcome_lbl = Label.new()
	_outcome_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_outcome_lbl.add_theme_font_size_override("font_size", 13)
	_outcome_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	pill_txt.add_child(_outcome_lbl)

	# 3. Sleek Peso Coin Readout + Framed Steppers
	var num_col := VBoxContainer.new()
	num_col.alignment = BoxContainer.ALIGNMENT_CENTER
	num_col.add_theme_constant_override("separation", 4)
	_offer_container.add_child(num_col)

	var num_row := HBoxContainer.new()
	num_row.alignment = BoxContainer.ALIGNMENT_CENTER
	num_row.add_theme_constant_override("separation", 20)
	num_col.add_child(num_row)

	_minus_btn = _make_chevron("‹")
	_minus_btn.pressed.connect(func(): _nudge_offer(-5.0))
	num_row.add_child(_minus_btn)

	_amount_row = HBoxContainer.new()
	_amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_amount_row.custom_minimum_size = Vector2(150, 0)
	_amount_row.add_theme_constant_override("separation", 8)
	num_row.add_child(_amount_row)

	var big_coin := TextureRect.new()
	big_coin.texture = PESO_ICON
	big_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_coin.custom_minimum_size = Vector2(34, 34)
	big_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_amount_row.add_child(big_coin)

	_amount_lbl = Label.new()
	_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_lbl.add_theme_font_override("font", _bold_font)
	_amount_lbl.add_theme_font_size_override("font_size", 46)
	_amount_lbl.add_theme_color_override("font_color", COL_TIER_BALANCED_BRIGHT)
	_amount_lbl.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
	_amount_lbl.add_theme_constant_override("outline_size", 4)
	_amount_row.add_child(_amount_lbl)

	_plus_btn = _make_chevron("›")
	_plus_btn.pressed.connect(func(): _nudge_offer(5.0))
	num_row.add_child(_plus_btn)

	var wallet_row := HBoxContainer.new()
	wallet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet_row.add_theme_constant_override("separation", 5)
	num_col.add_child(wallet_row)

	var wallet_pre := Label.new()
	wallet_pre.text = "Wallet after tribute:"
	wallet_pre.add_theme_font_override("font", UIStyle.FONT_INDER)
	wallet_pre.add_theme_font_size_override("font_size", 13)
	wallet_pre.add_theme_color_override("font_color", COL_CREAM_MUTED)
	wallet_row.add_child(wallet_pre)

	var small_coin := TextureRect.new()
	small_coin.texture = PESO_ICON
	small_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	small_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	small_coin.custom_minimum_size = Vector2(15, 15)
	small_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_row.add_child(small_coin)

	_wallet_after_lbl = Label.new()
	_wallet_after_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_wallet_after_lbl.add_theme_font_size_override("font_size", 13)
	_wallet_after_lbl.add_theme_color_override("font_color", COL_CREAM)
	wallet_row.add_child(_wallet_after_lbl)

	# 4. Interactive Hades Heat-Gauge with threshold lines & peso-coin indicators below
	_gauge = TributeGauge.new()
	_gauge.peso_tex = PESO_ICON
	_gauge.custom_minimum_size = Vector2(540, 74)
	_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gauge.value_changed.connect(_on_slider_changed)
	_offer_container.add_child(_gauge)

	# 5. Clean Confirm CTA Button
	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(260, 48)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_confirm_btn.add_theme_font_override("font", _bold_font)
	_confirm_btn.add_theme_font_size_override("font_size", 19)
	_confirm_style = UIStyle.create_flat_stylebox(Color(0.45, 0.36, 0.22, 1.0), 8, 24, 10)
	_confirm_style.border_color = COL_CREAM
	_confirm_style.set_border_width_all(2)
	_apply_confirm_style(COL_TIER_BALANCED)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_offer_container.add_child(_confirm_btn)

func _make_chevron(glyph: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(40, 40)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var s := UIStyle.create_flat_stylebox(Color(0.11, 0.095, 0.082, 0.92), 8, 0, 0)
	s.border_color = Color(0.835, 0.624, 0.278, 0.50)
	s.set_border_width_all(1)
	var h: StyleBoxFlat = s.duplicate()
	h.bg_color = Color(0.20, 0.16, 0.12, 0.96)
	h.border_color = COL_GOLD_BRIGHT
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("disabled", s)
	btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", COL_CREAM_MUTED)
	btn.add_theme_color_override("font_hover_color", COL_CREAM)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	return btn

func _apply_confirm_style(accent: Color) -> void:
	var base_bg := Color(accent.r * 0.44, accent.g * 0.42, accent.b * 0.36, 0.94)
	_confirm_style.bg_color = base_bg
	_confirm_style.border_color = accent.lightened(0.18)
	var hov: StyleBoxFlat = _confirm_style.duplicate()
	hov.bg_color = base_bg.lightened(0.14)
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
	_amount_lbl.text = "%d" % int(roundf(_current_offer))
	var wallet_left := maxf(0.0, _player_money - _current_offer)
	_wallet_after_lbl.text = "%d" % int(roundf(wallet_left))

	var accent: Color = COL_TIER_BALANCED
	var accent_bright: Color = COL_TIER_BALANCED_BRIGHT
	var sigil := "☽"

	match tier:
		"cleared":
			accent = COL_TIER_CLEARED
			accent_bright = COL_TIER_CLEARED_BRIGHT
			sigil = "✦"
			_aura_lbl.text = "SEAL THE PACT"
			_outcome_lbl.text = "Debt cleared — choose 1 of 3 Favors"
			_confirm_btn.text = "SEAL LEDGER"
		"generous":
			accent = COL_TIER_GENEROUS
			accent_bright = COL_TIER_GENEROUS_BRIGHT
			sigil = "★"
			_aura_lbl.text = "GENEROUS"
			_outcome_lbl.text = "Choose 1 of 3 Favors"
			_confirm_btn.text = "OFFER GENEROUSLY"
		"balanced":
			accent = COL_TIER_BALANCED
			accent_bright = COL_TIER_BALANCED_BRIGHT
			sigil = "☽"
			_aura_lbl.text = "BALANCED"
			_outcome_lbl.text = "Choose 1 of 3 mixed cards (Favor & Chill)"
			_confirm_btn.text = "OFFER TRIBUTE"
		_:
			accent = COL_TIER_SHORTFALL
			accent_bright = COL_TIER_SHORTFALL_BRIGHT
			sigil = "◌"
			_aura_lbl.text = "SHORTFALL"
			_outcome_lbl.text = "Choose 1 of 3 Chills"
			_confirm_btn.text = "OFFER NOTHING" if _current_offer <= 0.01 else "OFFER SHORTFALL"

	_tier_pill_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	_tier_pill_style.bg_color = Color(
		lerpf(0.08, accent.r * 0.22, 0.35),
		lerpf(0.072, accent.g * 0.20, 0.35),
		lerpf(0.065, accent.b * 0.18, 0.35),
		0.92
	)
	_tier_sigil_lbl.text = sigil
	_tier_sigil_lbl.add_theme_color_override("font_color", accent_bright)
	_aura_lbl.add_theme_color_override("font_color", accent_bright)
	_amount_lbl.add_theme_color_override("font_color", accent_bright)
	_apply_confirm_style(accent)
	_gauge.set_state(_current_offer, _max_offer, _min_amount, _generous_amount, accent, accent_bright)

	# Update overall Silver Ledger progress bar (paid + live tribute preview)
	var paid_r := _total_paid / _goal
	var preview_r := (_total_paid + _current_offer) / _goal
	_ledger_gauge.set_progress(paid_r, preview_r, accent)

	if animate_pop:
		_amount_row.pivot_offset = _amount_row.size * 0.5
		var pop := create_tween()
		pop.tween_property(_amount_row, "scale", Vector2(1.06, 1.06), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(_amount_row, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE)
		if tier != _last_tier:
			_last_tier = tier
			EventBus.request_sfx.emit("interact")
	elif _last_tier == "":
		_last_tier = tier

func _play_entrance() -> void:
	_header_banner.modulate.a = 0.0
	_header_banner.offset_top = -24.0
	_header_banner.offset_bottom = -24.0
	_offer_frame.modulate.a = 0.0
	_offer_frame.scale = Vector2(0.96, 0.96)

	await get_tree().process_frame
	if not is_inside_tree():
		return
	_offer_frame.pivot_offset = _offer_frame.size * 0.5

	var tw := create_tween()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_header_banner, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_header_banner, "offset_top", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_header_banner, "offset_bottom", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_offer_frame, "modulate:a", 1.0, 0.28).set_delay(0.05).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_offer_frame, "scale", Vector2.ONE, 0.32).set_delay(0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Resolution & Transition to Hades Boon Stack ──────────────────────────────

func _on_confirm_pressed() -> void:
	if _is_locked:
		return
	_is_locked = true
	_phase = 1
	_gauge.interactive = false
	_confirm_btn.disabled = true
	_minus_btn.disabled = true
	_plus_btn.disabled = true

	_confirmed_offer = _current_offer
	_confirmed_tier = _evaluate_tier(_confirmed_offer)
	EventBus.request_sfx.emit("money_decrease" if _confirmed_offer > 0.0 else "interact")

	_offer_frame.pivot_offset = _offer_frame.size * 0.5
	var fade_tw := create_tween()
	fade_tw.tween_property(_offer_frame, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	fade_tw.parallel().tween_property(_offer_frame, "scale", Vector2(0.96, 0.96), 0.22).set_trans(Tween.TRANS_QUAD)
	await fade_tw.finished
	if not is_inside_tree():
		return

	_offer_frame.visible = false
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return

	_launch_hades_card_stack()

# ── Beat 2: Hades-Style 3 Horizontal Boon Rows ───────────────────────────────

func _launch_hades_card_stack() -> void:
	_phase = 2
	_card_data_list = MayariCardRegistry.draw_three_cards(_confirmed_tier)
	_card_rows.clear()
	_card_picked = false
	_hovered_idx = -1
	_cards_ready = false

	_frame_prompt_lbl.text = "CHOOSE ONE:"
	_frame_prompt_lbl.visible = true
	match _confirmed_tier:
		"cleared":
			_header_title_lbl.text = "T H E   P A C T   I S   S E A L E D"
			_header_sub_lbl.text = "Choose one final blessing of Biringan for tomorrow."
		"generous":
			_header_title_lbl.text = "F A V O R   O F   B I R I N G A N"
			_header_sub_lbl.text = "Choose one lunar blessing for tomorrow."
		"shortfall":
			_header_title_lbl.text = "C H I L L   O F   B I R I N G A N"
			_header_sub_lbl.text = "Choose one omen to endure tomorrow."
		_:
			_header_title_lbl.text = "M O O N   O F   B I R I N G A N"
			_header_sub_lbl.text = "The moon deals a mixed hand for tomorrow."

	for child in _cards_container.get_children():
		child.queue_free()

	_center_frame.visible = true
	_center_frame.modulate.a = 0.0
	_mayari_portrait.visible = true
	_mayari_portrait.modulate.a = 0.0
	_mayari_portrait.offset_left = -80.0
	_mayari_portrait.offset_right = -80.0

	var reveal_tw := create_tween()
	reveal_tw.tween_property(_center_frame, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
	reveal_tw.parallel().tween_property(_mayari_portrait, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	reveal_tw.parallel().tween_property(_mayari_portrait, "offset_left", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tw.parallel().tween_property(_mayari_portrait, "offset_right", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for i in range(_card_data_list.size()):
		var row := _create_hades_boon_row(_card_data_list[i], i)
		row.modulate.a = 0.0
		_cards_container.add_child(row)
		_card_rows.append(row)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	var last_tw: Tween = null
	for i in range(_card_rows.size()):
		var row := _card_rows[i]
		row.pivot_offset = row.size * 0.5
		row.scale = Vector2(0.95, 0.95)
		var tw := create_tween()
		tw.tween_interval(0.05 + i * 0.09)
		tw.tween_callback(func(): EventBus.request_sfx.emit("interact"))
		tw.tween_property(row, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(row, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last_tw = tw

	if last_tw:
		await last_tw.finished
	_cards_ready = true

func _create_hades_boon_row(c_data: Dictionary, index: int) -> PanelContainer:
	var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
	var pal: Dictionary = HadesEmblem.palette("favor" if is_fav else "chill")
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]
	var row_bg: Color = pal["bg"]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 146)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style := UIStyle.create_flat_stylebox(row_bg, 6, 16, 12)
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
	hbox.add_theme_constant_override("separation", 20)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# Left Hades-style rotated diamond emblem with upright centered sigil
	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(122, 122)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	emblem.fill_color = Color(0.0, 0.0, 0.0, 0.0)
	hbox.add_child(emblem)

	var sigil_lbl := Label.new()
	sigil_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	sigil_lbl.text = str(c_data.get("sigil", "☽"))
	sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_lbl.add_theme_font_size_override("font_size", 42)
	sigil_lbl.add_theme_color_override("font_color", accent_bright)
	sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(sigil_lbl)

	# Middle text stack: Uppercase Title + Rarity tag, rich bold description, aligned Hades stat rows
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 4)
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
	rarity_lbl.text = "FAVOR" if is_fav else "CHILL"
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
	desc_rt.add_theme_font_size_override("normal_font_size", 16)
	desc_rt.add_theme_font_size_override("bold_font_size", 16)
	desc_rt.add_theme_color_override("default_color", COL_CREAM_MUTED)
	var raw_desc := str(c_data.get("description_rich", c_data.get("description", "")))
	desc_rt.text = raw_desc.replace("[b]", "[b][color=%s]" % COL_BOLD_CREAM).replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

	# Hades-style stat breakdown rows:  ▸ Stat Name:         +Value
	var stats: Array = c_data.get("stats", [])
	if stats.is_empty():
		var hook_lbl := Label.new()
		hook_lbl.text = "▸  " + str(c_data.get("tagline", ""))
		hook_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		hook_lbl.add_theme_font_size_override("font_size", 17)
		hook_lbl.add_theme_color_override("font_color", COL_CREAM)
		hook_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(hook_lbl)
	else:
		var stats_box := VBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 2)
		stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(stats_box)
		for st in stats:
			var stat_dict: Dictionary = st
			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 12)
			s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_box.add_child(s_row)

			var s_name := Label.new()
			s_name.text = "▸ " + str(stat_dict.get("label", ""))
			s_name.custom_minimum_size = Vector2(300, 0)
			s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
			s_name.add_theme_font_size_override("font_size", 17)
			s_name.add_theme_color_override("font_color", COL_CREAM)
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", _bold_font)
			s_val.add_theme_font_size_override("font_size", 18)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := COL_STAT_POS if tone == "pos" else (COL_STAT_NEG if tone == "neg" else COL_GOLD_BRIGHT)
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)

	card.mouse_entered.connect(_on_row_hovered.bind(index, true))
	card.mouse_exited.connect(_on_row_hovered.bind(index, false))
	card.gui_input.connect(_on_row_gui_input.bind(index))
	return card

func _on_row_hovered(index: int, is_hovered: bool) -> void:
	if _card_picked or not _cards_ready or index < 0 or index >= _card_rows.size():
		return
	if is_hovered:
		_hovered_idx = index
		EventBus.request_sfx.emit("interact")
	elif _hovered_idx == index:
		_hovered_idx = -1

	for i in range(_card_rows.size()):
		var row := _card_rows[i]
		if not is_instance_valid(row):
			continue
		var style: StyleBoxFlat = row.get_meta("card_style")
		var accent: Color = row.get_meta("accent")
		var accent_bright: Color = row.get_meta("accent_bright")
		row.pivot_offset = row.size * 0.5
		var tw := create_tween()
		if _hovered_idx == i:
			style.border_color = accent_bright
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_width_left = 6
			tw.tween_property(row, "scale", Vector2(1.025, 1.025), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(row, "modulate", Color.WHITE, 0.12)
		else:
			style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_width_left = 4
			var dim := Color(0.76, 0.72, 0.68, 0.88) if _hovered_idx != -1 else Color.WHITE
			tw.tween_property(row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(row, "modulate", dim, 0.14)

func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if _card_picked or not _cards_ready:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_row(index)

func _select_row(index: int) -> void:
	if _card_picked or index < 0 or index >= _card_data_list.size():
		return
	_card_picked = true
	var chosen_data: Dictionary = _card_data_list[index]
	var chosen_id := str(chosen_data.get("id", ""))
	var is_fav := str(chosen_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR

	EventBus.request_sfx.emit("purchase" if is_fav else "interact")
	_header_title_lbl.text = str(chosen_data.get("title", "")).to_upper()
	_header_sub_lbl.text = "Active tomorrow · " + str(chosen_data.get("tagline", ""))

	for i in range(_card_rows.size()):
		var row := _card_rows[i]
		if not is_instance_valid(row):
			continue
		var tw := create_tween()
		if i == index:
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
	await _fade_out_and_finish(chosen_id)

func _fade_out_and_finish(selected_card_id: String) -> void:
	var fade := create_tween()
	fade.tween_property(_backdrop, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	fade.parallel().tween_property(_mayari_portrait, "modulate:a", 0.0, 0.22)
	fade.parallel().tween_property(_header_banner, "modulate:a", 0.0, 0.22)
	fade.parallel().tween_property(_center_frame, "modulate:a", 0.0, 0.22)
	await fade.finished
	completed.emit(_confirmed_offer, _confirmed_tier, selected_card_id)
	queue_free()
