class_name EventsOverlay
extends CanvasLayer

## Calendar & Events overlay (Hotkey: C).
## Displays all active Neighborhood Events, Radio-revealed Visitors, Reyna Mayari Moon Cards,
## and Sto. Niño Blessings in exact 1:1 card sizing with MayariTallyOverlay and morning popups,
## paired with a subtle left-edge peek-out Filipino wall calendar that slides open on hover.

const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_ESPRESSO_SURFACE := Color(0.105, 0.092, 0.080, 0.94)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_EVENT := Color(0.95, 0.65, 0.24, 1.0)
const COL_EVENT_BRIGHT := Color(1.0, 0.84, 0.48, 1.0)
const COL_CHILL := Color(0.84, 0.37, 0.36, 1.0)
const COL_CHILL_SOFT := Color(0.95, 0.58, 0.54, 1.0)
const COL_CORAL := Color(0.88, 0.40, 0.36, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.86)
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.9)
const COL_STAT_POS := Color(0.56, 0.92, 0.52, 1.0)
const COL_STAT_NEG := Color(0.96, 0.48, 0.45, 1.0)
const COL_BOLD_CREAM := "#FFF6E5"

const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")
const CALENDAR_TEX_PATH := "res://Assets/ui/calendar_ui.png"
const CALENDAR_FONT_PATH := "res://Assets/Fonts/Balete Trial/BaleteTrial-Bold.ttf"
const CALENDAR_ASPECT := 1647.0 / 2022.0
const CALENDAR_PEEK_PX := 108.0
const CALENDAR_EXPANDED_X := 34.0
const CALENDAR_TILT_DEG := -2.2

const CALENDAR_MONTHS: Array[String] = [
	"JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
	"JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
]
const CALENDAR_START_MONTH_IDX := 7 # August (0-based)
const CALENDAR_START_YEAR := 2013
const CALENDAR_DAYS_PER_MONTH := 31
const CAL_COL_EDGES: Array[float] = [0.0553, 0.1803, 0.3054, 0.4311, 0.5580, 0.6855, 0.8124, 0.9399]
const CAL_ROW_EDGES: Array[float] = [0.4500, 0.5277, 0.6053, 0.6835, 0.7611, 0.8388]

class DayHighlightMarker extends Control:
	var pulse_time: float = 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		pulse_time += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-3.0)
		if r.size.x <= 4.0 or r.size.y <= 4.0:
			return
		var p := 0.5 + 0.5 * sin(pulse_time * 3.0)
		draw_rect(r, Color(0.98, 0.80, 0.24, 0.20 + p * 0.14), true)
		draw_rect(r.grow(1.5), Color(1.0, 0.88, 0.48, 0.18 + p * 0.22), false, 2.0)
		draw_rect(r, Color(0.84, 0.16, 0.13, 0.94), false, 3.0)
		draw_rect(r.grow(-2.5), Color(1.0, 0.92, 0.62, 0.55 + p * 0.25), false, 1.3)

class PastDaysOverlay extends Control:
	var completed_days: int = 0

	func _draw() -> void:
		if completed_days <= 0 or size.x <= 10.0 or size.y <= 10.0:
			return
		var check_col := Color(0.42, 0.24, 0.12, 0.42)
		var wash_col := Color(0.18, 0.12, 0.08, 0.08)
		for d in range(1, completed_days + 1):
			var cell_idx := clampi(d + 1, 2, 32)
			var col := cell_idx % 7
			var row := cell_idx / 7
			var x0 := CAL_COL_EDGES[col] * size.x
			var x1 := CAL_COL_EDGES[col + 1] * size.x
			var y0 := CAL_ROW_EDGES[row] * size.y
			var y1 := CAL_ROW_EDGES[row + 1] * size.y
			var cell_rect := Rect2(x0, y0, x1 - x0, y1 - y0).grow(-4.0)
			draw_rect(cell_rect, wash_col, true)
			# Subtle handwritten sepia diagonal mark across completed days
			var p1 := Vector2(cell_rect.position.x + cell_rect.size.x * 0.22, cell_rect.end.y - cell_rect.size.y * 0.22)
			var p2 := Vector2(cell_rect.end.x - cell_rect.size.x * 0.22, cell_rect.position.y + cell_rect.size.y * 0.22)
			draw_line(p1, p2, check_col, 2.2, true)

