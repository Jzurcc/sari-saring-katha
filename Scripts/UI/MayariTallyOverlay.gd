class_name MayariTallyOverlay
extends CanvasLayer

## Two-phase interactive overlay for Reyna Mayari's Nightly Tally:
## Phase 1 — "The Silver Ledger of Biringan": player chooses tonight's contribution
##           toward the ₱750 goal with live threshold markers, presets, and rolling fill.
## Phase 2 — "Moon-Card Draft": Slay-the-Spire style 3-card fan draft where the player
##           picks 1 of 3 Favor/Chill cards that takes effect tomorrow.

signal completed(offer_amount: float, tier: String, selected_card_id: String)

const COLOR_BACKDROP := Color(0.025, 0.032, 0.075, 0.86)
const COLOR_PANEL_BG := Color(0.068, 0.082, 0.145, 0.97)
const COLOR_PANEL_INNER := Color(0.095, 0.115, 0.195, 0.96)
const COLOR_SILVER := Color(0.76, 0.85, 0.96, 1.0)
const COLOR_SILVER_DIM := Color(0.55, 0.63, 0.76, 0.85)
const COLOR_GOLD := Color(0.98, 0.83, 0.42, 1.0)
const COLOR_GOLD_SOFT := Color(0.98, 0.83, 0.42, 0.22)
const COLOR_CHILL := Color(0.62, 0.72, 0.98, 1.0)
const COLOR_CHILL_BORDER := Color(0.75, 0.40, 0.48, 0.95)
const COLOR_CHILL_BG := Color(0.11, 0.09, 0.16, 0.97)
const COLOR_FAVOR_BG := Color(0.08, 0.11, 0.20, 0.97)
const COLOR_SEALED := Color(0.92, 0.96, 1.0, 1.0)

var _player_money: float = 0.0
var _total_paid: float = 0.0
var _goal: float = 750.0
var _min_amount: float = 40.0
var _generous_amount: float = 65.0
var _max_offer: float = 0.0
var _current_offer: float = 0.0
var _last_tier: String = ""
var _is_locked: bool = false

# Phase 1 nodes
var _backdrop: ColorRect
var _ledger_center: CenterContainer
var _ledger_panel: PanelContainer
var _ledger_style: StyleBoxFlat
var _progress_text: Label
var _remaining_text: Label
var _bar_bg: Panel
var _bar_base_fill: ColorRect
var _bar_preview_fill: ColorRect
var _offer_amount_lbl: Label
var _wallet_preview_lbl: Label
var _slider: HSlider
var _forecast_panel: PanelContainer
var _forecast_style: StyleBoxFlat
var _forecast_badge_lbl: Label
var _forecast_desc_lbl: Label
var _confirm_btn: Button
var _preset_buttons: Array[Button] = []
var _minus_btn: Button
var _plus_btn: Button

