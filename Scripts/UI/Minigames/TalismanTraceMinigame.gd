class_name TalismanTraceMinigame
extends CanvasLayer

## Anting-Anting / Talisman Tracing Minigame tied to Brahim's albularyo arc.
## Features 20 progressive multi-color, multi-brush-size sacred sigils rendered as
## smooth rounded hollow brush guides directly over Assets/ui/talisman.png, with
## overlap-friendly color-bitmask + coverage + precision accuracy evaluation.

signal minigame_finished(won: bool, result: Dictionary)

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
const AccessibilityPaletteScript := preload("res://Scripts/UI/AccessibilityPalette.gd")

const TALISMAN_TEX_PATH := "res://Assets/ui/talisman.png"
const BRAHIM_PORTRAIT_PATH := "res://Assets/characters/portraits/Brahim Face.png"
const ICON_BRUSH := "res://Assets/ui/lucide/brush.png"
const ICON_ERASER := "res://Assets/ui/lucide/eraser.png"
const ICON_UNDO := "res://Assets/ui/lucide/undo-2.png"
const ICON_REDO := "res://Assets/ui/lucide/redo-2.png"
const ICON_TRASH := "res://Assets/ui/lucide/trash-2.png"
const ICON_SPARKLES := "res://Assets/ui/icons/sparkles.png"
const ICON_CLOSE := "res://Assets/ui/lucide/x.png"

# Matches 1792x2400 aspect ratio (~0.747) at crisp interactive resolution
const CANVAS_SIZE := Vector2i(560, 750)

# Safe inner drawable face of Assets/ui/talisman.png (normalized UVs)
const SAFE_CENTER := Vector2(0.50, 0.525)
const SAFE_RX := 0.28
const SAFE_RY := 0.30

# Warm Espresso + Antique Gold + Cream palette
const COL_BACKDROP := Color(0.06, 0.04, 0.03, 0.82)
const COL_DOCK_BG := Color(0.11, 0.08, 0.06, 0.94)
const COL_CARD_BG := Color(0.12, 0.09, 0.07, 0.97)
const COL_GOLD := Color(0.86, 0.67, 0.32, 1.0)
const COL_GOLD_SOFT := Color(0.86, 0.67, 0.32, 0.42)
const COL_CREAM := Color(0.97, 0.93, 0.86, 1.0)
const COL_MUTED := Color(0.76, 0.70, 0.62, 1.0)
const COL_SUCCESS := Color(0.42, 0.82, 0.52, 1.0)
const COL_FAIL := Color(0.90, 0.40, 0.34, 1.0)

# Color indices: 0 = Charcoal, 1 = Crimson, 2 = Indigo, 3 = Sacred Gold
const INK_CHARCOAL := 0
const INK_CRIMSON := 1
const INK_INDIGO := 2
const INK_GOLD := 3

const INK_SWATCHES: Array[Dictionary] = [
	{"name": "Charcoal", "color": Color(0.11, 0.08, 0.06, 1.0), "guide": Color(0.14, 0.10, 0.08, 1.0)},
	{"name": "Orasyon Crimson", "color": Color(0.68, 0.14, 0.12, 1.0), "guide": Color(0.78, 0.16, 0.14, 1.0)},
	{"name": "Indigo Night", "color": Color(0.13, 0.24, 0.52, 1.0), "guide": Color(0.18, 0.34, 0.70, 1.0)},
	{"name": "Sacred Gold", "color": Color(1.00, 0.90, 0.52, 1.0), "guide": Color(0.98, 0.82, 0.26, 1.0)},
]

var is_open: bool = false

var _patterns: Array[Dictionary] = []
var _current_level: int = 1 # 1..20
var _locked_level: bool = false
var _best_accuracy_this_session: int = 0
var _last_result: Dictionary = {}
var _dash_phase: float = 0.0
var _is_evaluating: bool = false
var _guide_polylines_norm: Array = []
var _guide_mask: PackedByteArray = PackedByteArray()
var _guide_color_bits: PackedByteArray = PackedByteArray()
var _guide_core_pixels: int = 0
var _current_brush_size_index: int = 1
var _current_ink_index: int = 0

var _talisman_tex: Texture2D = null
var _brahim_tex: Texture2D = null

# UI references
var _root: Control
var _backdrop: ColorRect
var _stage_container: Control
var _canvas: CanvasDrawSurface
var _title_label: Label
var _subtitle_label: Label
var _target_badge_label: Label
var _stage_label: Label
var _prev_stage_btn: Button
var _next_stage_btn: Button
var _inscribe_btn: Button
var _brush_btn: Button
var _eraser_btn: Button
var _undo_btn: Button
var _redo_btn: Button
var _clear_btn: Button
var _swatch_buttons: Array[Button] = []
var _size_buttons: Array[Button] = []
var _intro_overlay: ColorRect
var _intro_panel: PanelContainer
var _result_overlay: ColorRect
var _result_panel: PanelContainer
var _result_title: Label
var _result_score: Label
var _result_stats_row: HBoxContainer
var _result_retry_btn: Button
var _result_done_btn: Button


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if ResourceLoader.exists(TALISMAN_TEX_PATH):
		_talisman_tex = load(TALISMAN_TEX_PATH)
	if ResourceLoader.exists(BRAHIM_PORTRAIT_PATH):
		_brahim_tex = load(BRAHIM_PORTRAIT_PATH)

	_patterns = _build_talisman_patterns()
	_build_ui()


func _process(delta: float) -> void:
	if not is_open:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_dash_phase = fmod(_dash_phase + delta * 18.0, 1000.0)
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func open_minigame(config: Dictionary = {}) -> void:
	is_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_is_evaluating = false
	_best_accuracy_this_session = 0
	_last_result = {}

	var start_lvl := 1
	_locked_level = bool(config.get("lock_level", false))
	if bool(config.get("random", false)):
		start_lvl = randi_range(1, _patterns.size())
		_locked_level = true
	elif config.has("level"):
		start_lvl = clampi(int(config.get("level", 1)), 1, _patterns.size())
	elif is_instance_valid(StoryManager) and StoryManager.has_method("get_world_flag"):
		var saved_lvl = StoryManager.get_world_flag("brahim_talisman_level", 1)
		start_lvl = clampi(int(saved_lvl), 1, _patterns.size())

	_load_level(start_lvl)
	_select_tool(CanvasDrawSurface.Tool.BRUSH)

	_result_overlay.visible = false
	if Juice.are_minigame_tutorials_enabled() and not bool(config.get("skip_intro", false)):
		_canvas.input_enabled = false
		_intro_overlay.visible = true
		call_deferred("_pop_intro_deferred")
	else:
		_intro_overlay.visible = false
		_canvas.input_enabled = true

	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)


func _pop_intro_deferred() -> void:
	if is_instance_valid(_intro_panel):
		Juice.pop_panel_in(_intro_panel)


func _close_minigame(won: bool, result: Dictionary) -> void:
	if not is_open:
		return
	is_open = false
	_canvas.input_enabled = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	minigame_finished.emit(won, result)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _intro_overlay.visible:
				_dismiss_intro()
			elif _result_overlay.visible:
				_close_minigame(bool(_last_result.get("won", false)), _last_result)
			else:
				_close_minigame(false, {"level": _current_level, "accuracy": _best_accuracy_this_session, "cancelled": true})
			return

		if _intro_overlay.visible or _result_overlay.visible or _is_evaluating:
			return

		if event.ctrl_pressed and event.keycode == KEY_Z:
			get_viewport().set_input_as_handled()
			if event.shift_pressed:
				_canvas.redo()
			else:
				_canvas.undo()
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			get_viewport().set_input_as_handled()
			_canvas.redo()
		elif event.keycode == KEY_B:
			get_viewport().set_input_as_handled()
			_select_tool(CanvasDrawSurface.Tool.BRUSH)
		elif event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			_select_tool(CanvasDrawSurface.Tool.ERASER)
		elif event.keycode == KEY_1:
			get_viewport().set_input_as_handled()
			_select_ink_color(0)
		elif event.keycode == KEY_2:
			get_viewport().set_input_as_handled()
			_select_ink_color(1)
		elif event.keycode == KEY_3:
			get_viewport().set_input_as_handled()
			_select_ink_color(2)
		elif event.keycode == KEY_4:
			get_viewport().set_input_as_handled()
			_select_ink_color(3)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _canvas.has_any_ink():
				_on_inscribe_pressed()