var is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _cal_bold_font: FontVariation

var _root: Control
var _backdrop: ColorRect
var _top_bar: HBoxContainer
var _radio_badge: PanelContainer
var _radio_style: StyleBoxFlat
var _radio_icon: Label
var _radio_pulse_time: float = 0.0
var _cal_holder: Control
var _cal_tab: PanelContainer
var _cal_year_left: Label
var _cal_year_right: Label
var _cal_month_lbl: Label
var _cal_past_overlay: PastDaysOverlay
var _cal_day_marker: DayHighlightMarker
var _cal_expanded: bool = false
var _cal_tween: Tween = null
var _cal_tucked_x: float = -300.0
var _frame: PanelContainer
var _cards_vbox: VBoxContainer
var _callout_col: VBoxContainer
var _callout_tween: Tween = null
var _callout_anchor: Control = null

func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cal_bold_font = FontVariation.new()
	if ResourceLoader.exists(CALENDAR_FONT_PATH):
		_cal_bold_font.base_font = load(CALENDAR_FONT_PATH)
	else:
		_cal_bold_font.base_font = UIStyle.FONT_FREDOKA_BOLD
	_cal_bold_font.variation_embolden = 0.35
	_cal_bold_font.spacing_glyph = -2
	_build_ui()
	hide()
	EventBus.events_overlay_toggled.connect(_on_toggled)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.resized.connect(_on_viewport_resized)
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.032, 0.025, 0.020, 0.80)
	_root.add_child(_backdrop)

	# ── Borderless 5%-safe Top Bar (matches RestockMenu / PriceLedgerOverlay) ──
	_top_bar = HBoxContainer.new()
	_top_bar.anchor_left = 0.05
	_top_bar.anchor_right = 0.95
	_top_bar.anchor_top = 0.042
	_top_bar.anchor_bottom = 0.132
	_top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_bar.add_theme_constant_override("separation", 14)
	_root.add_child(_top_bar)

	# Left spacer so right_cluster stays right-aligned
	var left_cluster := Control.new()
	left_cluster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(left_cluster)

	# Subtle top-center conditional Papa Ulap Radio Ready badge
	_radio_badge = PanelContainer.new()
	_radio_badge.anchor_left = 0.5
	_radio_badge.anchor_right = 0.5
	_radio_badge.anchor_top = 0.062
	_radio_badge.anchor_bottom = 0.062
	_radio_badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_radio_badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	_radio_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_style = UIStyle.create_flat_stylebox(Color(0.10, 0.085, 0.065, 0.80), 8, 12, 6)
	_radio_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.40)
	_radio_style.set_border_width_all(1)
	_radio_style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	_radio_style.shadow_size = 4
	_radio_badge.add_theme_stylebox_override("panel", _radio_style)
	_radio_badge.visible = false
	_root.add_child(_radio_badge)

	var rb_row := HBoxContainer.new()
	rb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rb_row.add_theme_constant_override("separation", 6)
	rb_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_badge.add_child(rb_row)

	_radio_icon = Label.new()
	_radio_icon.text = "✦"
	_radio_icon.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_radio_icon.add_theme_font_size_override("font_size", 14)
	_radio_icon.add_theme_color_override("font_color", Color(0.92, 0.80, 0.52, 0.86))
	rb_row.add_child(_radio_icon)

	var rb_lbl := Label.new()
	rb_lbl.text = "Papa Ulap ready to tune"
	rb_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	rb_lbl.add_theme_font_size_override("font_size", 14)
	rb_lbl.add_theme_color_override("font_color", Color(0.92, 0.80, 0.52, 0.86))
	rb_row.add_child(rb_lbl)

	# Right side: Title Case header + 48x48 coral-bordered close button
	var right_cluster := HBoxContainer.new()
	right_cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_cluster.alignment = BoxContainer.ALIGNMENT_END
	right_cluster.add_theme_constant_override("separation", 18)
	_top_bar.add_child(right_cluster)

	var title_stack := VBoxContainer.new()
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 1)
	right_cluster.add_child(title_stack)

	var title_lbl := Label.new()
	title_lbl.text = "Calendar & Events"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", COL_CREAM)
	title_stack.add_child(title_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "Hover left edge for Calendar · Press C or Esc to close"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	hint_lbl.add_theme_font_size_override("font_size", 14)
	hint_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	title_stack.add_child(hint_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Close [C / Esc]"
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	close_btn.add_theme_font_size_override("font_size", 22)
	var cs_norm := UIStyle.create_flat_stylebox(Color(0.18, 0.10, 0.09, 0.92), 10, 6, 2)
	cs_norm.border_color = Color(COL_CORAL.r, COL_CORAL.g, COL_CORAL.b, 0.72)
	cs_norm.set_border_width_all(2)
	var cs_hov := UIStyle.create_flat_stylebox(Color(0.28, 0.13, 0.12, 0.98), 10, 6, 2)
	cs_hov.border_color = Color(1.0, 0.56, 0.52, 0.95)
	cs_hov.set_border_width_all(2)
	close_btn.add_theme_stylebox_override("normal", cs_norm)
	close_btn.add_theme_stylebox_override("hover", cs_hov)
	close_btn.add_theme_stylebox_override("pressed", cs_hov)
	close_btn.add_theme_color_override("font_color", COL_CREAM)
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.90, 1.0))
	close_btn.pressed.connect(close_overlay)
	right_cluster.add_child(close_btn)

	# ── Centered Event Cards Frame (EXACT 0.580 x 0.680 matching MayariTallyOverlay & morning popups) ──
	_frame = PanelContainer.new()
	_frame.anchor_left = 0.210
	_frame.anchor_right = 0.790
	_frame.anchor_top = 0.175
	_frame.anchor_bottom = 0.855
	var f_style := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.046, 0.94), 10, 24, 14)
	f_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.72)
	f_style.set_border_width_all(2)
	f_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	f_style.shadow_size = 24
	_frame.add_theme_stylebox_override("panel", f_style)
	_frame.resized.connect(_sync_card_heights)
	_root.add_child(_frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_frame.add_child(scroll)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards_vbox)

	# ── Left-Edge Subtle Peek-Out Filipino Wall Calendar (hover to slide smoothly into full view) ──
	_cal_holder = Control.new()
	_cal_holder.z_index = 20
	_cal_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_cal_holder.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_root.add_child(_cal_holder)

	var cal_frame := PanelContainer.new()
	cal_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	cal_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cf_style := UIStyle.create_flat_stylebox(Color(0.05, 0.04, 0.035, 0.96), 6, 4, 4)
	cf_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.82)
	cf_style.set_border_width_all(2)
	cf_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	cf_style.shadow_size = 24
	cal_frame.add_theme_stylebox_override("panel", cf_style)
	_cal_holder.add_child(cal_frame)

	var cal_tex_rect := TextureRect.new()
	if ResourceLoader.exists(CALENDAR_TEX_PATH):
		cal_tex_rect.texture = load(CALENDAR_TEX_PATH)
	cal_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cal_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	cal_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cal_frame.add_child(cal_tex_rect)

	# Year (left blue box), Month (center red box), Year (right blue box)
	_cal_year_left = _make_calendar_banner_label(0.056, 0.274, 0.354, 0.417, 27)
	cal_tex_rect.add_child(_cal_year_left)
	_cal_month_lbl = _make_calendar_banner_label(0.280, 0.717, 0.354, 0.417, 32)
	cal_tex_rect.add_child(_cal_month_lbl)
	_cal_year_right = _make_calendar_banner_label(0.723, 0.942, 0.354, 0.417, 27)
	cal_tex_rect.add_child(_cal_year_right)

	# Completed past days subtle sepia overlay
	_cal_past_overlay = PastDaysOverlay.new()
	_cal_past_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cal_past_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cal_tex_rect.add_child(_cal_past_overlay)

	# Current Day pulsing highlight box
	_cal_day_marker = DayHighlightMarker.new()
	_cal_day_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cal_tex_rect.add_child(_cal_day_marker)

	# Subtle antique-gold peek tab along the right edge of the tucked calendar
	_cal_tab = PanelContainer.new()
	_cal_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_style := UIStyle.create_flat_stylebox(Color(0.095, 0.080, 0.065, 0.95), 8, 12, 8)
	tab_style.corner_radius_top_left = 0
	tab_style.corner_radius_bottom_left = 0
	tab_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.85)
	tab_style.border_width_left = 0
	tab_style.border_width_top = 2
	tab_style.border_width_right = 2
	tab_style.border_width_bottom = 2
	tab_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	tab_style.shadow_size = 10
	_cal_tab.add_theme_stylebox_override("panel", tab_style)
	_cal_holder.add_child(_cal_tab)

	var tab_v := VBoxContainer.new()
	tab_v.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_v.add_theme_constant_override("separation", 2)
	tab_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cal_tab.add_child(tab_v)

	var tab_icon := Label.new()
	tab_icon.text = "◈"
	tab_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_icon.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	tab_icon.add_theme_font_size_override("font_size", 14)
	tab_icon.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	tab_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_v.add_child(tab_icon)

	var tab_lbl := Label.new()
	tab_lbl.text = "Cal"
	tab_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	tab_lbl.add_theme_font_size_override("font_size", 14)
	tab_lbl.add_theme_color_override("font_color", COL_CREAM)
	tab_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_v.add_child(tab_lbl)

	# ── Floating Hades keyword callout stack (aligns to right of the hovered card) ──
	_callout_col = VBoxContainer.new()
	_callout_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_callout_col.custom_minimum_size = Vector2(220, 0)
	_callout_col.z_index = 30
	_callout_col.add_theme_constant_override("separation", 10)
	_callout_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout_col.visible = false
	_callout_col.modulate.a = 0.0
	_root.add_child(_callout_col)

	_layout_calendar(true)