# Phase 2 nodes (Moon-Card Draft)
var _draft_root: Control
var _draft_title_lbl: Label
var _draft_sub_lbl: Label
var _cards_holder: Control
var _card_nodes: Array[PanelContainer] = []
var _card_base_pos: Array[Vector2] = []
var _card_base_rot: Array[float] = []
var _card_data_list: Array[Dictionary] = []
var _card_picked: bool = false

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
	# Default slider to Min if affordable, else max affordable (rounded to nearest 5 or exact remaining)
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
	_refresh_ledger_ui(false)
	_play_ledger_entrance()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = COLOR_BACKDROP
	_backdrop.modulate.a = 0.0
	root.add_child(_backdrop)

	# ── PHASE 1: SILVER LEDGER PANEL ─────────────────────────────────────
	_ledger_center = CenterContainer.new()
	_ledger_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_ledger_center)

	_ledger_panel = PanelContainer.new()
	_ledger_panel.custom_minimum_size = Vector2(680, 0)
	_ledger_style = UIStyle.create_flat_stylebox(COLOR_PANEL_BG, 14, 28, 24)
	_ledger_style.border_color = COLOR_SILVER
	_ledger_style.border_width_left = 2
	_ledger_style.border_width_top = 2
	_ledger_style.border_width_right = 2
	_ledger_style.border_width_bottom = 2
	_ledger_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_ledger_style.shadow_size = 18
	_ledger_panel.add_theme_stylebox_override("panel", _ledger_style)
	_ledger_center.add_child(_ledger_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_ledger_panel.add_child(vbox)

	# Header
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	vbox.add_child(header_box)

	var title_lbl := Label.new()
	title_lbl.text = "☽  THE SILVER LEDGER OF BIRINGAN  ☾"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", COLOR_SILVER)
	header_box.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Decide tonight's offering toward Lola's pact. Your generosity shapes tomorrow's Moon Cards."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", COLOR_SILVER_DIM)
	header_box.add_child(sub_lbl)

	# Progress Section
	var prog_header := HBoxContainer.new()
	vbox.add_child(prog_header)

	_progress_text = Label.new()
	_progress_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_text.add_theme_font_override("font", UIStyle.FONT_INDER)
	_progress_text.add_theme_font_size_override("font_size", 16)
	_progress_text.add_theme_color_override("font_color", Color.WHITE)
	prog_header.add_child(_progress_text)

	_remaining_text = Label.new()
	_remaining_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_remaining_text.add_theme_font_override("font", UIStyle.FONT_INDER)
	_remaining_text.add_theme_font_size_override("font_size", 15)
	_remaining_text.add_theme_color_override("font_color", COLOR_GOLD)
	prog_header.add_child(_remaining_text)

	_bar_bg = Panel.new()
	_bar_bg.custom_minimum_size = Vector2(0, 24)
	var bar_style := UIStyle.create_flat_stylebox(Color(0.04, 0.05, 0.10, 1.0), 8, 0, 0)
	bar_style.border_color = Color(0.45, 0.55, 0.72, 0.6)
	bar_style.border_width_left = 1
	bar_style.border_width_top = 1
	bar_style.border_width_right = 1
	bar_style.border_width_bottom = 1
	_bar_bg.add_theme_stylebox_override("panel", bar_style)
	_bar_bg.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	vbox.add_child(_bar_bg)

	_bar_preview_fill = ColorRect.new()
	_bar_preview_fill.anchor_top = 0.0
	_bar_preview_fill.anchor_bottom = 1.0
	_bar_preview_fill.anchor_left = 0.0
	_bar_preview_fill.anchor_right = 0.0
	_bar_preview_fill.color = Color(0.98, 0.83, 0.42, 0.55)
	_bar_bg.add_child(_bar_preview_fill)

	_bar_base_fill = ColorRect.new()
	_bar_base_fill.anchor_top = 0.0
	_bar_base_fill.anchor_bottom = 1.0
	_bar_base_fill.anchor_left = 0.0
	_bar_base_fill.anchor_right = 0.0
	_bar_base_fill.color = Color(0.68, 0.80, 0.96, 0.95)
	_bar_bg.add_child(_bar_base_fill)

	# Offering Readout Box
	var offer_box := PanelContainer.new()
	var offer_style := UIStyle.create_flat_stylebox(COLOR_PANEL_INNER, 10, 18, 14)
	offer_style.border_color = Color(0.35, 0.44, 0.62, 0.55)
	offer_style.border_width_left = 1
	offer_style.border_width_top = 1
	offer_style.border_width_right = 1
	offer_style.border_width_bottom = 1
	offer_box.add_theme_stylebox_override("panel", offer_style)
	vbox.add_child(offer_box)

	var offer_inner := VBoxContainer.new()
	offer_inner.add_theme_constant_override("separation", 10)
	offer_box.add_child(offer_inner)

	var readout_row := HBoxContainer.new()
	offer_inner.add_child(readout_row)

	var left_lbl := Label.new()
	left_lbl.text = "TONIGHT'S OFFERING"
	left_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	left_lbl.add_theme_font_size_override("font_size", 14)
	left_lbl.add_theme_color_override("font_color", COLOR_SILVER_DIM)
	readout_row.add_child(left_lbl)

	_wallet_preview_lbl = Label.new()
	_wallet_preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_preview_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wallet_preview_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_wallet_preview_lbl.add_theme_font_size_override("font_size", 15)
	_wallet_preview_lbl.add_theme_color_override("font_color", COLOR_SILVER)
	readout_row.add_child(_wallet_preview_lbl)

	# Big Amount + Stepper Row
	var stepper_row := HBoxContainer.new()
	stepper_row.add_theme_constant_override("separation", 12)
	stepper_row.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_inner.add_child(stepper_row)

	_minus_btn = Button.new()
	_minus_btn.text = "-₱5"
	_minus_btn.custom_minimum_size = Vector2(68, 38)
	UIStyle.style_button(_minus_btn, Color(0.20, 0.24, 0.36), Color.WHITE, 16.0, 8)
	_minus_btn.pressed.connect(func(): _nudge_offer(-5.0))
	stepper_row.add_child(_minus_btn)

	_offer_amount_lbl = Label.new()
	_offer_amount_lbl.custom_minimum_size = Vector2(180, 0)
	_offer_amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_amount_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_offer_amount_lbl.add_theme_font_size_override("font_size", 34)
	_offer_amount_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	stepper_row.add_child(_offer_amount_lbl)

	_plus_btn = Button.new()
	_plus_btn.text = "+₱5"
	_plus_btn.custom_minimum_size = Vector2(68, 38)
	UIStyle.style_button(_plus_btn, Color(0.20, 0.24, 0.36), Color.WHITE, 16.0, 8)
	_plus_btn.pressed.connect(func(): _nudge_offer(5.0))
	stepper_row.add_child(_plus_btn)

	# Slider
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = maxf(0.0, _max_offer)
	_slider.step = 1.0
	_slider.value = _current_offer
	_slider.custom_minimum_size = Vector2(0, 26)
	_slider.value_changed.connect(_on_slider_changed)
	offer_inner.add_child(_slider)

	# Threshold Hints Row
	var thresh_row := HBoxContainer.new()
	offer_inner.add_child(thresh_row)

	var min_hint := Label.new()
	min_hint.text = "Min Expected: ₱%d" % int(roundf(_min_amount))
	min_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_hint.add_theme_font_override("font", UIStyle.FONT_INDER)
	min_hint.add_theme_font_size_override("font_size", 13)
	min_hint.add_theme_color_override("font_color", COLOR_SILVER)
	thresh_row.add_child(min_hint)

	var gen_hint := Label.new()
	gen_hint.text = "Generous Favor: ₱%d+" % int(roundf(_generous_amount))
	gen_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gen_hint.add_theme_font_override("font", UIStyle.FONT_INDER)
	gen_hint.add_theme_font_size_override("font_size", 13)
	gen_hint.add_theme_color_override("font_color", COLOR_GOLD)
	thresh_row.add_child(gen_hint)

	# Quick Preset Chips
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	preset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_inner.add_child(preset_row)

	var remaining := maxf(0.0, _goal - _total_paid)
	_add_preset_chip(preset_row, "₱0 (Hold)", 0.0, Color(0.24, 0.22, 0.30))
	if _min_amount > 0.0 and _min_amount < remaining:
		_add_preset_chip(preset_row, "Min (₱%d)" % int(roundf(_min_amount)), _min_amount, Color(0.22, 0.32, 0.46))
	if _generous_amount > _min_amount and _generous_amount < remaining:
		_add_preset_chip(preset_row, "Generous (₱%d)" % int(roundf(_generous_amount)), _generous_amount, Color(0.45, 0.36, 0.16))
	var max_label := "Seal Ledger! (₱%d)" % int(roundf(remaining)) if _player_money >= remaining else "Max (₱%d)" % int(roundf(_max_offer))
	_add_preset_chip(preset_row, max_label, _max_offer, Color(0.25, 0.42, 0.36))

	# Live Outcome Forecast Card
	_forecast_panel = PanelContainer.new()
	_forecast_style = UIStyle.create_flat_stylebox(Color(0.10, 0.13, 0.22, 0.95), 10, 16, 12)
	_forecast_style.border_width_left = 2
	_forecast_style.border_width_top = 2
	_forecast_style.border_width_right = 2
	_forecast_style.border_width_bottom = 2
	_forecast_panel.add_theme_stylebox_override("panel", _forecast_style)
	vbox.add_child(_forecast_panel)

	var fc_box := VBoxContainer.new()
	fc_box.add_theme_constant_override("separation", 3)
	_forecast_panel.add_child(fc_box)

	_forecast_badge_lbl = Label.new()
	_forecast_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forecast_badge_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_forecast_badge_lbl.add_theme_font_size_override("font_size", 17)
	fc_box.add_child(_forecast_badge_lbl)

	_forecast_desc_lbl = Label.new()
	_forecast_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forecast_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forecast_desc_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_forecast_desc_lbl.add_theme_font_size_override("font_size", 14)
	_forecast_desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.91, 0.98, 0.92))
	fc_box.add_child(_forecast_desc_lbl)

	# Confirm Button
	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(280, 48)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.style_button(_confirm_btn, Color(0.28, 0.48, 0.40), Color.WHITE, 18.0, 10)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_btn)

	# ── PHASE 2: ROGUELIKE MOON-CARD DRAFT ───────────────────────────────
	_draft_root = Control.new()
	_draft_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_root.visible = false
	_draft_root.modulate.a = 0.0
	root.add_child(_draft_root)

	var draft_header := VBoxContainer.new()
	draft_header.anchor_left = 0.0
	draft_header.anchor_right = 1.0
	draft_header.anchor_top = 0.08
	draft_header.anchor_bottom = 0.24
	draft_header.add_theme_constant_override("separation", 6)
	_draft_root.add_child(draft_header)

	_draft_title_lbl = Label.new()
	_draft_title_lbl.text = "☽  CHOOSE TOMORROW'S MOON CARD  ☾"
	_draft_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draft_title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_draft_title_lbl.add_theme_font_size_override("font_size", 28)
	_draft_title_lbl.add_theme_color_override("font_color", COLOR_SILVER)
	draft_header.add_child(_draft_title_lbl)

	_draft_sub_lbl = Label.new()
	_draft_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draft_sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_draft_sub_lbl.add_theme_font_size_override("font_size", 16)
	_draft_sub_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	draft_header.add_child(_draft_sub_lbl)

	_cards_holder = Control.new()
	_cards_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_draft_root.add_child(_cards_holder)

