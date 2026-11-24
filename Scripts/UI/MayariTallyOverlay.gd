class_name MayariTallyOverlay
extends CanvasLayer

## Atmospheric, minimalist two-beat ritual for Reyna Mayari's Nightly Tally.
## Designed with progressive disclosure and zero modal-box clutter:
## - Beat 1 (Offering): Floating silver ledger hairline at top + sculptural peso
##   selector over the wooden counter (scroll wheel, drag track, or arrows).
##   Reyna Mayari and the night storefront remain visible behind a soft vignette.
## - Beat 2 (Resolution): Controls dissolve; the ledger line fills with liquid
##   moonlight and pulses.
## - Beat 3 (Moon-Card Draft): 3 suspended tarot-style Moon Cards fan in with
##   gentle floating physics, double-bezel filigree frames, glanceable hooks,
##   and tactile hover/selection choreography.

signal completed(offer_amount: float, tier: String, selected_card_id: String)

const COL_SILVER := Color(0.84, 0.90, 0.98, 1.0)
const COL_SILVER_MUTED := Color(0.62, 0.69, 0.80, 0.82)
const COL_GOLD := Color(0.98, 0.84, 0.48, 1.0)
const COL_CHILL := Color(0.92, 0.56, 0.64, 1.0)
const COL_SEALED := Color(0.96, 0.98, 1.0, 1.0)
const COL_INK := Color(0.055, 0.062, 0.105, 0.94)

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

# Vignette & Root
var _root: Control
var _vignette: TextureRect

# Top Floating Silver Ledger Hairline
var _ledger_anchor: Control
var _ledger_title_lbl: Label
var _ledger_value_lbl: Label
var _track_bg: ColorRect
var _track_preview: ColorRect
var _track_base: ColorRect

# Bottom Floating Offering Ritual (no modal box!)
var _offer_anchor: Control
var _aura_lbl: Label
var _amount_lbl: Label
var _slider: HSlider
var _pip_min: ColorRect
var _pip_gen: ColorRect
var _snap_row: HBoxContainer
var _snap_buttons: Array[Button] = []
var _confirm_btn: Button
var _confirm_style: StyleBoxFlat
var _minus_btn: Button
var _plus_btn: Button

# Beat 3: Suspended Tarot Moon-Card Draft
var _draft_root: Control
var _draft_whisper_lbl: Label
var _draft_sub_lbl: Label
var _cards_holder: Control
var _card_nodes: Array[Control] = []
var _card_base_pos: Array[Vector2] = []
var _card_base_rot: Array[float] = []
var _card_data_list: Array[Dictionary] = []
var _hovered_card_idx: int = -1
var _card_picked: bool = false
var _float_time: float = 0.0
var _cards_dealt: bool = false

var _confirmed_offer: float = 0.0
var _confirmed_tier: String = "balanced"

static var _vignette_tex: ImageTexture = null

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
	_build_ui()
	_refresh_offering_ui(false)
	_play_entrance()

func _process(delta: float) -> void:
	if _phase == 2 and _cards_dealt and not _card_picked:
		_float_time += delta
		for i in range(_card_nodes.size()):
			if i == _hovered_card_idx:
				continue
			var card := _card_nodes[i]
			if is_instance_valid(card):
				var bob := sin(_float_time * 1.9 + float(i) * 1.35) * 4.5
				card.position.y = lerpf(card.position.y, _card_base_pos[i].y + bob, clampf(delta * 6.0, 0.0, 1.0))

func _input(event: InputEvent) -> void:
	if _phase != 0 or _is_locked:
		return
	# Tactile mouse-wheel adjustment directly on the offering ritual
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge_offer(5.0)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge_offer(-5.0)
			get_viewport().set_input_as_handled()

# ── Soft Edge Vignette Texture (leaves center/Mayari open!) ──────────────────