func _on_viewport_resized() -> void:
	_layout_calendar(true)
	_sync_card_heights()

func _layout_calendar(instant: bool) -> void:
	if not is_instance_valid(_cal_holder):
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 10.0 or vp.y <= 10.0:
		return
	var cal_h := vp.y * 0.680
	var cal_w := cal_h * CALENDAR_ASPECT
	var cal_y := vp.y * 0.175
	_cal_tucked_x = -cal_w + CALENDAR_PEEK_PX
	_cal_holder.size = Vector2(cal_w, cal_h)
	_cal_holder.pivot_offset = Vector2(cal_w * 0.5, cal_h * 0.5)
	_cal_holder.position.y = cal_y
	if is_instance_valid(_cal_tab):
		_cal_tab.reset_size()
		var tab_sz := _cal_tab.get_combined_minimum_size()
		_cal_tab.position = Vector2(cal_w - 2.0, cal_h * 0.5 - tab_sz.y * 0.5)
	if instant:
		if _cal_tween and _cal_tween.is_valid():
			_cal_tween.kill()
		_cal_holder.position.x = CALENDAR_EXPANDED_X if _cal_expanded else _cal_tucked_x
		_cal_holder.rotation_degrees = 0.0 if _cal_expanded else CALENDAR_TILT_DEG
		if is_instance_valid(_cal_tab):
			_cal_tab.modulate.a = 0.15 if _cal_expanded else 1.0