func _add_preset_chip(parent: HBoxContainer, label_text: String, amount: float, bg_col: Color) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 34)
	UIStyle.style_button(btn, bg_col, Color.WHITE, 13.0, 8)
	btn.disabled = amount > _max_offer + 0.01
	btn.pressed.connect(func():
		if _is_locked:
			return
		EventBus.request_sfx.emit("interact")
		_current_offer = clampf(amount, 0.0, _max_offer)
		_slider.set_value_no_signal(_current_offer)
		_refresh_ledger_ui(true)
	)
	parent.add_child(btn)
	_preset_buttons.append(btn)

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
		_refresh_ledger_ui(true)

func _on_slider_changed(val: float) -> void:
	if _is_locked:
		return
	# Snap cleanly to 5-peso steps unless right at the max_offer cap
	if absf(val - _max_offer) < 2.5:
		_current_offer = _max_offer
	else:
		_current_offer = clampf(roundf(val / 5.0) * 5.0, 0.0, _max_offer)
	_refresh_ledger_ui(true)

func _evaluate_tier(offer: float) -> String:
	if _total_paid + offer >= _goal - 0.01:
		return "cleared"
	if offer >= _generous_amount - 0.01:
		return "generous"
	if offer >= _min_amount - 0.01:
		return "balanced"
	return "shortfall"