# =============================================================================
# UI CONSTRUCTION (Dark Warm Espresso + Antique Gold + Fredoka)
# =============================================================================

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "TalismanTraceRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = COL_BACKDROP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_backdrop)

	# 5% title-safe margin wrapper
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 48)
	safe_margin.add_theme_constant_override("margin_right", 48)
	safe_margin.add_theme_constant_override("margin_top", 26)
	safe_margin.add_theme_constant_override("margin_bottom", 24)
	_root.add_child(safe_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	safe_margin.add_child(main_vbox)

	# --- TOP HEADER ---
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header)

	var title_box := HBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 14)
	header.add_child(title_box)

	if _brahim_tex:
		var p_frame := PanelContainer.new()
		p_frame.custom_minimum_size = Vector2(56, 56)
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Color(0.18, 0.13, 0.09, 0.96)
		p_style.border_color = COL_GOLD
		p_style.set_border_width_all(2)
		p_style.set_corner_radius_all(28)
		p_style.set_content_margin_all(4)
		p_frame.add_theme_stylebox_override("panel", p_style)
		var portrait := TextureRect.new()
		portrait.texture = _brahim_tex
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p_frame.add_child(portrait)
		title_box.add_child(p_frame)

	var titles_v := VBoxContainer.new()
	titles_v.alignment = BoxContainer.ALIGNMENT_CENTER
	titles_v.add_theme_constant_override("separation", 2)
	title_box.add_child(titles_v)

	_title_label = Label.new()
	_title_label.text = "Anting-Anting Inscription"
	_title_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COL_CREAM)
	titles_v.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Match each stroke's ink color and brush width to empower Brahim's talisman."
	_subtitle_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_subtitle_label.add_theme_font_size_override("font_size", 15)
	_subtitle_label.add_theme_color_override("font_color", COL_MUTED)
	titles_v.add_child(_subtitle_label)

	var meta_box := HBoxContainer.new()
	meta_box.alignment = BoxContainer.ALIGNMENT_END
	meta_box.add_theme_constant_override("separation", 12)
	header.add_child(meta_box)

	var stage_pill := PanelContainer.new()
	stage_pill.add_theme_stylebox_override("panel", _make_pill_style(Color(0.14, 0.10, 0.07, 0.92), COL_GOLD_SOFT, 10, 10, 6))
	meta_box.add_child(stage_pill)

	var stage_h := HBoxContainer.new()
	stage_h.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_h.add_theme_constant_override("separation", 8)
	stage_pill.add_child(stage_h)

	_prev_stage_btn = _make_icon_text_button("◀", Vector2(32, 32), 16)
	_prev_stage_btn.tooltip_text = "Previous Talisman"
	_prev_stage_btn.pressed.connect(func(): _step_level(-1))
	stage_h.add_child(_prev_stage_btn)

	_stage_label = Label.new()
	_stage_label.text = "Sigil 1 / 20"
	_stage_label.custom_minimum_size = Vector2(96, 0)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_stage_label.add_theme_font_size_override("font_size", 16)
	_stage_label.add_theme_color_override("font_color", COL_CREAM)
	stage_h.add_child(_stage_label)

	_next_stage_btn = _make_icon_text_button("▶", Vector2(32, 32), 16)
	_next_stage_btn.tooltip_text = "Next Talisman"
	_next_stage_btn.pressed.connect(func(): _step_level(1))
	stage_h.add_child(_next_stage_btn)

	var target_pill := PanelContainer.new()
	target_pill.add_theme_stylebox_override("panel", _make_pill_style(Color(0.20, 0.14, 0.08, 0.94), COL_GOLD, 10, 14, 8))
	meta_box.add_child(target_pill)

	_target_badge_label = Label.new()
	_target_badge_label.text = "Target: 62%"
	_target_badge_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_target_badge_label.add_theme_font_size_override("font_size", 17)
	_target_badge_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
	target_pill.add_child(_target_badge_label)

	# Standardized 48x48 coral-bordered espresso close button
	var close_btn := Button.new()
	Juice.style_close_button(close_btn)
	close_btn.pressed.connect(func():
		_close_minigame(false, {"level": _current_level, "accuracy": _best_accuracy_this_session, "cancelled": true})
	)
	header.add_child(close_btn)

	# --- CENTER FOCAL STAGE: ZOOMED-IN TALISMAN CANVAS ---
	_stage_container = Control.new()
	_stage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_stage_container)

	_canvas = CanvasDrawSurface.new()
	_canvas.name = "TalismanDrawSurface"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.transparent_background = true
	_canvas.background_texture = _talisman_tex
	_canvas.show_frame_chrome = false
	_canvas.canvas_padding = 6.0
	_canvas.guide_draw_callback = Callable(self, "_draw_talisman_guide")
	_canvas.setup_canvas(CANVAS_SIZE)
	_canvas.history_changed.connect(_on_history_changed)
	_canvas.stroke_updated.connect(_on_stroke_updated)
	_canvas.stroke_committed.connect(func(_c): Juice.play_sfx("interact", randf_range(0.96, 1.06), -8.0))
	_stage_container.add_child(_canvas)

	# --- BOTTOM DOCK ---
	var dock_center := HBoxContainer.new()
	dock_center.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(dock_center)

	var dock_panel := PanelContainer.new()
	dock_panel.add_theme_stylebox_override("panel", _make_pill_style(COL_DOCK_BG, COL_GOLD_SOFT, 16, 20, 10))
	dock_center.add_child(dock_panel)

	var dock_row := HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 14)
	dock_panel.add_child(dock_row)

	# 1) Ritual Ink Swatches (1..4)
	var swatch_box := HBoxContainer.new()
	swatch_box.alignment = BoxContainer.ALIGNMENT_CENTER
	swatch_box.add_theme_constant_override("separation", 8)
	dock_row.add_child(swatch_box)

	for i in range(INK_SWATCHES.size()):
		var sw_info: Dictionary = INK_SWATCHES[i]
		var sw_btn := Button.new()
		sw_btn.custom_minimum_size = Vector2(36, 36)
		sw_btn.focus_mode = Control.FOCUS_NONE
		sw_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sw_btn.tooltip_text = "%s [%d]" % [str(sw_info["name"]), i + 1]
		sw_btn.pressed.connect(_select_ink_color.bind(i))
		swatch_box.add_child(sw_btn)
		_swatch_buttons.append(sw_btn)

	dock_row.add_child(_make_vsep())

	# 2) Brush / Eraser
	var tool_box := HBoxContainer.new()
	tool_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_box.add_theme_constant_override("separation", 8)
	dock_row.add_child(tool_box)

	_brush_btn = _make_lucide_button(ICON_BRUSH, "Brush", Vector2(44, 42), "Brush (B)")
	_brush_btn.pressed.connect(func(): _select_tool(CanvasDrawSurface.Tool.BRUSH))
	tool_box.add_child(_brush_btn)

	_eraser_btn = _make_lucide_button(ICON_ERASER, "Erase", Vector2(44, 42), "Eraser (E)")
	_eraser_btn.pressed.connect(func(): _select_tool(CanvasDrawSurface.Tool.ERASER))
	tool_box.add_child(_eraser_btn)

	dock_row.add_child(_make_vsep())

	# 3) Brush Size Dots
	var size_box := HBoxContainer.new()
	size_box.alignment = BoxContainer.ALIGNMENT_CENTER
	size_box.add_theme_constant_override("separation", 6)
	dock_row.add_child(size_box)

	var dot_labels: Array[String] = ["•", "●", "⬤", "⬤"]
	var dot_fonts: Array[int] = [14, 18, 22, 27]
	var size_names: Array[String] = ["Fine Brush", "Medium Brush", "Bold Brush", "Broad Brush"]
	for i in range(4):
		var sb := _make_icon_text_button(dot_labels[i], Vector2(38, 38), dot_fonts[i])
		sb.tooltip_text = size_names[i]
		sb.pressed.connect(_select_size.bind(i))
		size_box.add_child(sb)
		_size_buttons.append(sb)

	dock_row.add_child(_make_vsep())

	# 4) Undo / Redo / Clear
	var hist_box := HBoxContainer.new()
	hist_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hist_box.add_theme_constant_override("separation", 8)
	dock_row.add_child(hist_box)

	_undo_btn = _make_lucide_button(ICON_UNDO, "↶", Vector2(42, 42), "Undo (Ctrl+Z)")
	_undo_btn.pressed.connect(func():
		_canvas.undo()
		Juice.play_sfx("tab_switch", 0.92, -6.0)
	)
	hist_box.add_child(_undo_btn)

	_redo_btn = _make_lucide_button(ICON_REDO, "↷", Vector2(42, 42), "Redo (Ctrl+Y)")
	_redo_btn.pressed.connect(func():
		_canvas.redo()
		Juice.play_sfx("tab_switch", 1.08, -6.0)
	)
	hist_box.add_child(_redo_btn)

	_clear_btn = _make_lucide_button(ICON_TRASH, "Clear", Vector2(42, 42), "Clear Ink")
	_clear_btn.pressed.connect(func():
		_canvas.clear_canvas()
		Juice.play_sfx("drop", 0.90, -5.0)
	)
	hist_box.add_child(_clear_btn)

	dock_row.add_child(_make_vsep())

	# 5) Primary Action: Inscribe Talisman
	_inscribe_btn = Button.new()
	_inscribe_btn.text = " Inscribe Talisman"
	if ResourceLoader.exists(ICON_SPARKLES):
		_inscribe_btn.icon = load(ICON_SPARKLES)
		_inscribe_btn.expand_icon = true
		_inscribe_btn.add_theme_constant_override("icon_max_width", 20)
	Juice.style_primary_button(_inscribe_btn, Vector2(228, 46))
	_inscribe_btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_inscribe_btn.disabled = true
	_inscribe_btn.pressed.connect(_on_inscribe_pressed)
	dock_row.add_child(_inscribe_btn)

	_build_intro_modal()
	_build_result_modal()