func _set_calendar_expanded(expanded: bool) -> void:
	if _cal_expanded == expanded:
		return
	_cal_expanded = expanded
	if _cal_tween and _cal_tween.is_valid():
		_cal_tween.kill()
	var target_x := CALENDAR_EXPANDED_X if expanded else _cal_tucked_x
	var target_rot := 0.0 if expanded else CALENDAR_TILT_DEG
	var target_tab_a := 0.12 if expanded else 1.0
	_cal_tween = create_tween().set_parallel(true)
	if expanded:
		_cal_tween.tween_property(_cal_holder, "position:x", target_x, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_cal_tween.tween_property(_cal_holder, "rotation_degrees", target_rot, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_cal_tween.tween_property(_cal_holder, "position:x", target_x, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_cal_tween.tween_property(_cal_holder, "rotation_degrees", target_rot, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(_cal_tab):
		_cal_tween.tween_property(_cal_tab, "modulate:a", target_tab_a, 0.18).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if not is_open:
		return
	if is_instance_valid(_radio_badge) and _radio_badge.visible:
		_radio_pulse_time += delta
		var p := 0.5 + 0.5 * sin(_radio_pulse_time * 3.2)
		var fast_p := 0.5 + 0.5 * sin(_radio_pulse_time * 5.4)
		_radio_badge.pivot_offset = _radio_badge.size * 0.5
		var s := lerpf(1.0, 1.032, p)
		_radio_badge.scale = Vector2(s, s)
		if _radio_style:
			_radio_style.border_color = COL_GOLD.lerp(Color(1.0, 0.94, 0.70, 1.0), p)
			_radio_style.bg_color = Color(0.16, 0.12, 0.055, 0.94).lerp(Color(0.24, 0.18, 0.08, 0.98), p * 0.85)
			_radio_style.shadow_color = Color(COL_GOLD_BRIGHT.r, COL_GOLD_BRIGHT.g, COL_GOLD_BRIGHT.b, 0.14 + p * 0.28)
			_radio_style.shadow_size = int(roundf(8.0 + p * 8.0))
		if is_instance_valid(_radio_icon):
			_radio_icon.pivot_offset = _radio_icon.size * 0.5
			var isc := lerpf(0.92, 1.20, fast_p)
			_radio_icon.scale = Vector2(isc, isc)
			_radio_icon.modulate = Color(1.0, 1.0, 1.0, 0.72 + fast_p * 0.28)

	if not is_instance_valid(_cal_holder):
		return
	var mp := get_viewport().get_mouse_position()
	var hit_rect := _cal_holder.get_global_rect()
	if is_instance_valid(_cal_tab):
		hit_rect = hit_rect.merge(_cal_tab.get_global_rect())
	# Small hysteresis margin when already expanded so sliding/edges never jitter
	if _cal_expanded:
		hit_rect = hit_rect.grow(16.0)
	else:
		hit_rect = hit_rect.grow_side(SIDE_LEFT, 24.0)
	var hovering := hit_rect.has_point(mp)
	if hovering != _cal_expanded:
		_set_calendar_expanded(hovering)

func _make_calendar_banner_label(al: float, ar: float, at: float, ab: float, font_sz: int) -> Label:
	var lbl := Label.new()
	lbl.anchor_left = al
	lbl.anchor_right = ar
	lbl.anchor_top = at
	lbl.anchor_bottom = ab
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.add_theme_font_override("font", _cal_bold_font)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.85))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _refresh_calendar_display() -> void:
	var total_idx := maxi(0, StoryManager.day - 1)
	var months_elapsed := total_idx / CALENDAR_DAYS_PER_MONTH
	var day_in_month := (total_idx % CALENDAR_DAYS_PER_MONTH) + 1
	var month_idx := (CALENDAR_START_MONTH_IDX + months_elapsed) % 12
	var year_num := CALENDAR_START_YEAR + (CALENDAR_START_MONTH_IDX + months_elapsed) / 12

	if is_instance_valid(_radio_badge):
		var can_tune := is_instance_valid(StoreEventManager) and StoreEventManager.can_reveal_next_broadcast()
		_radio_badge.visible = can_tune

	var year_str := str(year_num)
	if is_instance_valid(_cal_year_left):
		_cal_year_left.text = year_str
	if is_instance_valid(_cal_year_right):
		_cal_year_right.text = year_str
	if is_instance_valid(_cal_month_lbl):
		var m_txt := CALENDAR_MONTHS[month_idx]
		_cal_month_lbl.text = m_txt
		var m_sz := 28 if m_txt.length() >= 8 else 32
		_cal_month_lbl.add_theme_font_size_override("font_size", m_sz)

	if is_instance_valid(_cal_past_overlay):
		_cal_past_overlay.completed_days = maxi(0, day_in_month - 1)
		_cal_past_overlay.queue_redraw()

	if is_instance_valid(_cal_day_marker):
		# Day 1 is at Tuesday (col 2, row 0) -> cell_idx = day_in_month + 1 (2..32)
		var cell_idx := clampi(day_in_month + 1, 2, 32)
		var col := cell_idx % 7
		var row := cell_idx / 7
		_cal_day_marker.anchor_left = CAL_COL_EDGES[col]
		_cal_day_marker.anchor_right = CAL_COL_EDGES[col + 1]
		_cal_day_marker.anchor_top = CAL_ROW_EDGES[row]
		_cal_day_marker.anchor_bottom = CAL_ROW_EDGES[row + 1]
		_cal_day_marker.offset_left = 0.0
		_cal_day_marker.offset_right = 0.0
		_cal_day_marker.offset_top = 0.0
		_cal_day_marker.offset_bottom = 0.0
		_cal_day_marker.queue_redraw()

func _on_toggled(opened: bool) -> void:
	if opened:
		if is_open:
			close_overlay()
		else:
			open_overlay()
	else:
		close_overlay()

func open_overlay() -> void:
	if is_open:
		return
	is_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")
	_cal_expanded = false
	_refresh_calendar_display()
	_populate_cards()
	show()
	_layout_calendar(true)
	_backdrop.modulate.a = 0.0
	_top_bar.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_cal_holder.modulate.a = 0.0
	var start_cal_x := _cal_tucked_x - 42.0
	_cal_holder.position.x = start_cal_x
	var tw := create_tween()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_top_bar, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_frame, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_cal_holder, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_cal_holder, "position:x", _cal_tucked_x, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func close_overlay() -> void:
	if not is_open:
		return
	is_open = false
	_cal_expanded = false
	if _cal_tween and _cal_tween.is_valid():
		_cal_tween.kill()
	_show_keyword_callouts([])
	hide()
	Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("drop")
	EventBus.events_overlay_toggled.emit(false)

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var is_esc: bool = event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE))
	var is_c: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_C or event.keycode == KEY_C)
	if is_esc or is_c:
		close_overlay()
		get_viewport().set_input_as_handled()

