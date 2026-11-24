class_name MayariTallyOverlay
extends CanvasLayer

## Hades-inspired split-screen ritual for Reyna Mayari's Nightly Tally:
## - Beat 1 & Beat 2 share the EXACT same 3 card slots inside the center frame so confirming
##   your tribute physically flips the 3 shadow previews in place to reveal tomorrow's cards.
## - A single unified Silver Ledger Gauge at the bottom combines overall ledger progress
##   (solid antique gold) with tonight's interactive tribute (animated pastel stripes),
##   diamond end-caps & handlebar thumb, threshold indicators below, and a floating
##   [< [coin] amount >] control riding directly on top of the adjustable thumb line.

signal completed(offer_amount: float, tier: String, selected_card_id: String)

const MAYARI_SPRITE_PATH := "res://Assets/characters/sprites/ReynaMayari.png"
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
const COL_TIER_MEAGER := Color(0.52, 0.72, 0.92, 1.0)          # Soft pastel omen blue
const COL_TIER_MEAGER_BRIGHT := Color(0.74, 0.87, 0.99, 1.0)
const COL_TIER_FAIR := Color(0.88, 0.79, 0.58, 1.0)            # Soft buttercream gold
const COL_TIER_FAIR_BRIGHT := Color(0.98, 0.92, 0.76, 1.0)
const COL_TIER_LAVISH := Color(0.95, 0.82, 0.46, 1.0)          # Soft warm favor gold
const COL_TIER_LAVISH_BRIGHT := Color(1.0, 0.93, 0.68, 1.0)
const COL_TIER_SEALED := Color(0.96, 0.91, 0.76, 1.0)          # Luminous champagne
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

	const BAR_Y := 34.0
	const BAR_H := 22.0

	var total_paid: float = 0.0
	var goal: float = 1500.0
	var current_offer: float = 0.0
	var max_offer: float = 100.0
	var min_thresh: float = 40.0
	var gen_thresh: float = 65.0
	var fill_color: Color = Color(0.88, 0.79, 0.58, 1.0)
	var border_color: Color = Color(0.98, 0.92, 0.76, 0.92)
	var peso_tex: Texture2D = null
	var bold_font: Font = null
	var interactive: bool = true

	var _dragging: bool = false
	var _stripe_scroll: float = 0.0
	var _preview_rect: ColorRect
	var _stripe_mat: ShaderMaterial

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

	func _process(delta: float) -> void:
		_stripe_scroll += delta * 0.55
		if _stripe_mat:
			_stripe_mat.set_shader_parameter("scroll_offset", _stripe_scroll)
			_stripe_mat.set_shader_parameter("base_color", fill_color)

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
		_sync_visuals()
		queue_redraw()

	func pop_amount() -> void:
		if not is_instance_valid(_amount_lbl):
			return
		_amount_lbl.pivot_offset = _amount_lbl.size * 0.5
		var tw := create_tween()
		tw.tween_property(_amount_lbl, "scale", Vector2(1.14, 1.14), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_amount_lbl, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE)

	func _gui_input(event: InputEvent) -> void:
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
		elif event is InputEventMouseMotion and _dragging:
			var mm := event as InputEventMouseMotion
			_emit_from_x(mm.position.x)

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

		# Crisp outer & inner gold frame
		var frame_col := Color(0.835, 0.624, 0.278, 0.85)
		draw_rect(bar_rect, frame_col, false, 2.0)
		draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)

		# End-cap diamond ornaments (left & right)
		_draw_diamond(Vector2(0.0, BAR_Y + BAR_H * 0.5), 4.5, frame_col)
		_draw_diamond(Vector2(size.x, BAR_Y + BAR_H * 0.5), 4.5, frame_col)

		# Seam line where already-paid meets tonight's tribute
		if paid_x > pad + 2.0:
			draw_line(Vector2(paid_x, BAR_Y - 2.0), Vector2(paid_x, BAR_Y + BAR_H + 2.0), Color(1.0, 0.94, 0.80, 0.65), 1.5, true)

		# Thin vertical FAIR & LAVISH threshold lines + collision-free peso indicators below
		var show_min := min_thresh > 0.0 and total_paid + min_thresh < g - 0.01
		var show_gen := gen_thresh > min_thresh + 0.01 and total_paid + gen_thresh < g - 0.01
		var min_x := _ratio_to_x((total_paid + min_thresh) / g)
		var gen_x := _ratio_to_x((total_paid + gen_thresh) / g)
		var close_pair := show_min and show_gen and (gen_x - min_x) < 118.0

		if show_min:
			var reached_min := current_offer >= min_thresh - 0.01
			_draw_threshold(min_x, "FAIR", int(roundf(min_thresh)), reached_min, Color(0.98, 0.92, 0.76, 1.0), -1 if close_pair else 0)
		if show_gen:
			var reached_gen := current_offer >= gen_thresh - 0.01
			_draw_threshold(gen_x, "LAVISH", int(roundf(gen_thresh)), reached_gen, Color(1.0, 0.93, 0.68, 1.0), 1 if close_pair else 0)

		# Connector stem from floating readout down into glowing diamond handlebar thumb
		draw_line(Vector2(cur_x, BAR_Y - 8.0), Vector2(cur_x, BAR_Y), Color(border_color.r, border_color.g, border_color.b, 0.72), 1.5, true)
		var ptr_c := Vector2(cur_x, BAR_Y + BAR_H * 0.5)
		_draw_diamond(ptr_c, 10.5, Color(0.05, 0.04, 0.035, 0.98))
		_draw_diamond(ptr_c, 7.8, fill_color.lightened(0.20))
		_draw_diamond(ptr_c, 3.4, Color(1.0, 0.97, 0.90, 0.96))

	func _draw_threshold(x: float, prefix: String, amount: int, reached: bool, lit_col: Color, align_bias: int) -> void:
		var line_col := lit_col if reached else Color(0.78, 0.72, 0.62, 0.44)
		draw_line(Vector2(x, BAR_Y - 4.0), Vector2(x, BAR_Y + BAR_H + 11.0), line_col, 1.5, true)
		_draw_diamond(Vector2(x, BAR_Y + BAR_H + 11.0), 3.3, line_col)
		var lbl_col := lit_col if reached else Color(0.76, 0.70, 0.60, 0.66)
		var font := UIStyle.FONT_INDER
		var font_sz := 12
		var prefix_txt := prefix + " · "
		var num_txt := "%d" % amount
		var icon_sz := 11.0
		var gap := 2.0
		var pre_w := font.get_string_size(prefix_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		var num_w := font.get_string_size(num_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		var total_w := pre_w + (icon_sz + gap if peso_tex else 0.0) + num_w

		var start_x: float
		if align_bias < 0:
			# Pull cleanly left of the FAIR tick so it never collides with LAVISH
			start_x = clampf(x - total_w - 6.0, 0.0, maxf(0.0, size.x - total_w))
		elif align_bias > 0:
			# Push cleanly right of the LAVISH tick so it never collides with FAIR
			start_x = clampf(x + 6.0, 0.0, maxf(0.0, size.x - total_w))
		else:
			start_x = clampf(x - total_w * 0.5, 0.0, maxf(0.0, size.x - total_w))

		var y := BAR_Y + BAR_H + 29.0
		draw_string(font, Vector2(start_x, y), prefix_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, lbl_col)
		var cx := start_x + pre_w
		if peso_tex:
			draw_texture_rect(peso_tex, Rect2(cx, y - icon_sz + 2.0, icon_sz, icon_sz), false, Color(1, 1, 1, lbl_col.a))
			cx += icon_sz + gap
		draw_string(font, Vector2(cx, y), num_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, lbl_col)

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
var _goal: float = 1500.0
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

# Shared Top Prompt Row
var _frame_prompt_lbl: Label
var _tier_badge: PanelContainer
var _tier_badge_style: StyleBoxFlat
var _tier_badge_lbl: Label

# Shared 3 Card Slots (EXACT same size & position in Beat 1 and Beat 2!)
var _card_slots: Array[Control] = []
var _shadow_rows: Array[Dictionary] = []

# Unified Bottom Ledger Gauge Dock + Overlapping Bottom-Right Offer Button
var _gauge_dock: VBoxContainer
var _unified_gauge: UnifiedLedgerGauge
var _confirm_btn: Button
var _confirm_style: StyleBoxFlat

# Beat 2: Revealed Hades Boon Rows (placed inside the exact same _card_slots!)
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

	# Clean uniform dark backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.035, 0.028, 0.024, 0.74)
	_backdrop.modulate.a = 0.0
	_root.add_child(_backdrop)

	# ── 1. TOP WIDE TITLE BANNER ──
	_header_banner = PanelContainer.new()
	_header_banner.anchor_left = 0.14
	_header_banner.anchor_right = 0.86
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
	_center_frame.anchor_left = 0.24
	_center_frame.anchor_right = 0.80
	_center_frame.anchor_top = 0.165
	_center_frame.anchor_bottom = 0.905
	var frame_style := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.046, 0.94), 8, 26, 16)
	frame_style.border_color = Color(0.835, 0.624, 0.278, 0.78)
	frame_style.set_border_width_all(2)
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	frame_style.shadow_size = 22
	_center_frame.add_theme_stylebox_override("panel", frame_style)
	_root.add_child(_center_frame)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 10)
	_center_frame.add_child(main_col)

	# Top prompt row (shared by Beat 1 & Beat 2)
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 10)
	main_col.add_child(prompt_row)

	_frame_prompt_lbl = Label.new()
	_frame_prompt_lbl.text = "TOMORROW'S HAND:"
	_frame_prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame_prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_frame_prompt_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_frame_prompt_lbl.add_theme_font_size_override("font_size", 20)
	_frame_prompt_lbl.add_theme_color_override("font_color", COL_CREAM)
	prompt_row.add_child(_frame_prompt_lbl)

	_tier_badge = PanelContainer.new()
	_tier_badge_style = UIStyle.create_flat_stylebox(Color(0.11, 0.095, 0.08, 0.94), 6, 12, 3)
	_tier_badge_style.border_color = COL_TIER_FAIR
	_tier_badge_style.set_border_width_all(1)
	_tier_badge.add_theme_stylebox_override("panel", _tier_badge_style)
	prompt_row.add_child(_tier_badge)

	_tier_badge_lbl = Label.new()
	_tier_badge_lbl.add_theme_font_override("font", _bold_font)
	_tier_badge_lbl.add_theme_font_size_override("font_size", 13)
	_tier_badge.add_child(_tier_badge_lbl)

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
		slot.custom_minimum_size = Vector2(0, 118)
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
	_unified_gauge.custom_minimum_size = Vector2(0, 88)
	_unified_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unified_gauge.value_changed.connect(_on_slider_changed)
	_unified_gauge.nudge_requested.connect(_nudge_offer)
	_gauge_dock.add_child(_unified_gauge)

	# ── 3. BOTTOM-RIGHT OVERLAPPING OFFER BUTTON (Straddling the frame's bottom border!) ──
	_confirm_btn = Button.new()
	_confirm_btn.anchor_left = 0.80
	_confirm_btn.anchor_right = 0.80
	_confirm_btn.anchor_top = 0.905
	_confirm_btn.anchor_bottom = 0.905
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

	# ── 4. BOTTOM-LEFT REYNA MAYARI PORTRAIT (Uncropped, slightly smaller & tucked left/down) ──
	_mayari_portrait = TextureRect.new()
	if ResourceLoader.exists(MAYARI_SPRITE_PATH):
		_mayari_portrait.texture = load(MAYARI_SPRITE_PATH)
	_mayari_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mayari_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mayari_portrait.anchor_left = -0.03
	_mayari_portrait.anchor_right = 0.36
	_mayari_portrait.anchor_top = 0.26
	_mayari_portrait.anchor_bottom = 1.19
	_mayari_portrait.z_index = 10
	_mayari_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mayari_portrait)