static func _get_vignette_texture() -> ImageTexture:
	if _vignette_tex != null:
		return _vignette_tex
	const W := 128
	const H := 72
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var ny := (float(y) / float(H - 1)) * 2.0 - 1.0 # -1 top, +1 bottom
		for x in W:
			var nx := (float(x) / float(W - 1)) * 2.0 - 1.0
			var radial := clampf(Vector2(nx * 0.85, ny).length(), 0.0, 1.35)
			# Darker along bottom & top edges for legible floating typography, light in center
			var edge_fade := smoothstep(0.35, 1.25, radial) * 0.68
			var bottom_band := smoothstep(0.15, 0.95, ny) * 0.42
			var top_band := smoothstep(0.30, 1.0, -ny) * 0.28
			var alpha := clampf(edge_fade + bottom_band + top_band, 0.14, 0.84)
			img.set_pixel(x, y, Color(0.02, 0.025, 0.06, alpha))
	_vignette_tex = ImageTexture.create_from_image(img)
	return _vignette_tex

# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_vignette = TextureRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.texture = _get_vignette_texture()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)

	_build_top_ledger()
	_build_bottom_offering()
	_build_card_draft_layer()

func _build_top_ledger() -> void:
	_ledger_anchor = Control.new()
	_ledger_anchor.anchor_left = 0.5
	_ledger_anchor.anchor_right = 0.5
	_ledger_anchor.anchor_top = 0.0
	_ledger_anchor.anchor_bottom = 0.0
	_ledger_anchor.offset_left = -220.0
	_ledger_anchor.offset_right = 220.0
	_ledger_anchor.offset_top = 34.0
	_ledger_anchor.offset_bottom = 96.0
	_ledger_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ledger_anchor)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ledger_anchor.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top_row)

	_ledger_title_lbl = Label.new()
	_ledger_title_lbl.text = "☽  SILVER LEDGER"
	_ledger_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ledger_title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_ledger_title_lbl.add_theme_font_size_override("font_size", 13)
	_ledger_title_lbl.add_theme_color_override("font_color", COL_SILVER_MUTED)
	_ledger_title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_ledger_title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	top_row.add_child(_ledger_title_lbl)

	_ledger_value_lbl = Label.new()
	_ledger_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ledger_value_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_ledger_value_lbl.add_theme_font_size_override("font_size", 14)
	_ledger_value_lbl.add_theme_color_override("font_color", COL_SILVER)
	_ledger_value_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_ledger_value_lbl.add_theme_constant_override("shadow_offset_y", 1)
	top_row.add_child(_ledger_value_lbl)

	# Razor-thin moonlight hairline progress track (no chunky box)
	_track_bg = ColorRect.new()
	_track_bg.custom_minimum_size = Vector2(0, 4)
	_track_bg.color = Color(0.76, 0.84, 0.96, 0.18)
	_track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_track_bg)

	_track_preview = ColorRect.new()
	_track_preview.anchor_top = 0.0
	_track_preview.anchor_bottom = 1.0
	_track_preview.anchor_left = 0.0
	_track_preview.anchor_right = 0.0
	_track_preview.color = Color(0.98, 0.84, 0.48, 0.55)
	_track_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_bg.add_child(_track_preview)

	_track_base = ColorRect.new()
	_track_base.anchor_top = 0.0
	_track_base.anchor_bottom = 1.0
	_track_base.anchor_left = 0.0
	_track_base.anchor_right = 0.0
	_track_base.color = COL_SILVER
	_track_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_bg.add_child(_track_base)