func _populate_cards() -> void:
	for child in _cards_vbox.get_children():
		_cards_vbox.remove_child(child)
		child.queue_free()

	var total_active := 0

	# 1. Active Neighborhood Events
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			_cards_vbox.add_child(_build_neighborhood_event_card(ev))
			total_active += 1

	# 1B. Radio-Revealed Daily Visitor Sightings
	if is_instance_valid(StoryManager):
		for vis in StoryManager.get_revealed_expected_regulars():
			_cards_vbox.add_child(_build_visitor_event_card(vis))
			total_active += 1

	# 2. Active Reyna Mayari Moon Card(s)
	var mayari_ids: Array[String] = StoryManager.active_mayari_cards
	if mayari_ids.is_empty() and StoryManager.active_mayari_card != "":
		mayari_ids = [StoryManager.active_mayari_card]
	for mid in mayari_ids:
		var card := MayariCardRegistry.get_card(mid)
		if not card.is_empty():
			_cards_vbox.add_child(_build_mayari_event_card(card, false, mid))
			total_active += 1

	# 3. Active Sto. Niño Blessings
	for b_id in StoryManager.active_blessing_cards:
		var b_card := MayariCardRegistry.get_card(b_id)
		if not b_card.is_empty():
			_cards_vbox.add_child(_build_mayari_event_card(b_card, true, "blessing_" + b_id))
			total_active += 1

	if total_active == 0:
		var empty_box := PanelContainer.new()
		empty_box.custom_minimum_size = Vector2(0, 150)
		var es := UIStyle.create_flat_stylebox(Color(0.088, 0.078, 0.068, 0.92), 8, 24, 24)
		es.border_color = Color(0.482, 0.306, 0.102, 0.65)
		es.set_border_width_all(1)
		empty_box.add_theme_stylebox_override("panel", es)
		var empty_lbl := Label.new()
		empty_lbl.text = "Karimlan is quiet today.\n\nNo active Neighborhood Events, visitors, or lunar omens right now."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		empty_lbl.add_theme_font_size_override("font_size", 19)
		empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		empty_box.add_child(empty_lbl)
		_cards_vbox.add_child(empty_box)