func _build_intro_modal() -> void:
	_intro_overlay = ColorRect.new()
	_intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_overlay.color = Color(0.03, 0.02, 0.015, 0.68)
	_intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_overlay.visible = false
	_root.add_child(_intro_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_overlay.add_child(center)

	_intro_panel = PanelContainer.new()
	_intro_panel.custom_minimum_size = Vector2(560, 0)
	_intro_panel.add_theme_stylebox_override("panel", _make_pill_style(COL_CARD_BG, COL_GOLD, 18, 30, 26))
	center.add_child(_intro_panel)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_intro_panel.add_child(v)

	var h := Label.new()
	h.text = "Brahim's Anting-Anting"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	h.add_theme_font_size_override("font_size", 30)
	h.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
	v.add_child(h)

	var body := Label.new()
	body.text = "Trace each hollow brush guide to inscribe the talisman.\nMatch both the ink color ([1]–[4]) and brush thickness — overlapping strokes accept either color!"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", COL_CREAM)
	v.add_child(body)

	var start_btn := Button.new()
	start_btn.text = "Begin Inscription"
	Juice.style_primary_button(start_btn, Vector2(220, 48))
	start_btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	start_btn.pressed.connect(_dismiss_intro)
	v.add_child(start_btn)


func _build_result_modal() -> void:
	_result_overlay = ColorRect.new()
	_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.color = Color(0.03, 0.02, 0.015, 0.72)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_overlay.visible = false
	_root.add_child(_result_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)

	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(560, 0)
	_result_panel.add_theme_stylebox_override("panel", _make_pill_style(COL_CARD_BG, COL_GOLD, 18, 30, 26))
	center.add_child(_result_panel)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	_result_panel.add_child(v)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_result_title.add_theme_font_size_override("font_size", 32)
	v.add_child(_result_title)

	_result_score = Label.new()
	_result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_score.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_result_score.add_theme_font_size_override("font_size", 24)
	_result_score.add_theme_color_override("font_color", COL_CREAM)
	v.add_child(_result_score)

	_result_stats_row = HBoxContainer.new()
	_result_stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_stats_row.add_theme_constant_override("separation", 12)
	v.add_child(_result_stats_row)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	v.add_child(btn_row)

	_result_retry_btn = _make_secondary_button("Trace Again", Vector2(160, 46))
	_result_retry_btn.pressed.connect(func():
		_result_overlay.visible = false
		_canvas.clear_canvas()
		_canvas.input_enabled = true
	)
	btn_row.add_child(_result_retry_btn)

	_result_done_btn = Button.new()
	_result_done_btn.text = "Continue"
	Juice.style_primary_button(_result_done_btn, Vector2(175, 46))
	_result_done_btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_result_done_btn.pressed.connect(func():
		_close_minigame(bool(_last_result.get("won", false)), _last_result)
	)
	btn_row.add_child(_result_done_btn)


func _dismiss_intro() -> void:
	_intro_overlay.visible = false
	_canvas.input_enabled = true
	Juice.play_sfx("tab_switch", 1.12, -4.0)


# =============================================================================
# LEVEL LOADING & TOOL SELECTION
# =============================================================================

func _step_level(delta: int) -> void:
	if _locked_level:
		return
	var next := clampi(_current_level + delta, 1, _patterns.size())
	if next != _current_level:
		Juice.play_sfx("tab_switch", 1.05 if delta > 0 else 0.94, -5.0)
		_load_level(next)


func _load_level(lvl: int) -> void:
	_current_level = clampi(lvl, 1, _patterns.size())
	var pat: Dictionary = _patterns[_current_level - 1]
	_guide_polylines_norm = pat["strokes"]
	_current_brush_size_index = clampi(int(pat.get("brush_size_index", 1)), 0, 3)
	var first_col := _get_stroke_color_index(_guide_polylines_norm[0]) if not _guide_polylines_norm.is_empty() else 0
	_select_size(_current_brush_size_index)
	_select_ink_color(first_col)
	_rebuild_guide_mask(float(pat.get("grace_px", 6.5)))

	_title_label.text = "%s — %s" % [str(pat["roman"]), str(pat["name"])]
	_subtitle_label.text = str(pat["subtitle"])
	_stage_label.text = "Sigil %d / %d" % [_current_level, _patterns.size()]
	_target_badge_label.text = "Target: %d%%" % int(pat["required_accuracy"])

	_prev_stage_btn.visible = not _locked_level
	_next_stage_btn.visible = not _locked_level
	_prev_stage_btn.disabled = _current_level <= 1
	_next_stage_btn.disabled = _current_level >= _patterns.size()

	_canvas.setup_canvas(CANVAS_SIZE)
	_inscribe_btn.disabled = true
	_canvas.queue_redraw()


func _get_stroke_pts(stroke_entry) -> Array:
	if stroke_entry is Dictionary:
		return stroke_entry.get("pts", [])
	return stroke_entry


func _get_stroke_size_index(stroke_entry) -> int:
	if stroke_entry is Dictionary:
		return clampi(int(stroke_entry.get("size", _current_brush_size_index)), 0, 3)
	return _current_brush_size_index


func _get_stroke_color_index(stroke_entry) -> int:
	if stroke_entry is Dictionary:
		return clampi(int(stroke_entry.get("color", 0)), 0, INK_SWATCHES.size() - 1)
	return 0


func _rebuild_guide_mask(grace_px: float) -> void:
	# Exact raster mask matching CANVAS_SIZE (560x750):
	# _guide_mask: 0 = outside line, 1 = grace margin, 2 = core guide band
	# _guide_color_bits: 4-bit bitmask of allowed ink color indices (overlapping strokes set multiple bits!)
	var w := CANVAS_SIZE.x
	var h := CANVAS_SIZE.y
	_guide_mask = PackedByteArray()
	_guide_mask.resize(w * h)
	_guide_mask.fill(0)
	_guide_color_bits = PackedByteArray()
	_guide_color_bits.resize(w * h)
	_guide_color_bits.fill(0)

	for stroke_entry in _guide_polylines_norm:
		var stroke := _get_stroke_pts(stroke_entry)
		if stroke.size() < 2:
			continue
		var s_idx := _get_stroke_size_index(stroke_entry)
		var c_idx := _get_stroke_color_index(stroke_entry)
		var c_bit: int = 1 << c_idx
		var brush_r := CanvasDrawSurface.BRUSH_SIZES[s_idx]
		var core_r := maxf(3.0, brush_r * 0.78)
		var allow_r := brush_r + grace_px
		var core_r_sq := core_r * core_r
		var allow_r_sq := allow_r * allow_r
		var r_ceil := int(ceilf(allow_r))
		var step_px := maxf(1.5, core_r * 0.35)

		for i in range(stroke.size() - 1):
			var a := Vector2(stroke[i].x * float(w), stroke[i].y * float(h))
			var b := Vector2(stroke[i + 1].x * float(w), stroke[i + 1].y * float(h))
			var seg_len := a.distance_to(b)
			var steps := maxi(1, int(ceilf(seg_len / step_px)))
			for s in range(steps + 1):
				var pt := a.lerp(b, float(s) / float(steps))
				var cx := int(roundf(pt.x))
				var cy := int(roundf(pt.y))
				var x0 := maxi(0, cx - r_ceil)
				var x1 := mini(w - 1, cx + r_ceil)
				var y0 := maxi(0, cy - r_ceil)
				var y1 := mini(h - 1, cy + r_ceil)
				for py in range(y0, y1 + 1):
					var dy := float(py) - pt.y
					var dy_sq := dy * dy
					var row_off := py * w
					for px in range(x0, x1 + 1):
						var dx := float(px) - pt.x
						var d_sq := dx * dx + dy_sq
						if d_sq <= core_r_sq:
							_guide_mask[row_off + px] = 2
							_guide_color_bits[row_off + px] = _guide_color_bits[row_off + px] | c_bit
						elif d_sq <= allow_r_sq:
							if _guide_mask[row_off + px] == 0:
								_guide_mask[row_off + px] = 1
							_guide_color_bits[row_off + px] = _guide_color_bits[row_off + px] | c_bit

	_guide_core_pixels = 0
	for i in range(_guide_mask.size()):
		if _guide_mask[i] == 2:
			_guide_core_pixels += 1


func _get_active_swatches() -> Array[Dictionary]:
	return AccessibilityPaletteScript.get_talisman_swatches()


func _select_ink_color(idx: int) -> void:
	var swatches := _get_active_swatches()
	idx = clampi(idx, 0, swatches.size() - 1)
	_current_ink_index = idx
	_canvas.brush_color = swatches[idx]["color"]
	if _canvas.active_tool == CanvasDrawSurface.Tool.ERASER:
		_select_tool(CanvasDrawSurface.Tool.BRUSH)
	var cb_active: bool = AccessibilityPaletteScript.is_active()
	for i in range(_swatch_buttons.size()):
		var btn := _swatch_buttons[i]
		var sw: Dictionary = swatches[i]
		var col: Color = sw["color"]
		btn.tooltip_text = "%s [%d]" % [str(sw["name"]), i + 1]
		btn.text = str(sw.get("symbol", "")) if cb_active else ""
		if cb_active:
			var luma := col.r * 0.299 + col.g * 0.587 + col.b * 0.114
			btn.add_theme_color_override("font_color", Color(0.06, 0.05, 0.04, 1.0) if luma > 0.55 else Color(1.0, 0.98, 0.94, 1.0))
			btn.add_theme_font_size_override("font_size", 15)
		var st := StyleBoxFlat.new()
		st.bg_color = col
		st.set_corner_radius_all(18)
		if i == idx:
			st.border_color = Color(1.0, 0.94, 0.68, 1.0)
			st.set_border_width_all(3)
		else:
			st.border_color = Color(0.86, 0.67, 0.32, 0.45)
			st.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st)
		btn.add_theme_stylebox_override("pressed", st)


