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
const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

# Sari-Saring Katha Brand Palette (matches OptionsOverlay / CustomerRequestHUD / UIStyle)
const COL_ESPRESSO := Color(0.082, 0.074, 0.066, 0.94)
const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)        # #D59F47 antique gold
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)         # UIStyle.COLOR_GOLD_TEXT
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.82)
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.9)
const COL_CHILL := Color(0.84, 0.37, 0.36, 1.0)          # Warm crimson-terracotta (fits brand!)
const COL_CHILL_SOFT := Color(0.95, 0.58, 0.54, 1.0)
const COL_SEALED := Color(1.0, 0.95, 0.82, 1.0)
const COL_STAT_POS := Color(0.56, 0.92, 0.52, 1.0)       # Luminous Hades-style green for buffs
const COL_STAT_NEG := Color(0.96, 0.48, 0.45, 1.0)       # Warm coral-red for penalties
const COL_BOLD_CREAM := "#FFF6E5"

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
var _center_frame: PanelContainer
var _frame_prompt_lbl: Label
var _mayari_portrait: TextureRect
var _header_title_lbl: Label
var _header_sub_lbl: Label
var _ledger_val_lbl: Label
var _track_bg: ColorRect
var _track_preview: ColorRect
var _track_base: ColorRect

# Beat 1: Offering Panel
var _offer_container: PanelContainer
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

	# Warm dark backdrop (lets the night store subtly breathe behind)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.035, 0.028, 0.024, 0.74)
	_backdrop.modulate.a = 0.0
	_root.add_child(_backdrop)

	# ── 1. TOP WIDE TITLE BANNER (Wider than the centered box below — Hades style!) ──
	_header_banner = PanelContainer.new()
	_header_banner.anchor_left = 0.14
	_header_banner.anchor_right = 0.86
	_header_banner.anchor_top = 0.035
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
	header_v.add_child(title_row)

	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(170, 0)
	title_row.add_child(left_pad)

	_header_title_lbl = Label.new()
	_header_title_lbl.text = "T H E   S I L V E R   L E D G E R"
	_header_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_header_title_lbl.add_theme_font_size_override("font_size", 34)
	_header_title_lbl.add_theme_color_override("font_color", COL_CREAM)
	_header_title_lbl.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
	_header_title_lbl.add_theme_constant_override("outline_size", 4)
	title_row.add_child(_header_title_lbl)

	_ledger_val_lbl = Label.new()
	_ledger_val_lbl.custom_minimum_size = Vector2(170, 0)
	_ledger_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ledger_val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ledger_val_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_ledger_val_lbl.add_theme_font_size_override("font_size", 22)
	_ledger_val_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	title_row.add_child(_ledger_val_lbl)

	_header_sub_lbl = Label.new()
	_header_sub_lbl.text = "Set tonight's tribute to Reyna Mayari."
	_header_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_header_sub_lbl.add_theme_font_size_override("font_size", 17)
	_header_sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	header_v.add_child(_header_sub_lbl)

	# Sleek integrated ledger progress hairline across the wide banner
	_track_bg = ColorRect.new()
	_track_bg.custom_minimum_size = Vector2(0, 5)
	_track_bg.color = Color(0.28, 0.22, 0.16, 0.65)
	header_v.add_child(_track_bg)

	_track_preview = ColorRect.new()
	_track_preview.anchor_top = 0.0
	_track_preview.anchor_bottom = 1.0
	_track_preview.anchor_left = 0.0
	_track_preview.anchor_right = 0.0
	_track_preview.color = Color(1.0, 0.86, 0.50, 0.55)
	_track_bg.add_child(_track_preview)

	_track_base = ColorRect.new()
	_track_base.anchor_top = 0.0
	_track_base.anchor_bottom = 1.0
	_track_base.anchor_left = 0.0
	_track_base.anchor_right = 0.0
	_track_base.color = COL_GOLD
	_track_bg.add_child(_track_base)

	# ── 2. DEAD-CENTER HADES FRAME (Narrower than top banner!) ───────────
	_center_frame = PanelContainer.new()
	_center_frame.anchor_left = 0.22
	_center_frame.anchor_right = 0.78
	_center_frame.anchor_top = 0.175
	_center_frame.anchor_bottom = 0.895
	var frame_style := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.046, 0.94), 8, 28, 20)
	frame_style.border_color = Color(0.835, 0.624, 0.278, 0.75)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	frame_style.shadow_size = 20
	_center_frame.add_theme_stylebox_override("panel", frame_style)
	_root.add_child(_center_frame)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 12)
	_center_frame.add_child(main_col)

	_frame_prompt_lbl = Label.new()
	_frame_prompt_lbl.text = "NIGHTLY OFFERING:"
	_frame_prompt_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_frame_prompt_lbl.add_theme_font_size_override("font_size", 22)
	_frame_prompt_lbl.add_theme_color_override("font_color", COL_CREAM)
	main_col.add_child(_frame_prompt_lbl)

	# Beat 1: Offering Panel inside the centered frame
	_build_offering_panel(main_col)

	# Beat 2: Hades-style 3 Horizontal Boon Rows inside the centered frame
	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.add_theme_constant_override("separation", 12)
	_cards_container.visible = false
	_cards_container.modulate.a = 0.0
	main_col.add_child(_cards_container)

	# ── 3. BOTTOM-LEFT REYNA MAYARI PORTRAIT (Cropped, overlapping left edge of center frame!) ──
	_mayari_portrait = TextureRect.new()
	if ResourceLoader.exists(MAYARI_SPRITE_PATH):
		_mayari_portrait.texture = load(MAYARI_SPRITE_PATH)
	_mayari_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mayari_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_mayari_portrait.anchor_left = -0.02
	_mayari_portrait.anchor_right = 0.29
	_mayari_portrait.anchor_top = 0.24
	_mayari_portrait.anchor_bottom = 1.24
	_mayari_portrait.z_index = 10
	_mayari_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mayari_portrait)