func _category_display(cat: String) -> String:
	match cat.to_lower():
		"bottle": return "Beverages"
		"snack": return "Snacks"
		"can": return "Canned Goods"
		"cigarette": return "Cigarettes"
		"candy": return "Candies"
		"pack": return "Noodles"
		"sachet": return "Sachets"
		"frozen": return "Frozen"
		_: return cat.capitalize()

func _event_sigil(event_id: String) -> String:
	match event_id:
		"barangay_liga": return "◈"
		"brownout_notice": return "⚡"
		"payday_friday": return "₱"
		"summer_heat": return "☀"
		"typhoon_warning": return "〰"
		_: return "✦"

func _format_natural_list(names: PackedStringArray) -> String:
	var count := names.size()
	if count == 0:
		return "Featured Stock"
	if count == 1:
		return names[0]
	if count == 2:
		return "%s and %s" % [names[0], names[1]]
	var leading := PackedStringArray()
	for i in range(count - 1):
		leading.append(names[i])
	return "%s, and %s" % [", ".join(leading), names[count - 1]]

func _build_neighborhood_event_card(ev: StoreEventData) -> PanelContainer:
	var desc_rich := ev.description
	if ev.has_target_items():
		var target_names: PackedStringArray = []
		for cat in ev.affected_categories:
			target_names.append(_category_display(cat))
		if target_names.is_empty():
			for it in ev.affected_items:
				if it:
					target_names.append(it.item_name)
		var targets_str := _format_natural_list(target_names)
		desc_rich = "%s Neighbors are actively seeking [b]%s[/b] today." % [ev.description, targets_str]
	var stats: Array = ev.build_stat_rows()
	var kws: Array = ev.get_keywords()
	return _build_hades_card(ev.event_name, _event_sigil(ev.event_id), desc_rich, stats, "event", kws, ev.get_icon_path(), ev.event_id)