func _select_tool(tool: CanvasDrawSurface.Tool) -> void:
	_canvas.active_tool = tool
	_apply_toggle_button_style(_brush_btn, tool == CanvasDrawSurface.Tool.BRUSH)
	_apply_toggle_button_style(_eraser_btn, tool == CanvasDrawSurface.Tool.ERASER)


func _select_size(idx: int) -> void:
	_canvas.size_index = clampi(idx, 0, 3)
	for i in range(_size_buttons.size()):
		_apply_toggle_button_style(_size_buttons[i], i == _canvas.size_index)


func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	if is_instance_valid(_undo_btn):
		_undo_btn.disabled = not can_undo
	if is_instance_valid(_redo_btn):
		_redo_btn.disabled = not can_redo


func _on_stroke_updated() -> void:
	if is_instance_valid(_inscribe_btn):
		_inscribe_btn.disabled = not _canvas.has_any_ink()


# =============================================================================
# ROUNDED HOLLOW GUIDE RENDERER (Color-coded & brush-width matched, zero square caps!)
# =============================================================================

func _draw_talisman_guide(surface: CanvasDrawSurface, canvas_rect: Rect2) -> void:
	if _guide_polylines_norm.is_empty():
		return
	var screen_scale := canvas_rect.size.x / maxf(1.0, float(CANVAS_SIZE.x))
	var bead_spacing := 16.0

	for stroke_entry in _guide_polylines_norm:
		var stroke := _get_stroke_pts(stroke_entry)
		if stroke.size() < 2:
			continue
		var s_idx := _get_stroke_size_index(stroke_entry)
		var c_idx := _get_stroke_color_index(stroke_entry)
		var swatches := _get_active_swatches()
		var guide_col: Color = swatches[c_idx]["guide"]
		var brush_r := CanvasDrawSurface.BRUSH_SIZES[s_idx] * screen_scale
		var outer_w := clampf(brush_r * 1.92, 6.0, 34.0)
		var inner_w := maxf(2.0, outer_w - 4.2)

		var pts := PackedVector2Array()
		for norm_pt in stroke:
			pts.append(Vector2(
				canvas_rect.position.x + norm_pt.x * canvas_rect.size.x,
				canvas_rect.position.y + norm_pt.y * canvas_rect.size.y
			))

		# 1. Soft rounded outer brush band (rounded circles at every vertex/endpoint eliminate square corners!)
		var rim_col := Color(guide_col.r, guide_col.g, guide_col.b, 0.36)
		surface.draw_polyline(pts, rim_col, outer_w, true)
		for pt in pts:
			surface.draw_circle(pt, outer_w * 0.5, rim_col)

		# 2. Bright hollow interior wash so the exact brush diameter reads clearly as a rounded hollow tube
		var hollow_col := Color(0.96, 0.90, 0.74, 0.34)
		surface.draw_polyline(pts, hollow_col, inner_w, true)
		for pt in pts:
			surface.draw_circle(pt, inner_w * 0.5, hollow_col)

		# 3. Gliding rounded bead dots along the centerline in the stroke's ink color (never square dashes!)
		var bead_r := clampf(brush_r * 0.28, 2.0, 5.2)
		var bead_col := Color(guide_col.r, guide_col.g, guide_col.b, 0.86)
		var bead_halo := Color(1.0, 0.96, 0.84, 0.48)
		var dist_acc := -fmod(_dash_phase, bead_spacing)
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var seg_len := a.distance_to(b)
			if seg_len < 0.01:
				continue
			var dir := (b - a) / seg_len
			var pos := fposmod(-dist_acc, bead_spacing)
			while pos <= seg_len:
				var bp := a + dir * pos
				surface.draw_circle(bp, bead_r + 1.4, bead_halo)
				surface.draw_circle(bp, bead_r, bead_col)
				pos += bead_spacing
			dist_acc += seg_len

		# 4. Crisp color-coded start anchor ring at pts[0]
		var start_r := clampf(brush_r * 0.62, 5.5, 11.0)
		surface.draw_circle(pts[0], start_r + 1.5, Color(1.0, 0.95, 0.80, 0.75))
		surface.draw_circle(pts[0], start_r, Color(guide_col.r, guide_col.g, guide_col.b, 0.92))
		surface.draw_circle(pts[0], start_r * 0.42, Color(1.0, 0.97, 0.88, 0.92))