func _build_offering_panel(parent: VBoxContainer) -> void:
	_offer_container = PanelContainer.new()
	var style := UIStyle.create_flat_stylebox(COL_ESPRESSO, 12, 28, 26)
	style.border_color = Color(0.835, 0.624, 0.278, 0.55)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	_offer_container.add_theme_stylebox_override("panel", style)
	parent.add_child(_offer_container)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_offer_container.add_child(v)

	# Aura status word
	_aura_lbl = Label.new()
	_aura_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aura_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_aura_lbl.add_theme_font_size_override("font_size", 19)
	v.add_child(_aura_lbl)

	# Sculptural Peso Readout + Chevrons
	var num_row := HBoxContainer.new()
	num_row.alignment = BoxContainer.ALIGNMENT_CENTER
	num_row.add_theme_constant_override("separation", 28)
	v.add_child(num_row)

	_minus_btn = _make_chevron("‹")
	_minus_btn.pressed.connect(func(): _nudge_offer(-5.0))
	num_row.add_child(_minus_btn)

	_amount_lbl = Label.new()
	_amount_lbl.custom_minimum_size = Vector2(210, 0)
	_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_amount_lbl.add_theme_font_size_override("font_size", 68)
	_amount_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_amount_lbl.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
	_amount_lbl.add_theme_constant_override("outline_size", 4)
	num_row.add_child(_amount_lbl)

	_plus_btn = _make_chevron("›")
	_plus_btn.pressed.connect(func(): _nudge_offer(5.0))
	num_row.add_child(_plus_btn)

	# Warm gold slider track (matches OptionsOverlay slider colors!)
	var slider_wrap := Control.new()
	slider_wrap.custom_minimum_size = Vector2(480, 28)
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
	track_s.bg_color = Color(0.518, 0.396, 0.196, 0.55)
	track_s.set_corner_radius_all(3)
	track_s.content_margin_top = 3
	track_s.content_margin_bottom = 3
	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = COL_CREAM
	fill_s.set_corner_radius_all(3)
	_slider.add_theme_stylebox_override("slider", track_s)
	_slider.add_theme_stylebox_override("grabber_area", fill_s)
	_slider.add_theme_stylebox_override("grabber_area_highlight", fill_s)
	slider_wrap.add_child(_slider)

	_pip_min = ColorRect.new()
	_pip_min.size = Vector2(3, 14)
	_pip_min.color = COL_CREAM
	_pip_min.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_wrap.add_child(_pip_min)

	_pip_gen = ColorRect.new()
	_pip_gen.size = Vector2(3, 14)
	_pip_gen.color = COL_GOLD_BRIGHT
	_pip_gen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_wrap.add_child(_pip_gen)

	# Quiet quick-snap buttons
	_snap_row = HBoxContainer.new()
	_snap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_snap_row.add_theme_constant_override("separation", 20)
	v.add_child(_snap_row)

	var remaining := maxf(0.0, _goal - _total_paid)
	_add_snap("Hold (₱0)", 0.0, COL_CREAM_MUTED)
	if _min_amount > 0.0 and _min_amount < remaining - 0.01:
		_add_snap("Min ₱%d" % int(roundf(_min_amount)), _min_amount, COL_CREAM)
	if _generous_amount > _min_amount + 0.01 and _generous_amount < remaining - 0.01:
		_add_snap("Generous ₱%d" % int(roundf(_generous_amount)), _generous_amount, COL_GOLD_BRIGHT)
	var max_lbl := "Seal ₱%d" % int(roundf(remaining)) if _player_money >= remaining else "All ₱%d" % int(roundf(_max_offer))
	_add_snap(max_lbl, _max_offer, COL_SEALED)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)

	# Confirm CTA (matches OptionsOverlay warm bronze-gold button)
	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(280, 52)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_confirm_btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	_confirm_btn.add_theme_font_size_override("font_size", 22)
	_confirm_style = UIStyle.create_flat_stylebox(Color(0.518, 0.396, 0.196, 1.0), 8, 24, 10)
	_confirm_style.border_color = COL_CREAM
	_confirm_style.set_border_width_all(1)
	_apply_confirm_style(COL_GOLD)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	v.add_child(_confirm_btn)