func _build_visitor_event_card(vis: CustomerData) -> PanelContainer:
	var desc_rich := "Papa Ulap spotted [b]%s[/b] heading toward your store today." % vis.character_name
	var stats: Array = [
		{"label": "Spawn Chance:", "value": "+120%", "tone": "pos"},
	]
	var fav_names := PackedStringArray()
	for fcat in vis.get_favorite_categories():
		fav_names.append(_category_display(fcat))
	var fav_list := _format_natural_list(fav_names)
	var tip_desc := ("One of your friendly neighbors! Likes %s." % fav_list) if not fav_names.is_empty() else "One of your friendly neighbors dropping by today!"
	var kws: Array = [
		{"title": vis.character_name, "desc": tip_desc},
	]
	return _build_hades_card(
		"Visitor: %s" % vis.character_name,
		"!",
		desc_rich,
		stats,
		"event",
		kws,
		"res://Assets/ui/icons/user-round-exclamation-point.png",
		"visitor_" + vis.character_name
	)

func _build_mayari_event_card(c_data: Dictionary, is_blessing: bool = false, card_id: String = "") -> PanelContainer:
	var is_fav := str(c_data.get("kind", "")) == MayariCardRegistry.KIND_FAVOR
	var desc_rich := str(c_data.get("description_rich", c_data.get("description", "")))
	var stats: Array = c_data.get("stats", [])
	var kws: Array = c_data.get("keywords", [])
	var kind_str := "blessing" if is_blessing else ("favor" if is_fav else "omen")
	var fx_id := card_id if card_id != "" else str(c_data.get("id", c_data.get("title", "")))
	return _build_hades_card(
		str(c_data.get("title", "Moon Card")),
		str(c_data.get("sigil", "☽")),
		desc_rich,
		stats,
		kind_str,
		kws,
		str(c_data.get("icon", "")),
		fx_id
	)

func _get_unified_card_height() -> float:
	# Exact 1:1 card height matching the 3 slots inside MayariTallyOverlay's 0.680-tall frame and morning popups
	var fh := _frame.size.y if is_instance_valid(_frame) and _frame.size.y > 100.0 else get_viewport().get_visible_rect().size.y * 0.680
	return maxf(130.0, (fh - 135.0) / 3.0)

func _sync_card_heights() -> void:
	if not is_instance_valid(_cards_vbox):
		return
	var target_h := _get_unified_card_height()
	for ch in _cards_vbox.get_children():
		if ch is PanelContainer and ch.has_meta("is_hades_card"):
			ch.custom_minimum_size = Vector2(0, target_h)