# =============================================================================
# ACCURACY EVALUATION ENGINE (Coverage + Overlap-Safe Color Match + Precision)
# =============================================================================

func _on_inscribe_pressed() -> void:
	if _is_evaluating or not _canvas.has_any_ink():
		return
	_is_evaluating = true
	_canvas.input_enabled = false

	var pat: Dictionary = _patterns[_current_level - 1]
	var eval := _evaluate_tracing()
	var accuracy_pct: int = int(eval["accuracy"])
	var coverage_pct: int = int(eval["coverage"])
	var color_pct: int = int(eval["color_match"])
	var precision_pct: int = int(eval["precision"])
	var stray_pct: int = int(eval["stray"])
	var target_pct: int = int(pat["required_accuracy"])
	var won: bool = accuracy_pct >= target_pct

	_best_accuracy_this_session = maxi(_best_accuracy_this_session, accuracy_pct)

	if won and is_instance_valid(StoryManager) and StoryManager.has_method("set_world_flag"):
		var cur_saved := int(StoryManager.get_world_flag("brahim_talisman_level", 1))
		if _current_level >= cur_saved and _current_level < _patterns.size():
			StoryManager.set_world_flag("brahim_talisman_level", _current_level + 1)

	_last_result = {
		"level": _current_level,
		"talisman_name": str(pat["name"]),
		"accuracy": accuracy_pct,
		"coverage": coverage_pct,
		"color_match": color_pct,
		"precision": precision_pct,
		"stray": stray_pct,
		"target": target_pct,
		"won": won,
	}

	var burst_origin := _stage_container.global_position + _stage_container.size * 0.5
	if won:
		Juice.play_win_fanfare(self)
		Juice.spawn_burst(_root, burst_origin, Color(1.0, 0.88, 0.45, 1.0), 22, 220.0)
	else:
		Juice.play_lose_sting(self)
		Juice.shake_control(_stage_container, 9.0, 0.25)

	_show_result_modal(won, pat, accuracy_pct, coverage_pct, color_pct, precision_pct, target_pct)
	_is_evaluating = false


func _nearest_swatch_index(r: float, g: float, b: float) -> int:
	var best_idx := 0
	var best_d := 999.0
	var swatches := _get_active_swatches()
	for i in range(swatches.size()):
		var c: Color = swatches[i]["color"]
		var dr := r - c.r
		var dg := g - c.g
		var db := b - c.b
		var d := dr * dr + dg * dg + db * db
		if d < best_d:
			best_d = d
			best_idx = i
	return best_idx


func _evaluate_tracing() -> Dictionary:
	var img := _canvas.get_raw_paint_image()
	if img == null or _guide_mask.is_empty() or _guide_core_pixels <= 0:
		return {"accuracy": 0, "coverage": 0, "color_match": 0, "precision": 0, "stray": 0}

	var bytes := img.get_data()
	var pixel_count := _guide_mask.size()
	if bytes.size() < pixel_count * 4:
		return {"accuracy": 0, "coverage": 0, "color_match": 0, "precision": 0, "stray": 0}

	var covered_core := 0
	var color_matched_core := 0
	var total_ink := 0
	var on_path_ink := 0

	for i in range(pixel_count):
		var a_byte := bytes[i * 4 + 3]
		if a_byte <= 35:
			continue
		total_ink += 1
		var m := _guide_mask[i]
		if m >= 1:
			on_path_ink += 1
		if m == 2:
			covered_core += 1
			var r := float(bytes[i * 4]) / 255.0
			var g := float(bytes[i * 4 + 1]) / 255.0
			var b := float(bytes[i * 4 + 2]) / 255.0
			var sw_idx := _nearest_swatch_index(r, g, b)
			if (_guide_color_bits[i] & (1 << sw_idx)) != 0:
				color_matched_core += 1

	if total_ink < 24:
		return {"accuracy": 0, "coverage": 0, "color_match": 0, "precision": 0, "stray": 0}

	var coverage := clampf(float(covered_core) / float(_guide_core_pixels), 0.0, 1.0)
	var color_ratio := clampf(float(color_matched_core) / float(maxi(1, covered_core)), 0.0, 1.0)
	var precision := clampf(float(on_path_ink) / float(total_ink), 0.0, 1.0)
	var stray_ratio := clampf(1.0 - precision, 0.0, 1.0)

	# Color-weighted effective coverage: right color = 100% credit, wrong color = 35% credit
	var eff_coverage := coverage * (0.35 + 0.65 * color_ratio)
	var f1 := (2.0 * eff_coverage * precision) / maxf(0.0001, eff_coverage + precision)
	var stray_penalty := maxf(0.0, stray_ratio - 0.04) * 0.42
	var combined := clampf(f1 - stray_penalty, 0.0, 1.0)

	return {
		"accuracy": int(roundf(combined * 100.0)),
		"coverage": int(roundf(coverage * 100.0)),
		"color_match": int(roundf(color_ratio * 100.0)),
		"precision": int(roundf(precision * 100.0)),
		"stray": int(roundf(stray_ratio * 100.0)),
	}


func _show_result_modal(won: bool, _pat: Dictionary, acc: int, cov: int, col_pct: int, prec: int, target: int) -> void:
	if won:
		_result_title.text = "Anting-Anting Empowered!"
		_result_title.add_theme_color_override("font_color", COL_SUCCESS)
		_result_retry_btn.visible = false
	else:
		_result_title.text = "Unsteady Inscription"
		_result_title.add_theme_color_override("font_color", COL_FAIL)
		_result_retry_btn.visible = true

	_result_score.text = "Accuracy: %d%%  (Target: %d%%)" % [acc, target]
	for ch in _result_stats_row.get_children():
		_result_stats_row.remove_child(ch)
		ch.queue_free()
	_result_stats_row.add_child(Juice.make_stat_chip("Coverage", "%d%%" % cov, Juice.COL_SUCCESS if cov >= 70 else Juice.COL_CREAM))
	_result_stats_row.add_child(Juice.make_stat_chip("Color Match", "%d%%" % col_pct, Juice.COL_GOLD_BRIGHT if col_pct >= 75 else Juice.COL_DANGER))
	_result_stats_row.add_child(Juice.make_stat_chip("Precision", "%d%%" % prec, Juice.COL_CREAM))

	_result_overlay.visible = true
	call_deferred("_pop_result_deferred")


func _pop_result_deferred() -> void:
	if is_instance_valid(_result_panel):
		Juice.pop_panel_in(_result_panel)


# =============================================================================
# 20 PROGRESSIVE MULTI-COLOR & MULTI-SIZE TALISMAN PUZZLES (English / Taglish)
# =============================================================================

func _pt(nx: float, ny: float) -> Vector2:
	return Vector2(SAFE_CENTER.x + nx * SAFE_RX, SAFE_CENTER.y + ny * SAFE_RY)


func _arc_pts(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, segs: int = 24) -> Array:
	var out: Array = []
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		var ang := lerpf(a0, a1, t)
		out.append(_pt(cx + cos(ang) * rx, cy + sin(ang) * ry))
	return out


func _circle_pts(cx: float, cy: float, rx: float, ry: float, segs: int = 32) -> Array:
	return _arc_pts(cx, cy, rx, ry, -PI * 0.5, PI * 1.5, segs)