func _create_preview_shadow_row(_index: int) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := UIStyle.create_flat_stylebox(Color(0.048, 0.045, 0.042, 0.92), 6, 16, 10)
	style.border_color = Color(0.88, 0.79, 0.58, 0.48)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	card.add_child(hbox)

	# Same footprint as Beat 2's HadesEmblem so the flip lines up seamlessly!
	var diamond := MysteryDiamond.new()
	diamond.custom_minimum_size = Vector2(96, 96)
	diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(diamond)

	var q_lbl := Label.new()
	q_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	q_lbl.text = "?"
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_override("font", _bold_font)
	q_lbl.add_theme_font_size_override("font_size", 36)
	diamond.add_child(q_lbl)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 4)
	hbox.add_child(mid)

	var top_line := HBoxContainer.new()
	mid.add_child(top_line)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 22)
	top_line.add_child(title_lbl)

	var tag_lbl := Label.new()
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_override("font", _bold_font)
	tag_lbl.add_theme_font_size_override("font_size", 17)
	top_line.add_child(tag_lbl)

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
	var badge_txt := "☽ FAIR"
	var shadow_title := "UNREVEALED FATE"
	var shadow_desc := "Each slot rolls 65% Omen or 35% Favor — choose 1 of 3."
	var shadow_tag := "65% OMEN  ·  35% FAVOR"
	var shadow_bg := Color(0.060, 0.058, 0.064, 0.94)
	var shadow_q := "?"

	match tier:
		"cleared":
			accent = COL_TIER_SEALED
			accent_bright = COL_TIER_SEALED_BRIGHT
			badge_txt = "✦ SEALED"
			shadow_title = "FINAL BLESSING"
			shadow_desc = "The Silver Ledger is sealed — choose 1 of 3 guaranteed Favors."
			shadow_tag = "100% FAVOR"
			shadow_bg = Color(0.095, 0.084, 0.056, 0.94)
			shadow_q = "✦"
			_confirm_btn.text = "SEAL LEDGER"
		"generous":
			accent = COL_TIER_LAVISH
			accent_bright = COL_TIER_LAVISH_BRIGHT
			badge_txt = "★ LAVISH"
			shadow_title = "UNREVEALED FAVOR"
			shadow_desc = "A generous lunar blessing awaits — choose 1 of 3 Favors."
			shadow_tag = "100% FAVOR"
			shadow_bg = Color(0.092, 0.080, 0.050, 0.94)
			shadow_q = "?"
			_confirm_btn.text = "OFFER LAVISHLY"
		"balanced":
			accent = COL_TIER_FAIR
			accent_bright = COL_TIER_FAIR_BRIGHT
			badge_txt = "☽ FAIR"
			shadow_title = "UNREVEALED FATE"
			shadow_desc = "Each card rolls 65% Omen or 35% Favor — choose 1 of 3."
			shadow_tag = "65% OMEN  ·  35% FAVOR"
			shadow_bg = Color(0.062, 0.060, 0.066, 0.94)
			shadow_q = "?"
			_confirm_btn.text = "OFFER TRIBUTE"
		_:
			accent = COL_TIER_MEAGER
			accent_bright = COL_TIER_MEAGER_BRIGHT
			badge_txt = "◌ MEAGER"
			shadow_title = "UNREVEALED OMEN"
			shadow_desc = "An uneasy lunar trial awaits — choose 1 of 3 Omens."
			shadow_tag = "100% OMEN"
			shadow_bg = Color(0.048, 0.062, 0.090, 0.94)
			shadow_q = "?"
			_confirm_btn.text = "OFFER NOTHING" if _current_offer <= 0.01 else "OFFER MEAGER"

	_tier_badge_lbl.text = badge_txt
	_tier_badge_lbl.add_theme_color_override("font_color", accent_bright)
	_tier_badge_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	_tier_badge_style.bg_color = Color(
		lerpf(0.075, accent.r * 0.22, 0.35),
		lerpf(0.070, accent.g * 0.20, 0.35),
		lerpf(0.066, accent.b * 0.20, 0.35),
		0.94
	)

	var tier_changed := (_last_tier != "" and tier != _last_tier)
	for i in range(_shadow_rows.size()):
		var sr: Dictionary = _shadow_rows[i]
		var st: StyleBoxFlat = sr["style"]
		var dm: MysteryDiamond = sr["diamond"]
		var ql: Label = sr["q_lbl"]
		var tl: Label = sr["title_lbl"]
		var tg: Label = sr["tag_lbl"]
		var dl: Label = sr["desc_lbl"]

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
		tg.add_theme_color_override("font_color", Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.88))
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

	# Fade out the bottom gauge dock, tier badge, and overlapping CTA while keeping the 3 slots locked in place!
	var fade_tw := create_tween().set_parallel(true)
	fade_tw.tween_property(_gauge_dock, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	fade_tw.tween_property(_tier_badge, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	fade_tw.tween_property(_confirm_btn, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	await fade_tw.finished
	if not is_inside_tree():
		return

	_confirm_btn.visible = false
	_tier_badge.visible = false
	_gauge_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_launch_hades_card_flip()

# ── Beat 2: In-Place Card Flip Reveal ────────────────────────────────────────

func _launch_hades_card_flip() -> void:
	_phase = 2
	_card_data_list = MayariCardRegistry.draw_three_cards(_confirmed_tier)
	_card_rows.clear()
	_card_picked = false
	_hovered_idx = -1
	_cards_ready = false

	_frame_prompt_lbl.text = "CHOOSE ONE:"
	match _confirmed_tier:
		"cleared":
			_header_title_lbl.text = "T H E   P A C T   I S   S E A L E D"
			_header_sub_lbl.text = "Choose one final Favor for tomorrow."
		"generous":
			_header_title_lbl.text = "F A V O R   O F   B I R I N G A N"
			_header_sub_lbl.text = "Choose one Favor for tomorrow."
		"shortfall":
			_header_title_lbl.text = "O M E N   O F   B I R I N G A N"
			_header_sub_lbl.text = "Choose one Omen to endure tomorrow."
		_:
			_header_title_lbl.text = "M O O N   O F   B I R I N G A N"
			_header_sub_lbl.text = "The moon deals a mixed hand for tomorrow."

	# Pre-create the 3 revealed cards inside the EXACT same slots (hidden until flip midpoint)
	for i in range(mini(_card_data_list.size(), _card_slots.size())):
		var row := _create_hades_boon_row(_card_data_list[i], i)
		row.visible = false
		_card_slots[i].add_child(row)
		_card_rows.append(row)

	await get_tree().process_frame
	if not is_inside_tree():
		return

	# Staggered vertical card flip: shadow collapses scale.y 1 -> 0, swaps to revealed card, pops 0 -> 1!
	var last_tw: Tween = null
	for i in range(_card_rows.size()):
		var shadow_panel: PanelContainer = _shadow_rows[i]["panel"]
		var revealed_row: PanelContainer = _card_rows[i]
		shadow_panel.pivot_offset = shadow_panel.size * 0.5
		revealed_row.pivot_offset = shadow_panel.size * 0.5

		var tw := create_tween()
		tw.tween_interval(i * 0.11)
		tw.tween_property(shadow_panel, "scale:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			shadow_panel.visible = false
			revealed_row.visible = true
			revealed_row.pivot_offset = revealed_row.size * 0.5
			revealed_row.scale = Vector2(1.0, 0.0)
			EventBus.request_sfx.emit("interact")
		)
		tw.tween_property(revealed_row, "scale:y", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last_tw = tw

	if last_tw:
		await last_tw.finished
	_cards_ready = true

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
	hbox.add_theme_constant_override("separation", 18)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(96, 96)
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
	sigil_lbl.add_theme_font_size_override("font_size", 36)
	sigil_lbl.add_theme_color_override("font_color", accent_bright)
	sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.add_child(sigil_lbl)

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
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", accent_bright)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(title_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = "FAVOR" if is_fav else "OMEN"
	rarity_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_override("font", _bold_font)
	rarity_lbl.add_theme_font_size_override("font_size", 19)
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
	desc_rt.add_theme_font_size_override("normal_font_size", 15)
	desc_rt.add_theme_font_size_override("bold_font_size", 15)
	desc_rt.add_theme_color_override("default_color", COL_CREAM_MUTED)
	var raw_desc := str(c_data.get("description_rich", c_data.get("description", "")))
	desc_rt.text = raw_desc.replace("[b]", "[b][color=%s]" % COL_BOLD_CREAM).replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

	var stats: Array = c_data.get("stats", [])
	if stats.is_empty():
		var hook_lbl := Label.new()
		hook_lbl.text = "▸  " + str(c_data.get("tagline", ""))
		hook_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		hook_lbl.add_theme_font_size_override("font_size", 15)
		hook_lbl.add_theme_color_override("font_color", COL_CREAM)
		hook_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(hook_lbl)
	else:
		var stats_box := VBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 1)
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
			s_name.custom_minimum_size = Vector2(280, 0)
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
			tw.tween_property(row, "scale", Vector2(1.022, 1.022), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