func _make_chevron(glyph: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(44, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	btn.add_theme_font_size_override("font_size", 38)
	btn.add_theme_color_override("font_color", COL_CREAM_MUTED)
	btn.add_theme_color_override("font_hover_color", COL_CREAM)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	return btn

func _add_snap(label_text: String, amount: float, col: Color) -> void:
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
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", col * Color(1, 1, 1, 0.85))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.4, 0.35))
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

func _apply_confirm_style(accent: Color) -> void:
	var base_bg := Color(accent.r * 0.55, accent.g * 0.45, accent.b * 0.25, 0.95)
	_confirm_style.bg_color = base_bg
	_confirm_style.border_color = accent.lightened(0.22)
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

	_ledger_val_lbl.text = "₱%d / ₱%d" % [int(roundf(projected)), int(roundf(_goal))]
	_track_base.anchor_right = clampf(_total_paid / _goal, 0.0, 1.0)
	_track_preview.anchor_right = clampf(projected / _goal, 0.0, 1.0)
	_amount_lbl.text = "₱%d" % int(roundf(_current_offer))

	if _max_offer > 0.01:
		_pip_min.visible = _min_amount > 0.0 and _min_amount < _max_offer
		_pip_min.position = Vector2(clampf(_min_amount / _max_offer, 0.0, 1.0) * 480.0 - 1.5, 7.0)
		_pip_gen.visible = _generous_amount > _min_amount and _generous_amount < _max_offer
		_pip_gen.position = Vector2(clampf(_generous_amount / _max_offer, 0.0, 1.0) * 480.0 - 1.5, 7.0)
	else:
		_pip_min.visible = false
		_pip_gen.visible = false

	var accent := COL_GOLD
	match tier:
		"cleared":
			accent = COL_SEALED
			_aura_lbl.text = "SEAL THE PACT — GUARANTEED FAVOR"
			_confirm_btn.text = "SEAL LEDGER"
			_track_preview.color = Color(1.0, 0.94, 0.78, 0.80)
		"generous":
			accent = COL_GOLD_BRIGHT
			_aura_lbl.text = "GENEROUS — GUARANTEED FAVOR"
			_confirm_btn.text = "OFFER GENEROUSLY"
			_track_preview.color = Color(1.0, 0.85, 0.45, 0.68)
		"balanced":
			accent = COL_CREAM
			_aura_lbl.text = "BALANCED — MIXED FATE"
			_confirm_btn.text = "OFFER TRIBUTE"
			_track_preview.color = Color(0.88, 0.78, 0.62, 0.55)
		_:
			accent = COL_CHILL_SOFT
			_aura_lbl.text = "SHORTFALL — BIRINGAN'S CHILL"
			_confirm_btn.text = "OFFER NOTHING" if _current_offer <= 0.01 else "OFFER SHORTFALL"
			_track_preview.color = Color(0.84, 0.37, 0.36, 0.60)

	_aura_lbl.add_theme_color_override("font_color", accent)
	_amount_lbl.add_theme_color_override("font_color", accent)
	_apply_confirm_style(COL_CHILL if tier == "shortfall" else COL_GOLD)

	if animate_pop:
		_amount_lbl.pivot_offset = _amount_lbl.size * 0.5
		var pop := create_tween()
		pop.tween_property(_amount_lbl, "scale", Vector2(1.07, 1.07), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(_amount_lbl, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE)
		if tier != _last_tier:
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

	var tw := create_tween()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_header_banner, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_header_banner, "offset_top", 0.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_header_banner, "offset_bottom", 0.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_center_frame, "modulate:a", 1.0, 0.32).set_delay(0.06).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_mayari_portrait, "modulate:a", 1.0, 0.34).set_delay(0.08).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_mayari_portrait, "offset_left", 0.0, 0.42).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_mayari_portrait, "offset_right", 0.0, 0.42).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── Resolution & Transition to Hades Boon Stack ──────────────────────────────

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

	var new_total := minf(_goal, _total_paid + _confirmed_offer)
	var target_ratio := clampf(new_total / _goal, 0.0, 1.0)
	var fill_tw := create_tween()
	fill_tw.tween_property(_track_base, "anchor_right", target_ratio, 0.50).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fill_tw.parallel().tween_property(_offer_container, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	await fill_tw.finished
	if not is_inside_tree():
		return

	_offer_container.visible = false
	await get_tree().create_timer(0.18).timeout
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

	_cards_container.visible = true
	_cards_container.modulate.a = 1.0

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