func _poly_pts(verts: Array[Vector2], closed: bool = true) -> Array:
	var out: Array = []
	for v in verts:
		out.append(_pt(v.x, v.y))
	if closed and verts.size() > 0:
		out.append(_pt(verts[0].x, verts[0].y))
	return out


func _st(pts: Array, size_idx: int, color_idx: int = INK_CHARCOAL) -> Dictionary:
	return {"pts": pts, "size": size_idx, "color": color_idx}


func _build_talisman_patterns() -> Array[Dictionary]:
	var sets: Array[Dictionary] = []

	# 1. First Ward (Bold Charcoal + Medium Crimson)
	sets.append({
		"roman": "I",
		"name": "First Ward",
		"subtitle": "Bold Charcoal pillar & Medium Crimson crossbar.",
		"required_accuracy": 60,
		"brush_size_index": 2,
		"grace_px": 8.0,
		"strokes": [
			_st([_pt(0.0, -0.76), _pt(0.0, 0.76)], 2, INK_CHARCOAL),
			_st([_pt(-0.62, -0.10), _pt(0.62, -0.10)], 1, INK_CRIMSON),
		],
	})

	# 2. Moonlit Crescent (Bold Indigo crescent + Fine Gold star)
	sets.append({
		"roman": "II",
		"name": "Moonlit Crescent",
		"subtitle": "Bold Indigo crescent with a Fine Sacred Gold star.",
		"required_accuracy": 62,
		"brush_size_index": 2,
		"grace_px": 7.5,
		"strokes": [
			_st(_arc_pts(0.08, 0.0, 0.62, 0.68, deg_to_rad(52.0), deg_to_rad(308.0), 28), 2, INK_INDIGO),
			_st(_arc_pts(0.24, 0.0, 0.44, 0.54, deg_to_rad(68.0), deg_to_rad(292.0), 24), 1, INK_INDIGO),
			_st([_pt(0.32, -0.20), _pt(0.32, 0.20)], 0, INK_GOLD),
			_st([_pt(0.12, 0.0), _pt(0.52, 0.0)], 0, INK_GOLD),
		],
	})

	# 3. Morning Sun (Bold Gold core + Medium Crimson cardinal rays)
	sets.append({
		"roman": "III",
		"name": "Morning Sun",
		"subtitle": "Bold Sacred Gold sun & Medium Crimson rays.",
		"required_accuracy": 63,
		"brush_size_index": 2,
		"grace_px": 7.5,
		"strokes": [
			_st(_circle_pts(0.0, 0.0, 0.34, 0.32, 28), 2, INK_GOLD),
			_st([_pt(0.0, -0.44), _pt(0.0, -0.78)], 1, INK_CRIMSON),
			_st([_pt(0.0, 0.44), _pt(0.0, 0.78)], 1, INK_CRIMSON),
			_st([_pt(-0.44, 0.0), _pt(-0.76, 0.0)], 1, INK_CRIMSON),
			_st([_pt(0.44, 0.0), _pt(0.76, 0.0)], 1, INK_CRIMSON),
		],
	})

	# 4. Watcher's Eye (Medium Indigo almond + Bold Charcoal iris + Fine Gold lashes)
	sets.append({
		"roman": "IV",
		"name": "Watcher's Eye",
		"subtitle": "Medium Indigo eye, Bold Charcoal iris & Fine Gold lashes.",
		"required_accuracy": 65,
		"brush_size_index": 1,
		"grace_px": 7.0,
		"strokes": [
			_st(_arc_pts(0.0, 0.28, 0.78, 0.62, deg_to_rad(212.0), deg_to_rad(328.0), 24), 1, INK_INDIGO),
			_st(_arc_pts(0.0, -0.28, 0.78, 0.62, deg_to_rad(32.0), deg_to_rad(148.0), 24), 1, INK_INDIGO),
			_st(_circle_pts(0.0, 0.0, 0.22, 0.22, 24), 2, INK_CHARCOAL),
			_st([_pt(0.0, -0.64), _pt(0.0, -0.40)], 0, INK_GOLD),
			_st([_pt(0.0, 0.40), _pt(0.0, 0.64)], 0, INK_GOLD),
		],
	})

	# 5. Healing Triad (Bold Crimson triangle + Medium Gold ring + Fine Charcoal spark)
	sets.append({
		"roman": "V",
		"name": "Healing Triad",
		"subtitle": "Bold Crimson triangle, Medium Gold ring & Fine Charcoal bar.",
		"required_accuracy": 66,
		"brush_size_index": 2,
		"grace_px": 7.0,
		"strokes": [
			_st(_poly_pts([Vector2(0.0, -0.76), Vector2(0.72, 0.50), Vector2(-0.72, 0.50)], true), 2, INK_CRIMSON),
			_st(_circle_pts(0.0, 0.08, 0.24, 0.23, 24), 1, INK_GOLD),
			_st([_pt(-0.54, 0.74), _pt(0.54, 0.74)], 0, INK_CHARCOAL),
		],
	})

	# 6. Talisman Cross (Bold Charcoal cross + Medium Gold diamond + Fine Crimson accents)
	sets.append({
		"roman": "VI",
		"name": "Talisman Cross",
		"subtitle": "Bold Charcoal cross, Medium Gold diamond & Fine Crimson tips.",
		"required_accuracy": 68,
		"brush_size_index": 2,
		"grace_px": 6.8,
		"strokes": [
			_st([_pt(0.0, -0.76), _pt(0.0, 0.76)], 2, INK_CHARCOAL),
			_st([_pt(-0.60, -0.10), _pt(0.60, -0.10)], 2, INK_CHARCOAL),
			_st(_poly_pts([Vector2(0.0, -0.36), Vector2(0.26, -0.10), Vector2(0.0, 0.16), Vector2(-0.26, -0.10)], true), 1, INK_GOLD),
			_st([_pt(-0.16, -0.76), _pt(0.16, -0.76)], 0, INK_CRIMSON),
			_st([_pt(-0.16, 0.76), _pt(0.16, 0.76)], 0, INK_CRIMSON),
		],
	})

	# 7. Suki's Lantern (Medium Crimson diamond lantern + Bold Gold flame + Fine Indigo tassel)
	sets.append({
		"roman": "VII",
		"name": "Suki's Lantern",
		"subtitle": "Medium Crimson lantern, Bold Gold core & Fine Indigo tassel.",
		"required_accuracy": 69,
		"brush_size_index": 1,
		"grace_px": 6.5,
		"strokes": [
			_st(_poly_pts([Vector2(0.0, -0.68), Vector2(0.54, -0.08), Vector2(0.0, 0.44), Vector2(-0.54, -0.08)], true), 1, INK_CRIMSON),
			_st(_circle_pts(0.0, -0.10, 0.18, 0.18, 20), 2, INK_GOLD),
			_st([_pt(0.0, 0.44), _pt(0.0, 0.80)], 0, INK_INDIGO),
			_st([_pt(-0.24, -0.78), _pt(0.24, -0.78)], 1, INK_CHARCOAL),
		],
	})

	# 8. Sari-Sari Bell (Bold Gold dome + Medium Crimson rim + Fine Charcoal clapper)
	sets.append({
		"roman": "VIII",
		"name": "Sari-Sari Bell",
		"subtitle": "Bold Gold bell dome, Medium Crimson rim & Fine Charcoal clapper.",
		"required_accuracy": 70,
		"brush_size_index": 2,
		"grace_px": 6.5,
		"strokes": [
			_st(_arc_pts(0.0, 0.18, 0.56, 0.72, deg_to_rad(180.0), deg_to_rad(360.0), 26), 2, INK_GOLD),
			_st([_pt(-0.68, 0.24), _pt(0.68, 0.24)], 1, INK_CRIMSON),
			_st(_circle_pts(0.0, 0.48, 0.14, 0.14, 18), 0, INK_CHARCOAL),
			_st([_pt(0.0, -0.72), _pt(0.0, -0.54)], 1, INK_CHARCOAL),
		],
	})

	# 9. Twin Waves (Bold Indigo waves + Medium Gold horizon + Fine Crimson sun)
	sets.append({
		"roman": "IX",
		"name": "Twin Waves",
		"subtitle": "Bold Indigo sea arcs, Medium Gold horizon & Fine Crimson sun.",
		"required_accuracy": 71,
		"brush_size_index": 2,
		"grace_px": 6.5,
		"strokes": [
			_st(_arc_pts(-0.34, 0.36, 0.36, 0.24, deg_to_rad(180.0), deg_to_rad(360.0), 18), 2, INK_INDIGO),
			_st(_arc_pts(0.34, 0.36, 0.36, 0.24, deg_to_rad(0.0), deg_to_rad(180.0), 18), 2, INK_INDIGO),
			_st([_pt(-0.70, 0.04), _pt(0.70, 0.04)], 1, INK_GOLD),
			_st(_arc_pts(0.0, 0.02, 0.38, 0.36, deg_to_rad(180.0), deg_to_rad(360.0), 22), 0, INK_CRIMSON),
		],
	})

	# 10. Wind Shield (Bold Charcoal crest + Medium Indigo chevron + Fine Gold curls)
	sets.append({
		"roman": "X",
		"name": "Wind Shield",
		"subtitle": "Bold Charcoal crest, Medium Indigo chevron & Fine Gold curls.",
		"required_accuracy": 72,
		"brush_size_index": 2,
		"grace_px": 6.2,
		"strokes": [
			_st(_poly_pts([
				Vector2(-0.66, -0.66), Vector2(0.66, -0.66),
				Vector2(0.66, 0.08), Vector2(0.0, 0.80),
				Vector2(-0.66, 0.08),
			], true), 2, INK_CHARCOAL),
			_st([_pt(-0.42, -0.16), _pt(0.0, 0.26), _pt(0.42, -0.16)], 1, INK_INDIGO),
			_st(_arc_pts(-0.32, -0.44, 0.16, 0.14, deg_to_rad(180.0), deg_to_rad(420.0), 14), 0, INK_GOLD),
			_st(_arc_pts(0.32, -0.44, 0.16, 0.14, deg_to_rad(120.0), deg_to_rad(360.0), 14), 0, INK_GOLD),
		],
	})

	# 11. Guiding Compass (Medium Gold 4-point star + Bold Indigo ring + Fine Crimson ticks)
	sets.append({
		"roman": "XI",
		"name": "Guiding Compass",
		"subtitle": "Bold Indigo ring, Medium Gold star & Fine Crimson ticks.",
		"required_accuracy": 73,
		"brush_size_index": 1,
		"grace_px": 6.0,
		"strokes": [
			_st(_circle_pts(0.0, 0.0, 0.42, 0.40, 28), 2, INK_INDIGO),
			_st(_poly_pts([
				Vector2(0.0, -0.80), Vector2(0.16, -0.16),
				Vector2(0.74, 0.0), Vector2(0.16, 0.16),
				Vector2(0.0, 0.80), Vector2(-0.16, 0.16),
				Vector2(-0.74, 0.0), Vector2(-0.16, -0.16),
			], true), 1, INK_GOLD),
			_st([_pt(-0.56, -0.56), _pt(-0.36, -0.36)], 0, INK_CRIMSON),
			_st([_pt(0.56, -0.56), _pt(0.36, -0.36)], 0, INK_CRIMSON),
		],
	})

	# 12. Agimat Hourglass (Bold Charcoal glass + Medium Gold core + Fine Crimson caps)
	sets.append({
		"roman": "XII",
		"name": "Agimat Hourglass",
		"subtitle": "Bold Charcoal hourglass, Medium Gold core & Fine Crimson caps.",
		"required_accuracy": 74,
		"brush_size_index": 2,
		"grace_px": 6.0,
		"strokes": [
			_st(_poly_pts([Vector2(-0.58, -0.68), Vector2(0.58, -0.68), Vector2(-0.58, 0.68), Vector2(0.58, 0.68)], true), 2, INK_CHARCOAL),
			_st(_circle_pts(0.0, 0.0, 0.18, 0.18, 20), 1, INK_GOLD),
			_st([_pt(-0.68, -0.80), _pt(0.68, -0.80)], 0, INK_CRIMSON),
			_st([_pt(-0.68, 0.80), _pt(0.68, 0.80)], 0, INK_CRIMSON),
		],
	})

	# 13. Balete Roots (Bold Charcoal trunk + Medium Indigo canopy + Fine Gold roots & moon)
	sets.append({
		"roman": "XIII",
		"name": "Balete Roots",
		"subtitle": "Bold Charcoal trunk, Medium Indigo canopy & Fine Gold roots.",
		"required_accuracy": 75,
		"brush_size_index": 2,
		"grace_px": 5.8,
		"strokes": [
			_st([_pt(0.0, -0.22), _pt(0.0, 0.42)], 2, INK_CHARCOAL),
			_st(_arc_pts(0.0, -0.26, 0.62, 0.44, deg_to_rad(180.0), deg_to_rad(360.0), 24), 1, INK_INDIGO),
			_st([_pt(0.0, 0.42), _pt(-0.56, 0.76)], 0, INK_GOLD),
			_st([_pt(0.0, 0.42), _pt(0.56, 0.76)], 0, INK_GOLD),
			_st([_pt(0.0, 0.42), _pt(0.0, 0.80)], 0, INK_GOLD),
			_st(_circle_pts(0.0, -0.44, 0.14, 0.14, 18), 0, INK_CRIMSON),
		],
	})

	# 14. Flame of Biringan (Bold Crimson outer flame + Medium Gold inner flame + Fine Indigo ring)
	sets.append({
		"roman": "XIV",
		"name": "Flame of Biringan",
		"subtitle": "Bold Crimson flame, Medium Gold heart & Fine Indigo base.",
		"required_accuracy": 76,
		"brush_size_index": 2,
		"grace_px": 5.8,
		"strokes": [
			_st(_poly_pts([Vector2(0.0, -0.82), Vector2(0.58, 0.12), Vector2(0.32, 0.56), Vector2(-0.32, 0.56), Vector2(-0.58, 0.12)], true), 2, INK_CRIMSON),
			_st(_poly_pts([Vector2(0.0, -0.42), Vector2(0.28, 0.18), Vector2(0.0, 0.44), Vector2(-0.28, 0.18)], true), 1, INK_GOLD),
			_st([_pt(-0.56, 0.76), _pt(0.56, 0.76)], 0, INK_INDIGO),
		],
	})

	# 15. Interlaced Star (Medium Indigo ring + Fine Crimson up-tri + Fine Gold down-tri)
	sets.append({
		"roman": "XV",
		"name": "Interlaced Star",
		"subtitle": "Medium Indigo ring with Crimson & Sacred Gold interlaced triangles.",
		"required_accuracy": 77,
		"brush_size_index": 1,
		"grace_px": 5.5,
		"strokes": [
			_st(_circle_pts(0.0, 0.0, 0.74, 0.70, 36), 1, INK_INDIGO),
			_st(_poly_pts([Vector2(0.0, -0.64), Vector2(0.58, 0.34), Vector2(-0.58, 0.34)], true), 0, INK_CRIMSON),
			_st(_poly_pts([Vector2(0.0, 0.64), Vector2(0.58, -0.34), Vector2(-0.58, -0.34)], true), 0, INK_GOLD),
		],
	})

	# 16. Crown of Mayari (Bold Gold crescent + Medium Indigo halo + Fine Crimson jewels)
	sets.append({
		"roman": "XVI",
		"name": "Crown of Mayari",
		"subtitle": "Bold Gold crown, Medium Indigo halo & Fine Crimson jewels.",
		"required_accuracy": 78,
		"brush_size_index": 2,
		"grace_px": 5.5,
		"strokes": [
			_st(_poly_pts([
				Vector2(-0.64, 0.38), Vector2(-0.64, -0.26), Vector2(-0.28, 0.08),
				Vector2(0.0, -0.44), Vector2(0.28, 0.08), Vector2(0.64, -0.26), Vector2(0.64, 0.38),
			], true), 2, INK_GOLD),
			_st(_arc_pts(0.0, -0.20, 0.52, 0.48, deg_to_rad(195.0), deg_to_rad(345.0), 22), 1, INK_INDIGO),
			_st([_pt(-0.56, 0.62), _pt(0.56, 0.62)], 0, INK_CRIMSON),
			_st(_circle_pts(0.0, -0.64, 0.11, 0.11, 16), 0, INK_CRIMSON),
		],
	})

	# 17. Orasyon Scales (Bold Charcoal beam + Medium Gold pans + Fine Indigo ring)
	sets.append({
		"roman": "XVII",
		"name": "Orasyon Scales",
		"subtitle": "Bold Charcoal beam, Medium Gold pans & Fine Indigo fulcrum.",
		"required_accuracy": 79,
		"brush_size_index": 2,
		"grace_px": 5.5,
		"strokes": [
			_st([_pt(0.0, -0.66), _pt(0.0, 0.68)], 2, INK_CHARCOAL),
			_st([_pt(-0.68, -0.28), _pt(0.68, -0.28)], 2, INK_CHARCOAL),
			_st(_arc_pts(-0.56, 0.14, 0.22, 0.18, deg_to_rad(0.0), deg_to_rad(180.0), 16), 1, INK_GOLD),
			_st(_arc_pts(0.56, 0.14, 0.22, 0.18, deg_to_rad(0.0), deg_to_rad(180.0), 16), 1, INK_GOLD),
			_st(_circle_pts(0.0, -0.28, 0.16, 0.16, 18), 0, INK_INDIGO),
			_st([_pt(-0.38, 0.72), _pt(0.38, 0.72)], 1, INK_CRIMSON),
		],
	})

	# 18. Kapre's Ember (Bold Crimson diamond + Medium Charcoal wisps + Fine Gold sparks)
	sets.append({
		"roman": "XVIII",
		"name": "Kapre's Ember",
		"subtitle": "Bold Crimson ember, Medium Charcoal smoke & Fine Gold sparks.",
		"required_accuracy": 80,
		"brush_size_index": 2,
		"grace_px": 5.2,
		"strokes": [
			_st(_poly_pts([Vector2(0.0, -0.24), Vector2(0.46, 0.24), Vector2(0.0, 0.72), Vector2(-0.46, 0.24)], true), 2, INK_CRIMSON),
			_st(_arc_pts(-0.18, -0.44, 0.22, 0.26, deg_to_rad(90.0), deg_to_rad(270.0), 16), 1, INK_CHARCOAL),
			_st(_arc_pts(0.18, -0.58, 0.22, 0.24, deg_to_rad(-90.0), deg_to_rad(90.0), 16), 1, INK_CHARCOAL),
			_st([_pt(-0.58, -0.22), _pt(-0.38, -0.02)], 0, INK_GOLD),
			_st([_pt(0.58, -0.22), _pt(0.38, -0.02)], 0, INK_GOLD),
			_st(_circle_pts(0.0, 0.24, 0.16, 0.16, 18), 0, INK_GOLD),
		],
	})

	# 19. Midnight Seal (Medium Indigo twin rings + Bold Charcoal pillar + Fine Gold & Crimson wards)
	sets.append({
		"roman": "XIX",
		"name": "Midnight Seal",
		"subtitle": "Indigo twin rings, Charcoal pillar, Gold crescent & Crimson triad.",
		"required_accuracy": 81,
		"brush_size_index": 1,
		"grace_px": 5.0,
		"strokes": [
			_st(_circle_pts(0.0, 0.0, 0.76, 0.72, 36), 1, INK_INDIGO),
			_st(_circle_pts(0.0, 0.0, 0.48, 0.46, 30), 0, INK_INDIGO),
			_st([_pt(0.0, -0.72), _pt(0.0, 0.72)], 2, INK_CHARCOAL),
			_st(_arc_pts(0.0, -0.46, 0.24, 0.18, deg_to_rad(15.0), deg_to_rad(165.0), 16), 0, INK_GOLD),
			_st(_poly_pts([Vector2(0.0, 0.20), Vector2(0.26, 0.56), Vector2(-0.26, 0.56)], true), 0, INK_CRIMSON),
		],
	})

	# 20. Grand Agimat (All 4 inks & 3 brush sizes!)
	sets.append({
		"roman": "XX",
		"name": "Grand Agimat",
		"subtitle": "Master sigil • All four ritual inks & three brush thicknesses.",
		"required_accuracy": 83,
		"brush_size_index": 2,
		"grace_px": 4.8,
		"strokes": [
			_st(_poly_pts([Vector2(0.0, -0.84), Vector2(0.76, 0.0), Vector2(0.0, 0.84), Vector2(-0.76, 0.0)], true), 2, INK_CHARCOAL),
			_st(_circle_pts(0.0, 0.0, 0.50, 0.48, 34), 1, INK_INDIGO),
			_st(_poly_pts([Vector2(0.0, -0.36), Vector2(0.34, 0.26), Vector2(-0.34, 0.26)], true), 1, INK_CRIMSON),
			_st(_circle_pts(0.0, 0.04, 0.14, 0.14, 18), 0, INK_GOLD),
			_st([_pt(-0.62, -0.62), _pt(-0.38, -0.38)], 0, INK_GOLD),
			_st([_pt(0.62, -0.62), _pt(0.38, -0.38)], 0, INK_GOLD),
			_st([_pt(-0.62, 0.62), _pt(-0.38, 0.38)], 0, INK_GOLD),
			_st([_pt(0.62, 0.62), _pt(0.38, 0.38)], 0, INK_GOLD),
		],
	})

	return sets