func _refresh_ledger_ui(allow_pop: bool) -> void:
	var tier := _evaluate_tier(_current_offer)
	var projected := minf(_goal, _total_paid + _current_offer)
	var rem_after := maxf(0.0, _goal - projected)

	_progress_text.text = "Ledger Paid: ₱%d → ₱%d / ₱%d" % [int(roundf(_total_paid)), int(roundf(projected)), int(roundf(_goal))]
	_remaining_text.text = "SEALED!" if rem_after <= 0.01 else "₱%d left after tonight" % int(roundf(rem_after))

	_bar_base_fill.anchor_right = clampf(_total_paid / _goal, 0.0, 1.0)
	_bar_preview_fill.anchor_right = clampf(projected / _goal, 0.0, 1.0)

	_offer_amount_lbl.text = "₱%d" % int(roundf(_current_offer))
	_wallet_preview_lbl.text = "Drawer: ₱%d → ₱%d" % [int(roundf(_player_money)), int(roundf(maxf(0.0, _player_money - _current_offer)))]

	match tier:
		"cleared":
			_bar_preview_fill.color = Color(0.95, 0.98, 1.0, 0.85)
			_forecast_style.border_color = COLOR_SEALED
			_forecast_style.bg_color = Color(0.14, 0.18, 0.30, 0.98)
			_forecast_badge_lbl.text = "✦  FINAL OFFERING — SEAL THE LEDGER  ✦"
			_forecast_badge_lbl.add_theme_color_override("font_color", COLOR_SEALED)
			_forecast_desc_lbl.text = "Completes Lola's ₱%d pact forever! Ends Reyna Mayari's nightly collections." % int(roundf(_goal))
			_confirm_btn.text = "Seal the Ledger (₱%d)" % int(roundf(_current_offer))
			UIStyle.style_button(_confirm_btn, Color(0.32, 0.50, 0.68), Color.WHITE, 18.0, 10)
		"generous":
			_bar_preview_fill.color = Color(0.98, 0.83, 0.42, 0.68)
			_forecast_style.border_color = COLOR_GOLD
			_forecast_style.bg_color = Color(0.15, 0.14, 0.10, 0.96)
			_forecast_badge_lbl.text = "✦  GENEROUS OFFERING — BIRINGAN'S FAVOR  ✦"
			_forecast_badge_lbl.add_theme_color_override("font_color", COLOR_GOLD)
			_forecast_desc_lbl.text = "Draft 1 of 3 GUARANTEED Favor Cards (Buffs) for tomorrow!"
			_confirm_btn.text = "Offer Generously (₱%d)" % int(roundf(_current_offer))
			UIStyle.style_button(_confirm_btn, Color(0.62, 0.48, 0.18), Color.WHITE, 18.0, 10)
		"balanced":
			_bar_preview_fill.color = Color(0.60, 0.78, 0.96, 0.55)
			_forecast_style.border_color = COLOR_SILVER
			_forecast_style.bg_color = Color(0.09, 0.13, 0.22, 0.96)
			_forecast_badge_lbl.text = "☽  BALANCED LEDGER — MIXED FATE  ☾"
			_forecast_badge_lbl.add_theme_color_override("font_color", COLOR_SILVER)
			_forecast_desc_lbl.text = "Meets Mayari's expectation. Draft 1 of 3 mixed Moon Cards (higher Chill chance)."
			_confirm_btn.text = "Offer Tribute (₱%d)" % int(roundf(_current_offer))
			UIStyle.style_button(_confirm_btn, Color(0.24, 0.42, 0.52), Color.WHITE, 18.0, 10)
		_:
			_bar_preview_fill.color = Color(0.75, 0.42, 0.50, 0.55)
			_forecast_style.border_color = COLOR_CHILL_BORDER
			_forecast_style.bg_color = Color(0.16, 0.09, 0.13, 0.96)
			_forecast_badge_lbl.text = "◐  SHORTFALL — BIRINGAN'S CHILL  ◐"
			_forecast_badge_lbl.add_theme_color_override("font_color", Color(0.95, 0.62, 0.68))
			_forecast_desc_lbl.text = "Below minimum expectation. Draft 1 of 3 Chill Cards (Debuffs / Quirks) for tomorrow."
			_confirm_btn.text = "Offer Nothing (₱0)" if _current_offer <= 0.01 else "Offer Shortfall (₱%d)" % int(roundf(_current_offer))
			UIStyle.style_button(_confirm_btn, Color(0.46, 0.24, 0.28), Color.WHITE, 18.0, 10)

	if allow_pop and tier != _last_tier:
		_last_tier = tier
		EventBus.request_sfx.emit("interact")
		_forecast_panel.pivot_offset = _forecast_panel.size * 0.5
		var pop := create_tween()
		pop.tween_property(_forecast_panel, "scale", Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(_forecast_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	elif _last_tier == "":
		_last_tier = tier

func _play_ledger_entrance() -> void:
	_ledger_panel.modulate.a = 0.0
	_ledger_panel.scale = Vector2(0.92, 0.92)
	await get_tree().process_frame
	if is_instance_valid(_ledger_panel):
		_ledger_panel.pivot_offset = _ledger_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_ledger_panel, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_ledger_panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_confirm_pressed() -> void:
	if _is_locked:
		return
	_is_locked = true
	_slider.editable = false
	_confirm_btn.disabled = true
	_minus_btn.disabled = true
	_plus_btn.disabled = true
	for b in _preset_buttons:
		b.disabled = true

	_confirmed_offer = _current_offer
	_confirmed_tier = _evaluate_tier(_confirmed_offer)

	if _confirmed_offer > 0.0:
		EventBus.request_sfx.emit("money_decrease")
	else:
		EventBus.request_sfx.emit("interact")

	# Animate base bar filling to the new total + border glow pulse
	var new_total := minf(_goal, _total_paid + _confirmed_offer)
	var target_ratio := clampf(new_total / _goal, 0.0, 1.0)
	var fill_tw := create_tween()
	fill_tw.tween_property(_bar_base_fill, "anchor_right", target_ratio, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _confirmed_tier == "generous" or _confirmed_tier == "cleared":
		fill_tw.parallel().tween_property(_ledger_style, "border_color", COLOR_GOLD, 0.22)
		fill_tw.tween_property(_ledger_style, "border_color", COLOR_SILVER, 0.35)
	await fill_tw.finished
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.28).timeout
	if not is_inside_tree():
		return

	# If the player sealed the ₱750 ledger, skip the card draft and close cleanly!
	if _confirmed_tier == "cleared":
		await _fade_out_and_finish("")
		return

	# Transition smoothly from Phase 1 -> Phase 2 (Roguelike 3-Card Moon Draft)
	var out_tw := create_tween()
	out_tw.tween_property(_ledger_panel, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	out_tw.parallel().tween_property(_ledger_panel, "scale", Vector2(0.92, 0.92), 0.22).set_trans(Tween.TRANS_QUAD)
	await out_tw.finished
	if not is_inside_tree():
		return
	_ledger_center.visible = false

	_launch_card_draft()

# ── PHASE 2: ROGUELIKE 3-CARD MOON DRAFT ─────────────────────────────────────

func _launch_card_draft() -> void:
	_card_data_list = MayariCardRegistry.draw_three_cards(_confirmed_tier)
	_card_nodes.clear()
	_card_base_pos.clear()
	_card_base_rot.clear()
	_card_picked = false

	match _confirmed_tier:
		"generous":
			_draft_sub_lbl.text = "Biringan's Favor — All 3 cards are lunar blessings. Pick 1 for tomorrow."
			_draft_sub_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		"shortfall":
			_draft_sub_lbl.text = "Biringan's Chill — Endure Mayari's displeasure. Pick 1 quirk for tomorrow."
			_draft_sub_lbl.add_theme_color_override("font_color", Color(0.95, 0.62, 0.68))
		_:
			_draft_sub_lbl.text = "Balanced Ledger — Fate deals a mixed hand. Pick 1 Moon Card for tomorrow."
			_draft_sub_lbl.add_theme_color_override("font_color", COLOR_SILVER)

	_draft_root.visible = true
	var vp_size := get_viewport().get_visible_rect().size
	var card_size := Vector2(246, 356)
	var spacing := 274.0
	var center_x := vp_size.x * 0.5
	var center_y := vp_size.y * 0.56
	var fan_angles := [-4.0, 0.0, 4.0]
	var fan_y_offsets := [12.0, 0.0, 12.0]

	for i in range(_card_data_list.size()):
		var c_data: Dictionary = _card_data_list[i]
		var card := _create_moon_card(c_data, i, card_size)
		_cards_holder.add_child(card)
		var target_pos := Vector2(
			center_x + (i - 1) * spacing - card_size.x * 0.5,
			center_y - card_size.y * 0.5 + fan_y_offsets[i]
		)
		var target_rot: float = fan_angles[i]
		_card_nodes.append(card)
		_card_base_pos.append(target_pos)
		_card_base_rot.append(target_rot)

		# Start below viewport for juicy staggered deal-in
		card.position = target_pos + Vector2(0, 170)
		card.rotation_degrees = target_rot * 2.0
		card.scale = Vector2(0.75, 0.75)
		card.modulate.a = 0.0
		card.pivot_offset = card_size * 0.5

	var fade_in := create_tween()
	fade_in.tween_property(_draft_root, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

	for i in range(_card_nodes.size()):
		var card := _card_nodes[i]
		var t_pos := _card_base_pos[i]
		var t_rot := _card_base_rot[i]
		var delay := 0.08 + i * 0.12
		var deal_tw := create_tween()
		deal_tw.tween_interval(delay)
		deal_tw.tween_callback(func(): EventBus.request_sfx.emit("interact"))
		deal_tw.tween_property(card, "position", t_pos, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal_tw.parallel().tween_property(card, "rotation_degrees", t_rot, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		deal_tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal_tw.parallel().tween_property(card, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)

func _create_moon_card(c_data: Dictionary, index: int, card_size: Vector2) -> PanelContainer:
	var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
	var border_col := COLOR_GOLD if is_fav else COLOR_CHILL_BORDER
	var bg_col := COLOR_FAVOR_BG if is_fav else COLOR_CHILL_BG
	var badge_text := "✦ BIRINGAN'S FAVOR" if is_fav else "◐ BIRINGAN'S CHILL"
	var accent_col := COLOR_GOLD if is_fav else Color(0.95, 0.62, 0.68)

	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style := UIStyle.create_flat_stylebox(bg_col, 14, 16, 16)
	style.border_color = border_col
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 14
	card.add_theme_stylebox_override("panel", style)
	card.set_meta("card_style", style)
	card.set_meta("base_border", border_col)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	# Kind Badge Pill
	var badge_panel := PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_bg := Color(0.98, 0.83, 0.42, 0.16) if is_fav else Color(0.85, 0.35, 0.45, 0.18)
	var b_style := UIStyle.create_flat_stylebox(badge_bg, 6, 8, 4)
	badge_panel.add_theme_stylebox_override("panel", b_style)
	v.add_child(badge_panel)

	var badge_lbl := Label.new()
	badge_lbl.text = badge_text
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", accent_col)
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(badge_lbl)

	# Sigil Emblem
	var sigil_panel := PanelContainer.new()
	sigil_panel.custom_minimum_size = Vector2(74, 74)
	sigil_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sigil_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sigil_style := UIStyle.create_flat_stylebox(Color(0.04, 0.05, 0.10, 0.9), 37, 0, 0)
	sigil_style.border_color = border_col
	sigil_style.border_width_left = 2
	sigil_style.border_width_top = 2
	sigil_style.border_width_right = 2
	sigil_style.border_width_bottom = 2
	sigil_panel.add_theme_stylebox_override("panel", sigil_style)
	v.add_child(sigil_panel)

	var sigil_lbl := Label.new()
	sigil_lbl.text = str(c_data.get("sigil", "☽"))
	sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_lbl.add_theme_font_size_override("font_size", 34)
	sigil_lbl.add_theme_color_override("font_color", accent_col)
	sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil_panel.add_child(sigil_lbl)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = str(c_data.get("title", "Moon Card"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title_lbl)

	# Tagline
	var tag_lbl := Label.new()
	tag_lbl.text = str(c_data.get("tagline", ""))
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	tag_lbl.add_theme_font_size_override("font_size", 13)
	tag_lbl.add_theme_color_override("font_color", accent_col)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag_lbl)

	# Divider
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.22)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = str(c_data.get("description", ""))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.89, 0.96, 0.92))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc_lbl)

	# Footer cue
	var foot_lbl := Label.new()
	foot_lbl.text = "Click to Select"
	foot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	foot_lbl.add_theme_font_size_override("font_size", 12)
	foot_lbl.add_theme_color_override("font_color", COLOR_SILVER_DIM)
	foot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot_lbl)

	card.mouse_entered.connect(_on_card_hovered.bind(index, true))
	card.mouse_exited.connect(_on_card_hovered.bind(index, false))
	card.gui_input.connect(_on_card_gui_input.bind(index))

	return card

func _on_card_hovered(index: int, is_hovered: bool) -> void:
	if _card_picked or index < 0 or index >= _card_nodes.size():
		return
	if is_hovered:
		EventBus.request_sfx.emit("interact")

	for i in range(_card_nodes.size()):
		var card := _card_nodes[i]
		if not is_instance_valid(card):
			continue
		var style: StyleBoxFlat = card.get_meta("card_style")
		var base_border: Color = card.get_meta("base_border")
		var tw := create_tween()
		if is_hovered and i == index:
			card.z_index = 10
			style.border_color = base_border.lightened(0.3)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			tw.tween_property(card, "position", _card_base_pos[i] + Vector2(0, -22), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "rotation_degrees", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "scale", Vector2(1.07, 1.07), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "modulate", Color.WHITE, 0.14)
		else:
			card.z_index = 0
			style.border_color = base_border
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			var dim := Color(0.76, 0.79, 0.88, 0.92) if is_hovered else Color.WHITE
			tw.tween_property(card, "position", _card_base_pos[i], 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "rotation_degrees", _card_base_rot[i], 0.18).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(card, "modulate", dim, 0.16)

func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if _card_picked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_card(index)

func _select_card(index: int) -> void:
	if _card_picked or index < 0 or index >= _card_data_list.size():
		return
	_card_picked = true
	var chosen_data: Dictionary = _card_data_list[index]
	var chosen_id := str(chosen_data.get("id", ""))
	var is_fav := str(chosen_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR

	EventBus.request_sfx.emit("purchase" if is_fav else "interact")

	_draft_title_lbl.text = "☽  ACTIVE TOMORROW: %s  ☾" % str(chosen_data.get("title", "")).to_upper()
	_draft_sub_lbl.text = str(chosen_data.get("tagline", ""))

	var vp_center_x := get_viewport().get_visible_rect().size.x * 0.5
	for i in range(_card_nodes.size()):
		var card := _card_nodes[i]
		if not is_instance_valid(card):
			continue
		var tw := create_tween()
		if i == index:
			card.z_index = 20
			var style: StyleBoxFlat = card.get_meta("card_style")
			style.border_color = Color.WHITE
			style.border_width_left = 4
			style.border_width_top = 4
			style.border_width_right = 4
			style.border_width_bottom = 4
			var target_center := Vector2(vp_center_x - card.size.x * 0.5, _card_base_pos[i].y - 26.0)
			tw.tween_property(card, "position", target_center, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "rotation_degrees", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC)
			tw.parallel().tween_property(card, "scale", Vector2(1.13, 1.13), 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "modulate", Color.WHITE, 0.2)
		else:
			tw.tween_property(card, "position", _card_base_pos[i] + Vector2(0, 90), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(card, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(0.85).timeout
	if not is_inside_tree():
		return
	await _fade_out_and_finish(chosen_id)

func _fade_out_and_finish(selected_card_id: String) -> void:
	var fade := create_tween()
	fade.tween_property(_backdrop, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	if _ledger_center.visible:
		fade.parallel().tween_property(_ledger_panel, "modulate:a", 0.0, 0.22)
	if _draft_root.visible:
		fade.parallel().tween_property(_draft_root, "modulate:a", 0.0, 0.22)
	await fade.finished
	completed.emit(_confirmed_offer, _confirmed_tier, selected_card_id)
	queue_free()