func _build_bottom_offering() -> void:
	# Floating cleanly over the wooden counter — NO enclosing modal card!
	_offer_anchor = Control.new()
	_offer_anchor.anchor_left = 0.5
	_offer_anchor.anchor_right = 0.5
	_offer_anchor.anchor_top = 1.0
	_offer_anchor.anchor_bottom = 1.0
	_offer_anchor.offset_left = -260.0
	_offer_anchor.offset_right = 260.0
	_offer_anchor.offset_top = -255.0
	_offer_anchor.offset_bottom = -34.0
	_root.add_child(_offer_anchor)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 10)
	_offer_anchor.add_child(v)

	# Single evocative aura word (2 words max — glanceable!)
	_aura_lbl = Label.new()
	_aura_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aura_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_aura_lbl.add_theme_font_size_override("font_size", 14)
	_aura_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_aura_lbl.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(_aura_lbl)

	# Sculptural Peso Readout with minimal chevron steppers
	var num_row := HBoxContainer.new()
	num_row.alignment = BoxContainer.ALIGNMENT_CENTER
	num_row.add_theme_constant_override("separation", 24)
	v.add_child(num_row)

	_minus_btn = _make_ghost_chevron("‹")
	_minus_btn.pressed.connect(func(): _nudge_offer(-5.0))
	num_row.add_child(_minus_btn)

	_amount_lbl = Label.new()
	_amount_lbl.custom_minimum_size = Vector2(180, 0)
	_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_amount_lbl.add_theme_font_size_override("font_size", 54)
	_amount_lbl.add_theme_color_override("font_color", COL_GOLD)
	_amount_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_amount_lbl.add_theme_constant_override("shadow_offset_y", 3)
	num_row.add_child(_amount_lbl)

	_plus_btn = _make_ghost_chevron("›")
	_plus_btn.pressed.connect(func(): _nudge_offer(5.0))
	num_row.add_child(_plus_btn)

	# Minimalist Slider Track with tiny threshold pips
	var slider_wrap := Control.new()
	slider_wrap.custom_minimum_size = Vector2(440, 28)
	slider_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(slider_wrap)

	_slider = HSlider.new()
	_slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slider.min_value = 0.0
	_slider.max_value = maxf(0.0, _max_offer)
	_slider.step = 1.0
	_slider.value = _current_offer
	_slider.value_changed.connect(_on_slider_changed)
	var track_s := StyleBoxFlat.new()
	track_s.bg_color = Color(0.78, 0.85, 0.96, 0.24)
	track_s.set_corner_radius_all(2)
	track_s.content_margin_top = 2
	track_s.content_margin_bottom = 2
	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = COL_GOLD
	fill_s.set_corner_radius_all(2)
	_slider.add_theme_stylebox_override("slider", track_s)
	_slider.add_theme_stylebox_override("grabber_area", fill_s)
	_slider.add_theme_stylebox_override("grabber_area_highlight", fill_s)
	slider_wrap.add_child(_slider)

	# Threshold pips on the track
	_pip_min = ColorRect.new()
	_pip_min.size = Vector2(3, 12)
	_pip_min.color = COL_SILVER
	_pip_min.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_wrap.add_child(_pip_min)

	_pip_gen = ColorRect.new()
	_pip_gen.size = Vector2(3, 12)
	_pip_gen.color = COL_GOLD
	_pip_gen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_wrap.add_child(_pip_gen)

	# Quiet text-only quick snaps (no heavy colored pills)
	_snap_row = HBoxContainer.new()
	_snap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_snap_row.add_theme_constant_override("separation", 18)
	v.add_child(_snap_row)

	var remaining := maxf(0.0, _goal - _total_paid)
	_add_quiet_snap("Hold (₱0)", 0.0, COL_SILVER_MUTED)
	if _min_amount > 0.0 and _min_amount < remaining - 0.01:
		_add_quiet_snap("Min ₱%d" % int(roundf(_min_amount)), _min_amount, COL_SILVER)
	if _generous_amount > _min_amount + 0.01 and _generous_amount < remaining - 0.01:
		_add_quiet_snap("Generous ₱%d" % int(roundf(_generous_amount)), _generous_amount, COL_GOLD)
	var max_lbl := "Seal ₱%d" % int(roundf(remaining)) if _player_money >= remaining else "All ₱%d" % int(roundf(_max_offer))
	_add_quiet_snap(max_lbl, _max_offer, COL_SEALED)

	# Single sleek pill CTA
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	v.add_child(spacer)

	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(210, 44)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_confirm_btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	_confirm_btn.add_theme_font_size_override("font_size", 16)
	_confirm_style = UIStyle.create_flat_stylebox(Color(0.09, 0.11, 0.18, 0.92), 22, 26, 8)
	_confirm_style.border_color = COL_SILVER
	_confirm_style.border_width_left = 1
	_confirm_style.border_width_top = 1
	_confirm_style.border_width_right = 1
	_confirm_style.border_width_bottom = 1
	_apply_confirm_button_style(COL_SILVER)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	v.add_child(_confirm_btn)