# =============================================================================
# STYLE HELPERS
# =============================================================================

func _make_pill_style(bg: Color, border: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.content_margin_left = pad_x
	st.content_margin_right = pad_x
	st.content_margin_top = pad_y
	st.content_margin_bottom = pad_y
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	st.shadow_size = 12
	return st


func _make_vsep() -> VSeparator:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 28)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.86, 0.67, 0.32, 0.28)
	sep.add_theme_stylebox_override("separator", st)
	return sep


func _make_icon_text_button(label_text: String, min_sz: Vector2, font_sz: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	btn.add_theme_font_size_override("font_size", font_sz)
	_apply_toggle_button_style(btn, false)
	return btn


func _make_lucide_button(icon_path: String, fallback_text: String, min_sz: Vector2, tip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = min_sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = tip
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.expand_icon = false
	else:
		btn.text = fallback_text
		btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		btn.add_theme_font_size_override("font_size", 16)
	_apply_toggle_button_style(btn, false)
	return btn


func _make_secondary_button(label_text: String, min_sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	btn.add_theme_font_size_override("font_size", 19)
	var st := _make_pill_style(Color(0.18, 0.13, 0.09, 0.96), COL_GOLD_SOFT, 10, 16, 8)
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.26, 0.19, 0.13, 0.98)
	hov.border_color = COL_GOLD
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_color_override("font_color", COL_CREAM)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn


func _apply_toggle_button_style(btn: Button, active: bool) -> void:
	var bg := Color(0.36, 0.25, 0.11, 0.98) if active else Color(0.17, 0.12, 0.09, 0.94)
	var border := Color(0.96, 0.82, 0.44, 0.98) if active else Color(0.86, 0.67, 0.32, 0.32)
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2 if active else 1)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(6)
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.42, 0.30, 0.14, 0.98) if active else Color(0.24, 0.17, 0.12, 0.96)
	hov.border_color = COL_GOLD
	var dis := st.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.12, 0.09, 0.07, 0.55)
	dis.border_color = Color(0.86, 0.67, 0.32, 0.14)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0) if active else COL_CREAM)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.48, 0.40, 0.55))
	btn.add_theme_color_override("icon_normal_color", Color(1.0, 0.92, 0.70, 1.0) if active else COL_CREAM)
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_disabled_color", Color(0.55, 0.48, 0.40, 0.45))