func _build_hades_card(title: String, sigil: String, desc_rich: String, stats: Array, kind: String, keywords: Array = [], icon_path: String = "", fx_id: String = "") -> PanelContainer:
	var pal: Dictionary = HadesEmblem.palette(kind)
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]
	var row_bg: Color = pal["bg"]
	var tag: String = str(pal["tag"]).capitalize()

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, _get_unified_card_height())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("is_hades_card", true)
	var style := UIStyle.create_flat_stylebox(row_bg, 6, 16, 10)
	style.content_margin_right = 20
	style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 52)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(88, 88)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	emblem.set_fx_from_id(fx_id if fx_id != "" else title)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(emblem)

	HadesEmblem.populate_emblem_glyph(emblem, icon_path, sigil, accent_bright, 36.0, 36)

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
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", accent_bright)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(title_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = tag
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	tag_lbl.add_theme_font_size_override("font_size", 18)
	tag_lbl.add_theme_color_override("font_color", accent_bright)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(tag_lbl)

	var desc_rt := RichTextLabel.new()
	desc_rt.bbcode_enabled = true
	desc_rt.fit_content = true
	desc_rt.scroll_active = false
	desc_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_rt.add_theme_font_override("normal_font", UIStyle.FONT_FREDOKA_REG)
	desc_rt.add_theme_font_override("bold_font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	desc_rt.add_theme_font_size_override("normal_font_size", 17)
	desc_rt.add_theme_font_size_override("bold_font_size", 17)
	desc_rt.add_theme_color_override("default_color", COL_CREAM_MUTED)
	desc_rt.text = desc_rich.replace("[b]", "[b][color=%s]" % COL_BOLD_CREAM).replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

	if stats.size() >= 3:
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
			s_name.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			s_name.add_theme_font_size_override("font_size", 15)
			s_name.add_theme_color_override("font_color", COL_CREAM)
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
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
		var lbl_sz := 16 if stats.size() == 2 else 17
		var val_sz := 17 if stats.size() == 2 else 18
		for st in stats:
			var stat_dict: Dictionary = st
			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 12)
			s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_box.add_child(s_row)

			var s_name := Label.new()
			s_name.text = "▸ " + str(stat_dict.get("label", ""))
			s_name.custom_minimum_size = Vector2(345, 0)
			s_name.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
			s_name.add_theme_font_size_override("font_size", lbl_sz)
			s_name.add_theme_color_override("font_color", COL_CREAM)
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			s_val.add_theme_font_size_override("font_size", val_sz)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := COL_STAT_POS if tone == "pos" else (COL_STAT_NEG if tone == "neg" else COL_GOLD_BRIGHT)
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)

	if not keywords.is_empty():
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_entered.connect(_show_keyword_callouts.bind(keywords, card))
		card.mouse_exited.connect(func():
			if is_instance_valid(card) and card.get_global_rect().has_point(get_viewport().get_mouse_position()):
				return
			if _callout_anchor == card:
				_show_keyword_callouts([], null)
		)

	return card

func _position_callout_beside(anchor_ctrl: Control) -> void:
	if not is_instance_valid(_callout_col) or not is_instance_valid(anchor_ctrl):
		return
	var vp_sz := get_viewport().get_visible_rect().size
	var rect := anchor_ctrl.get_global_rect()
	var c_sz := _callout_col.get_combined_minimum_size()
	var cw := clampf(c_sz.x, 260.0, 310.0)
	var ch := maxf(c_sz.y, 72.0)
	_callout_col.size = Vector2(cw, ch)
	var tx := minf(rect.end.x + 28.0, vp_sz.x - cw - 12.0)
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
		var info: Dictionary = kw_id if kw_id is Dictionary else MayariCardRegistry.get_keyword(str(kw_id))
		if info.is_empty():
			continue
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(280, 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs := UIStyle.create_flat_stylebox(Color(0.062, 0.054, 0.046, 0.96), 8, 14, 10)
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
		kt.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		kt.add_theme_font_size_override("font_size", 20)
		kt.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		kt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(kt)

		var kd := Label.new()
		kd.text = str(info.get("desc", ""))
		kd.custom_minimum_size = Vector2(248, 0)
		kd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kd.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		kd.add_theme_font_size_override("font_size", 17)
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