func _make_ghost_chevron(glyph: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(40, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", COL_SILVER_MUTED)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	return btn

func _add_quiet_snap(label_text: String, amount: float, col: Color) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.disabled = amount > _max_offer + 0.01
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", col * Color(1, 1, 1, 0.78))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55, 0.35))
	btn.pressed.connect(func():
		if _is_locked:
			return
		EventBus.request_sfx.emit("interact")
		_current_offer = clampf(amount, 0.0, _max_offer)
		_slider.set_value_no_signal(_current_offer)
		_refresh_offering_ui(true)
	)
	_snap_row.add_child(btn)
	_snap_buttons.append(btn)

func _apply_confirm_button_style(accent: Color) -> void:
	_confirm_style.border_color = accent
	var hov: StyleBoxFlat = _confirm_style.duplicate()
	hov.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.26, 0.96)
	hov.border_color = accent.lightened(0.25)
	var prs: StyleBoxFlat = _confirm_style.duplicate()
	prs.bg_color = Color(accent.r * 0.32, accent.g * 0.32, accent.b * 0.36, 0.98)
	_confirm_btn.add_theme_stylebox_override("normal", _confirm_style)
	_confirm_btn.add_theme_stylebox_override("hover", hov)
	_confirm_btn.add_theme_stylebox_override("pressed", prs)
	_confirm_btn.add_theme_color_override("font_color", accent.lightened(0.15))
	_confirm_btn.add_theme_color_override("font_hover_color", Color.WHITE)

func _build_card_draft_layer() -> void:
	_draft_root = Control.new()
	_draft_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_root.visible = false
	_draft_root.modulate.a = 0.0
	_root.add_child(_draft_root)

	var header := VBoxContainer.new()
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.anchor_top = 0.14
	header.anchor_bottom = 0.24
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_root.add_child(header)

	_draft_whisper_lbl = Label.new()
	_draft_whisper_lbl.text = "CHOOSE TOMORROW'S FATE"
	_draft_whisper_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draft_whisper_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_draft_whisper_lbl.add_theme_font_size_override("font_size", 24)
	_draft_whisper_lbl.add_theme_color_override("font_color", COL_SILVER)
	_draft_whisper_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_draft_whisper_lbl.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(_draft_whisper_lbl)

	_draft_sub_lbl = Label.new()
	_draft_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draft_sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_draft_sub_lbl.add_theme_font_size_override("font_size", 13)
	_draft_sub_lbl.add_theme_color_override("font_color", COL_SILVER_MUTED)
	header.add_child(_draft_sub_lbl)

	_cards_holder = Control.new()
	_cards_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_draft_root.add_child(_cards_holder)

# ── Offering Interaction & Refresh ───────────────────────────────────────────

func _nudge_offer(delta: float) -> void:
	if _is_locked:
		return
	var next_val := clampf(roundf((_current_offer + delta) / 5.0) * 5.0, 0.0, _max_offer)
	if delta > 0.0 and _max_offer - _current_offer < 5.0:
		next_val = _max_offer
	if not is_equal_approx(next_val, _current_offer):
		EventBus.request_sfx.emit("interact")
		_current_offer = next_val
		_slider.set_value_no_signal(_current_offer)
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
	var projected := minf(_goal, _total_paid + _current_offer)

	_ledger_value_lbl.text = "₱%d / ₱%d" % [int(roundf(projected)), int(roundf(_goal))]
	_track_base.anchor_right = clampf(_total_paid / _goal, 0.0, 1.0)
	_track_preview.anchor_right = clampf(projected / _goal, 0.0, 1.0)

	_amount_lbl.text = "₱%d" % int(roundf(_current_offer))

	# Position threshold pips accurately along the 440px slider track
	if _max_offer > 0.01:
		_pip_min.visible = _min_amount > 0.0 and _min_amount < _max_offer
		_pip_min.position = Vector2(clampf(_min_amount / _max_offer, 0.0, 1.0) * 440.0 - 1.5, 8.0)
		_pip_gen.visible = _generous_amount > _min_amount and _generous_amount < _max_offer
		_pip_gen.position = Vector2(clampf(_generous_amount / _max_offer, 0.0, 1.0) * 440.0 - 1.5, 8.0)
	else:
		_pip_min.visible = false
		_pip_gen.visible = false

	var accent := COL_SILVER
	match tier:
		"cleared":
			accent = COL_SEALED
			_aura_lbl.text = "✦  SEAL THE PACT  ✦"
			_confirm_btn.text = "SEAL LEDGER"
			_track_preview.color = Color(0.96, 0.98, 1.0, 0.85)
		"generous":
			accent = COL_GOLD
			_aura_lbl.text = "✦  BIRINGAN'S FAVOR  ✦"
			_confirm_btn.text = "OFFER GENEROUSLY"
			_track_preview.color = Color(0.98, 0.84, 0.48, 0.72)
		"balanced":
			accent = COL_SILVER
			_aura_lbl.text = "☽  BALANCED  ☾"
			_confirm_btn.text = "OFFER TRIBUTE"
			_track_preview.color = Color(0.76, 0.86, 0.98, 0.55)
		_:
			accent = COL_CHILL
			_aura_lbl.text = "◐  SHORTFALL  ◐"
			_confirm_btn.text = "OFFER NOTHING" if _current_offer <= 0.01 else "OFFER SHORTFALL"
			_track_preview.color = Color(0.92, 0.56, 0.64, 0.55)

	_aura_lbl.add_theme_color_override("font_color", accent)
	_amount_lbl.add_theme_color_override("font_color", accent)
	_apply_confirm_button_style(accent)

	if animate_pop:
		_amount_lbl.pivot_offset = _amount_lbl.size * 0.5
		var num_pop := create_tween()
		num_pop.tween_property(_amount_lbl, "scale", Vector2(1.08, 1.08), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		num_pop.tween_property(_amount_lbl, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)

		if tier != _last_tier:
			_last_tier = tier
			EventBus.request_sfx.emit("interact")
			_aura_lbl.pivot_offset = _aura_lbl.size * 0.5
			var aura_pop := create_tween()
			aura_pop.tween_property(_aura_lbl, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			aura_pop.tween_property(_aura_lbl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
	elif _last_tier == "":
		_last_tier = tier

func _play_entrance() -> void:
	_ledger_anchor.modulate.a = 0.0
	_offer_anchor.modulate.a = 0.0
	_offer_anchor.offset_top = -225.0
	_offer_anchor.offset_bottom = -4.0

	var tw := create_tween()
	tw.tween_property(_vignette, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_ledger_anchor, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_offer_anchor, "modulate:a", 1.0, 0.32).set_delay(0.08).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_offer_anchor, "offset_top", -255.0, 0.42).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_offer_anchor, "offset_bottom", -34.0, 0.42).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── Beat 2: Resolution & Transition to Draft ─────────────────────────────────

func _on_confirm_pressed() -> void:
	if _is_locked:
		return
	_is_locked = true
	_phase = 1
	_slider.editable = false
	_confirm_btn.disabled = true
	_minus_btn.disabled = true
	_plus_btn.disabled = true
	for b in _snap_buttons:
		b.disabled = true

	_confirmed_offer = _current_offer
	_confirmed_tier = _evaluate_tier(_confirmed_offer)
	EventBus.request_sfx.emit("money_decrease" if _confirmed_offer > 0.0 else "interact")

	# 1. Dissolve bottom offering ritual cleanly downward
	var out_tw := create_tween()
	out_tw.tween_property(_offer_anchor, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	out_tw.parallel().tween_property(_offer_anchor, "offset_top", -220.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out_tw.parallel().tween_property(_offer_anchor, "offset_bottom", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 2. Fill the floating silver ledger hairline with liquid moonlight
	var new_total := minf(_goal, _total_paid + _confirmed_offer)
	var target_ratio := clampf(new_total / _goal, 0.0, 1.0)
	var fill_tw := create_tween()
	fill_tw.tween_property(_track_base, "anchor_right", target_ratio, 0.60).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _confirmed_tier == "generous" or _confirmed_tier == "cleared":
		fill_tw.parallel().tween_property(_track_base, "color", COL_GOLD if _confirmed_tier == "generous" else COL_SEALED, 0.25)
		fill_tw.tween_property(_track_base, "color", COL_SILVER, 0.35)
	await fill_tw.finished
	if not is_inside_tree():
		return

	_offer_anchor.visible = false
	await get_tree().create_timer(0.32).timeout
	if not is_inside_tree():
		return

	_launch_card_draft()

# ── Beat 3: Tactile Tarot Moon-Card Draft ────────────────────────────────────

func _launch_card_draft() -> void:
	_phase = 2
	_card_data_list = MayariCardRegistry.draw_three_cards(_confirmed_tier)
	_card_nodes.clear()
	_card_base_pos.clear()
	_card_base_rot.clear()
	_card_picked = false
	_hovered_card_idx = -1
	_cards_dealt = false
	_float_time = 0.0

	match _confirmed_tier:
		"cleared":
			_draft_whisper_lbl.text = "THE PACT IS SEALED"
			_draft_whisper_lbl.add_theme_color_override("font_color", COL_GOLD)
			_draft_sub_lbl.text = "Three lunar blessings. Claim your reward for tomorrow."
		"generous":
			_draft_whisper_lbl.text = "FAVOR OF BIRINGAN"
			_draft_whisper_lbl.add_theme_color_override("font_color", COL_GOLD)
			_draft_sub_lbl.text = "Three lunar blessings. Claim one for tomorrow."
		"shortfall":
			_draft_whisper_lbl.text = "CHILL OF BIRINGAN"
			_draft_whisper_lbl.add_theme_color_override("font_color", COL_CHILL)
			_draft_sub_lbl.text = "Three omens of displeasure. Endure one tomorrow."
		_:
			_draft_whisper_lbl.text = "CHOOSE TOMORROW'S FATE"
			_draft_whisper_lbl.add_theme_color_override("font_color", COL_SILVER)
			_draft_sub_lbl.text = "The moon deals a mixed hand. Pick one."

	_draft_root.visible = true
	var vp_size := get_viewport().get_visible_rect().size
	var card_size := Vector2(236, 336)
	var spacing := 272.0
	var center_x := vp_size.x * 0.5
	var center_y := vp_size.y * 0.57
	var fan_angles := [-5.0, 0.0, 5.0]
	var fan_y_offsets := [16.0, 0.0, 16.0]

	for i in range(_card_data_list.size()):
		var card := _create_tarot_card(_card_data_list[i], i, card_size)
		_cards_holder.add_child(card)
		var target_pos := Vector2(
			center_x + (i - 1) * spacing - card_size.x * 0.5,
			center_y - card_size.y * 0.5 + fan_y_offsets[i]
		)
		var target_rot: float = fan_angles[i]
		_card_nodes.append(card)
		_card_base_pos.append(target_pos)
		_card_base_rot.append(target_rot)

		card.position = target_pos + Vector2(0, 210)
		card.rotation_degrees = target_rot * 2.4
		card.scale = Vector2(0.76, 0.76)
		card.modulate.a = 0.0
		card.pivot_offset = card_size * 0.5

	var fade_in := create_tween()
	fade_in.tween_property(_draft_root, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)

	var last_deal: Tween = null
	for i in range(_card_nodes.size()):
		var card := _card_nodes[i]
		var t_pos := _card_base_pos[i]
		var t_rot := _card_base_rot[i]
		var delay := 0.06 + i * 0.11
		var deal_tw := create_tween()
		deal_tw.tween_interval(delay)
		deal_tw.tween_callback(func(): EventBus.request_sfx.emit("interact"))
		deal_tw.tween_property(card, "position", t_pos, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal_tw.parallel().tween_property(card, "rotation_degrees", t_rot, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		deal_tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal_tw.parallel().tween_property(card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		last_deal = deal_tw

	if last_deal:
		await last_deal.finished
	_cards_dealt = true

func _create_tarot_card(c_data: Dictionary, index: int, card_size: Vector2) -> Control:
	var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
	var accent := COL_GOLD if is_fav else COL_CHILL
	var outer_bg := Color(0.06, 0.075, 0.135, 0.96) if is_fav else Color(0.095, 0.065, 0.105, 0.96)
	var inner_bg := Color(0.085, 0.105, 0.18, 0.94) if is_fav else Color(0.125, 0.08, 0.13, 0.94)

	# Double-bezel physical tarot card: outer obsidian shell + inset hairline filigree frame
	var shell := PanelContainer.new()
	shell.custom_minimum_size = card_size
	shell.size = card_size
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var outer_style := UIStyle.create_flat_stylebox(outer_bg, 14, 7, 7)
	outer_style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	outer_style.border_width_left = 1
	outer_style.border_width_top = 1
	outer_style.border_width_right = 1
	outer_style.border_width_bottom = 1
	outer_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	outer_style.shadow_size = 20
	outer_style.shadow_offset = Vector2(0, 10)
	shell.add_theme_stylebox_override("panel", outer_style)

	var inner := PanelContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := UIStyle.create_flat_stylebox(inner_bg, 9, 16, 18)
	inner_style.border_color = Color(accent.r, accent.g, accent.b, 0.68)
	inner_style.border_width_left = 1
	inner_style.border_width_top = 1
	inner_style.border_width_right = 1
	inner_style.border_width_bottom = 1
	inner.add_theme_stylebox_override("panel", inner_style)
	shell.add_child(inner)

	shell.set_meta("outer_style", outer_style)
	shell.set_meta("inner_style", inner_style)
	shell.set_meta("accent", accent)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(v)

	# Tiny eyebrow kind tag
	var kind_lbl := Label.new()
	kind_lbl.text = "FAVOR" if is_fav else "CHILL"
	kind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	kind_lbl.add_theme_font_size_override("font_size", 11)
	kind_lbl.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.85))
	kind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(kind_lbl)

	# Minimalist luminous sigil (no bulky circle box)
	var sigil_lbl := Label.new()
	sigil_lbl.text = str(c_data.get("sigil", "☽"))
	sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_lbl.add_theme_font_size_override("font_size", 46)
	sigil_lbl.add_theme_color_override("font_color", accent)
	sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sigil_lbl)

	# Bold Card Title
	var title_lbl := Label.new()
	title_lbl.text = str(c_data.get("title", "Moon Card"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title_lbl)

	# Crisp hairline divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(44, 1)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	div.color = Color(accent.r, accent.g, accent.b, 0.45)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(div)

	# Glanceable mechanical hook (200ms readability!)
	var hook_lbl := Label.new()
	hook_lbl.text = str(c_data.get("tagline", ""))
	hook_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hook_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	hook_lbl.add_theme_font_size_override("font_size", 14)
	hook_lbl.add_theme_color_override("font_color", accent)
	hook_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hook_lbl)

	# Subtle concise detail (only visible at high contrast when hovered)
	var desc_lbl := Label.new()
	desc_lbl.text = str(c_data.get("description", ""))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 0.72))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc_lbl)
	shell.set_meta("desc_lbl", desc_lbl)

	shell.mouse_entered.connect(_on_card_hovered.bind(index, true))
	shell.mouse_exited.connect(_on_card_hovered.bind(index, false))
	shell.gui_input.connect(_on_card_gui_input.bind(index))
	return shell

func _on_card_hovered(index: int, is_hovered: bool) -> void:
	if _card_picked or not _cards_dealt or index < 0 or index >= _card_nodes.size():
		return
	if is_hovered:
		_hovered_card_idx = index
		EventBus.request_sfx.emit("interact")
	elif _hovered_card_idx == index:
		_hovered_card_idx = -1

	for i in range(_card_nodes.size()):
		var card := _card_nodes[i]
		if not is_instance_valid(card):
			continue
		var outer_s: StyleBoxFlat = card.get_meta("outer_style")
		var inner_s: StyleBoxFlat = card.get_meta("inner_style")
		var accent: Color = card.get_meta("accent")
		var desc_lbl: Label = card.get_meta("desc_lbl")
		var tw := create_tween()

		if _hovered_card_idx == i:
			card.z_index = 12
			outer_s.border_color = accent
			inner_s.border_color = accent.lightened(0.28)
			desc_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.96))
			tw.tween_property(card, "position", _card_base_pos[i] + Vector2(0, -28), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "rotation_degrees", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "scale", Vector2(1.09, 1.09), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "modulate", Color.WHITE, 0.14)
		else:
			card.z_index = 0
			outer_s.border_color = Color(accent.r, accent.g, accent.b, 0.42)
			inner_s.border_color = Color(accent.r, accent.g, accent.b, 0.68)
			desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 0.65))
			var dim := Color(0.72, 0.75, 0.84, 0.88) if _hovered_card_idx != -1 else Color.WHITE
			tw.tween_property(card, "position", _card_base_pos[i], 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "rotation_degrees", _card_base_rot[i], 0.20).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(card, "modulate", dim, 0.16)

func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if _card_picked or not _cards_dealt:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_card(index)

func _select_card(index: int) -> void:
	if _card_picked or index < 0 or index >= _card_data_list.size():
		return
	_card_picked = true
	var chosen_data: Dictionary = _card_data_list[index]
	var chosen_id := str(chosen_data.get("id", ""))
	var is_fav := str(chosen_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR

	EventBus.request_sfx.emit("purchase" if is_fav else "interact")

	_draft_whisper_lbl.text = str(chosen_data.get("title", "")).to_upper()
	_draft_sub_lbl.text = "Active tomorrow · " + str(chosen_data.get("tagline", ""))

	var vp_center_x := get_viewport().get_visible_rect().size.x * 0.5
	for i in range(_card_nodes.size()):
		var card := _card_nodes[i]
		if not is_instance_valid(card):
			continue
		var tw := create_tween()
		if i == index:
			card.z_index = 20
			var outer_s: StyleBoxFlat = card.get_meta("outer_style")
			var inner_s: StyleBoxFlat = card.get_meta("inner_style")
			outer_s.border_color = Color.WHITE
			inner_s.border_color = Color.WHITE
			var target_center := Vector2(vp_center_x - card.size.x * 0.5, _card_base_pos[i].y - 30.0)
			tw.tween_property(card, "position", target_center, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "rotation_degrees", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC)
			tw.parallel().tween_property(card, "scale", Vector2(1.14, 1.14), 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "modulate", Color.WHITE, 0.18)
		else:
			tw.tween_property(card, "position", _card_base_pos[i] + Vector2(0, 110), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(card, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(0.80).timeout
	if not is_inside_tree():
		return
	await _fade_out_and_finish(chosen_id)

func _fade_out_and_finish(selected_card_id: String) -> void:
	var fade := create_tween()
	fade.tween_property(_vignette, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE)
	fade.parallel().tween_property(_ledger_anchor, "modulate:a", 0.0, 0.22)
	if _draft_root.visible:
		fade.parallel().tween_property(_draft_root, "modulate:a", 0.0, 0.22)
	await fade.finished
	completed.emit(_confirmed_offer, _confirmed_tier, selected_card_id)
	queue_free()
