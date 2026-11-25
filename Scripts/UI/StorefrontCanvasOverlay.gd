class_name StorefrontCanvasOverlay
extends CanvasLayer

## Simplified Figma / Krita-style universal drawing studio for Storefront Customization
## (Lv. 1 Roof Signage & Lv. 2 Promo Poster).
## Almost the entire screen is the drafting canvas, with a sleek right-side inspector dock
## for Tools (Brush, Bucket, Eraser, Eyedropper, Text, Select), Color Wheel + RGB + Swatches,
## Selected Layer (Text/Sticker) controls, Unlocked Store Product Stickers, and Reset to Default.

signal closed(saved: bool)

const ColorWheelScript = preload("res://Scripts/UI/ColorWheelControl.gd")
const CanvasSurfaceScript = preload("res://Scripts/UI/CanvasDrawSurface.gd")

const SIGNAGE_CANVAS_SIZE := Vector2i(1024, 368)
const POSTER_CANVAS_SIZE := Vector2i(540, 780)

const BG_WORKSPACE := Color(0.055, 0.048, 0.042, 0.98)
const BG_BAR := Color(0.082, 0.072, 0.062, 0.98)
const BG_DOCK := Color(0.072, 0.064, 0.055, 0.98)
const CARD_DARK := Color(0.115, 0.100, 0.086, 0.96)
const GOLD_ACCENT := Color(0.835, 0.624, 0.278, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const GOLD_TEXT := Color(0.98, 0.86, 0.58, 1.0)
const WHITE_HDR := Color(0.98, 0.97, 0.94, 1.0)
const MUTED_TEXT := Color(0.76, 0.69, 0.58, 0.88)

const BASIC_SWATCHES: Array[Color] = [
	Color(0.10, 0.09, 0.08, 1.0),
	Color(1.00, 1.00, 1.00, 1.0),
	Color(0.84, 0.18, 0.16, 1.0),
	Color(0.95, 0.52, 0.14, 1.0),
	Color(0.98, 0.82, 0.20, 1.0),
	Color(0.24, 0.68, 0.30, 1.0),
	Color(0.14, 0.62, 0.78, 1.0),
	Color(0.18, 0.36, 0.82, 1.0),
	Color(0.54, 0.24, 0.76, 1.0),
	Color(0.90, 0.34, 0.60, 1.0),
	Color(0.48, 0.28, 0.14, 1.0),
	Color(0.98, 0.91, 0.78, 1.0),
]

var _slot_name: String = "signage"
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _active_color: Color = Color(0.84, 0.18, 0.16, 1.0)
var _recent_colors: Array[String] = []
var _syncing_color: bool = false
var _selected_sticker_category: String = "all"
var _bold_font: FontVariation

var _surface: CanvasDrawSurface
var _wheel: Control
var _title_lbl: Label
var _tool_buttons: Dictionary = {} # Tool enum -> Button
var _brush_section: VBoxContainer
var _size_slider: HSlider
var _size_value_lbl: Label
var _undo_btn: Button
var _redo_btn: Button
var _zoom_reset_btn: Button
var _upload_dialog: FileDialog = null
var _reset_default_btn: Button
var _layers_list_vbox: VBoxContainer
var _layers_count_lbl: Label

var _color_preview: ColorRect
var _hex_label: Label
var _val_slider: HSlider
var _r_slider: HSlider
var _g_slider: HSlider
var _b_slider: HSlider
var _r_spin: SpinBox
var _g_spin: SpinBox
var _b_spin: SpinBox
var _recent_grid: GridContainer

# Contextual Selected Layer Inspector (Text or Sticker)
var _layer_box: PanelContainer
var _layer_title_lbl: Label
var _text_edit_row: VBoxContainer
var _text_input: LineEdit
var _text_bold_btn: Button
var _layer_hint_lbl: Label

# Stickers & Poster Promo Tracker
var _cat_tabs_row: HFlowContainer
var _sticker_grid: GridContainer
var _promo_banner: PanelContainer
var _promo_lbl: Label
var _cat_hud_panel: PanelContainer
var _cat_hud_vbox: VBoxContainer

# Save confirmation & Multi-category tie-breaker modal
var _featured_modal: ColorRect = null
var _featured_modal_list: VBoxContainer = null


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("storefront_canvas_active")
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65


func open_editor(slot_name: String) -> void:
	_slot_name = "poster" if slot_name == "poster" else "signage"
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_recent_colors.clear()
	for c in StoryManager.custom_recent_colors:
		_recent_colors.append(str(c))

	_build_ui()

	var target_sz := POSTER_CANVAS_SIZE if _slot_name == "poster" else SIGNAGE_CANVAS_SIZE
	var paint_path := StoryManager.POSTER_PAINT_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_PAINT_PATH
	var fallback_path := StoryManager.POSTER_IMAGE_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_IMAGE_PATH
	var saved_stickers: Array = StoryManager.custom_poster_stickers if _slot_name == "poster" else StoryManager.custom_signage_stickers

	var loaded_img: Image = null
	if FileAccess.file_exists(paint_path):
		loaded_img = Image.load_from_file(paint_path)
	elif FileAccess.file_exists(fallback_path):
		loaded_img = Image.load_from_file(fallback_path)

	_surface.setup_canvas(target_sz, loaded_img, saved_stickers)
	_set_active_color(_active_color, true)
	_select_tool(CanvasDrawSurface.Tool.BRUSH)
	_refresh_recent_swatches()
	_refresh_sticker_palette()
	_refresh_promo_status()
	_refresh_selected_layer_ui(-1)
	_refresh_layers_panel()
	_on_zoom_changed(_surface.get_zoom())
	_refresh_reset_button_state()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Full-screen dark Figma/Krita workspace
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_WORKSPACE
	root.add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	root.add_child(main_vbox)

	# ── 1. SLIM FULL-WIDTH TOP TOOLBAR (48px) ──
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 50)
	var tb_st := UIStyle.create_flat_stylebox(BG_BAR, 0, 14, 6)
	tb_st.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.55)
	tb_st.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", tb_st)
	main_vbox.add_child(top_bar)

	var tb_row := HBoxContainer.new()
	tb_row.add_theme_constant_override("separation", 8)
	top_bar.add_child(tb_row)

	_title_lbl = Label.new()
	_title_lbl.text = "Promo Poster Studio" if _slot_name == "poster" else "Roof Signage Studio"
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", WHITE_HDR)
	tb_row.add_child(_title_lbl)

	var sep_dot := Label.new()
	sep_dot.text = "·"
	sep_dot.add_theme_font_size_override("font_size", 18)
	sep_dot.add_theme_color_override("font_color", GOLD_ACCENT)
	tb_row.add_child(sep_dot)

	_undo_btn = _make_bar_btn("↶ Undo", CARD_DARK, GOLD_TEXT)
	_undo_btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _surface.undo())
	tb_row.add_child(_undo_btn)

	_redo_btn = _make_bar_btn("↷ Redo", CARD_DARK, GOLD_TEXT)
	_redo_btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _surface.redo())
	tb_row.add_child(_redo_btn)

	var zoom_sep := Label.new()
	zoom_sep.text = "·"
	zoom_sep.add_theme_font_size_override("font_size", 18)
	zoom_sep.add_theme_color_override("font_color", GOLD_ACCENT)
	tb_row.add_child(zoom_sep)

	var zoom_out_btn := _make_bar_btn("−", CARD_DARK, GOLD_TEXT)
	zoom_out_btn.custom_minimum_size = Vector2(32, 32)
	zoom_out_btn.tooltip_text = "Zoom Out (Ctrl+- or Scroll)"
	zoom_out_btn.pressed.connect(func(): _surface.zoom_by(1.0 / 1.2))
	tb_row.add_child(zoom_out_btn)

	_zoom_reset_btn = _make_bar_btn("100%", CARD_DARK, WHITE_HDR)
	_zoom_reset_btn.custom_minimum_size = Vector2(58, 32)
	_zoom_reset_btn.tooltip_text = "Reset Zoom & Pan (Ctrl+0) · Space+Drag or Middle-Mouse to pan"
	_zoom_reset_btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _surface.reset_view())
	tb_row.add_child(_zoom_reset_btn)

	var zoom_in_btn := _make_bar_btn("+", CARD_DARK, GOLD_TEXT)
	zoom_in_btn.custom_minimum_size = Vector2(32, 32)
	zoom_in_btn.tooltip_text = "Zoom In (Ctrl++ or Scroll)"
	zoom_in_btn.pressed.connect(func(): _surface.zoom_by(1.2))
	tb_row.add_child(zoom_in_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_row.add_child(spacer)

	var upload_btn := _make_bar_btn("+ Upload Image", Color(0.18, 0.22, 0.28, 0.96), Color(0.86, 0.94, 1.0, 1.0))
	upload_btn.tooltip_text = "Import a PNG, JPG, or WEBP image from your computer as a movable layer"
	upload_btn.pressed.connect(_on_upload_image_pressed)
	tb_row.add_child(upload_btn)

	_reset_default_btn = _make_bar_btn("Reset to Default", Color(0.24, 0.17, 0.10, 0.95), GOLD_BRIGHT)
	_reset_default_btn.tooltip_text = "Remove custom art and restore the default storefront look"
	_reset_default_btn.pressed.connect(_on_reset_to_default_pressed)
	tb_row.add_child(_reset_default_btn)

	var clear_btn := _make_bar_btn("Clear", Color(0.28, 0.14, 0.13, 0.95), Color(1.0, 0.88, 0.86, 1.0))
	clear_btn.pressed.connect(func(): AudioManager.play_sfx("drop"); _surface.clear_canvas())
	tb_row.add_child(clear_btn)

	var cancel_btn := _make_bar_btn("Cancel", CARD_DARK, MUTED_TEXT)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	tb_row.add_child(cancel_btn)

	var save_btn := _make_bar_btn("Save & Mount", Color(0.76, 0.56, 0.22, 1.0), Color(0.08, 0.06, 0.04, 1.0))
	save_btn.custom_minimum_size = Vector2(132, 34)
	save_btn.pressed.connect(_on_save_pressed)
	tb_row.add_child(save_btn)

	# ── 2. MAIN WORKSPACE: EXPANSIVE CANVAS (~80%) + RIGHT INSPECTOR DOCK (310px) ──
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 0)
	main_vbox.add_child(split)

	# Left / Center: Almost the entire screen IS the canvas!
	var canvas_wrap := Control.new()
	canvas_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(canvas_wrap)

	_surface = CanvasSurfaceScript.new()
	_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_surface.stroke_committed.connect(_on_stroke_committed)
	_surface.eyedropper_picked.connect(_on_eyedropper_picked)
	_surface.stickers_changed.connect(_on_stickers_changed)
	_surface.sticker_selection_changed.connect(_refresh_selected_layer_ui)
	_surface.text_layer_placed.connect(_on_text_layer_placed)
	_surface.history_changed.connect(_on_history_changed)
	_surface.zoom_changed.connect(_on_zoom_changed)
	canvas_wrap.add_child(_surface)

	# Bottom-left floating Category Sticker Progress HUD (overlaid cleanly on canvas corner)
	_cat_hud_panel = PanelContainer.new()
	_cat_hud_panel.anchor_left = 0.0
	_cat_hud_panel.anchor_right = 0.0
	_cat_hud_panel.anchor_top = 1.0
	_cat_hud_panel.anchor_bottom = 1.0
	_cat_hud_panel.offset_left = 16.0
	_cat_hud_panel.offset_bottom = -16.0
	_cat_hud_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cat_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch_st := UIStyle.create_flat_stylebox(Color(0.068, 0.058, 0.050, 0.92), 8, 12, 8)
	ch_st.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.72)
	ch_st.set_border_width_all(1)
	_cat_hud_panel.add_theme_stylebox_override("panel", ch_st)
	canvas_wrap.add_child(_cat_hud_panel)

	_cat_hud_vbox = VBoxContainer.new()
	_cat_hud_vbox.add_theme_constant_override("separation", 3)
	_cat_hud_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cat_hud_panel.add_child(_cat_hud_vbox)

	# Right Dock: Figma / Krita compact inspector panel
	var dock := PanelContainer.new()
	dock.custom_minimum_size = Vector2(316, 0)
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dk_st := UIStyle.create_flat_stylebox(BG_DOCK, 0, 12, 10)
	dk_st.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.45)
	dk_st.border_width_left = 2
	dock.add_theme_stylebox_override("panel", dk_st)
	split.add_child(dock)

	var dock_scroll := ScrollContainer.new()
	dock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dock.add_child(dock_scroll)

	var dock_v := VBoxContainer.new()
	dock_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_v.add_theme_constant_override("separation", 10)
	dock_scroll.add_child(dock_v)

	# ── DOCK SECTION A: TOOLS ──
	dock_v.add_child(_make_dock_hdr("Tools"))
	var tool_grid := GridContainer.new()
	tool_grid.columns = 3
	tool_grid.add_theme_constant_override("h_separation", 6)
	tool_grid.add_theme_constant_override("v_separation", 6)
	dock_v.add_child(tool_grid)

	var tool_defs: Array[Array] = [
		[CanvasDrawSurface.Tool.BRUSH, "Brush", "B"],
		[CanvasDrawSurface.Tool.BUCKET, "Fill", "G"],
		[CanvasDrawSurface.Tool.ERASER, "Eraser", "E"],
		[CanvasDrawSurface.Tool.EYEDROPPER, "Pick", "I"],
		[CanvasDrawSurface.Tool.TEXT, "Text", "T"],
		[CanvasDrawSurface.Tool.SELECT, "Move", "V"],
	]
	for td in tool_defs:
		var t_enum: int = td[0]
		var btn := Button.new()
		btn.text = "%s (%s)" % [str(td[1]), str(td[2])]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _select_tool(t_enum))
		tool_grid.add_child(btn)
		_tool_buttons[t_enum] = btn

	# Brush Size Row
	_brush_section = VBoxContainer.new()
	_brush_section.add_theme_constant_override("separation", 2)
	dock_v.add_child(_brush_section)

	var sz_row := HBoxContainer.new()
	_brush_section.add_child(sz_row)
	var sz_lbl := Label.new()
	sz_lbl.text = "Brush Size"
	sz_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sz_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	sz_lbl.add_theme_font_size_override("font_size", 13)
	sz_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	sz_row.add_child(sz_lbl)

	_size_value_lbl = Label.new()
	_size_value_lbl.text = "12 px"
	_size_value_lbl.add_theme_font_override("font", _bold_font)
	_size_value_lbl.add_theme_font_size_override("font_size", 13)
	_size_value_lbl.add_theme_color_override("font_color", WHITE_HDR)
	sz_row.add_child(_size_value_lbl)

	_size_slider = HSlider.new()
	_size_slider.min_value = 2.0
	_size_slider.max_value = 48.0
	_size_slider.step = 1.0
	_size_slider.value = 12.0
	_size_slider.focus_mode = Control.FOCUS_NONE
	_size_slider.value_changed.connect(func(v: float):
		_surface.brush_radius = v
		_size_value_lbl.text = "%d px" % int(v)
	)
	_brush_section.add_child(_size_slider)

	# ── DOCK SECTION B: CONTEXTUAL SELECTED LAYER (TEXT / STICKER) ──
	_layer_box = PanelContainer.new()
	var lb_st := UIStyle.create_flat_stylebox(CARD_DARK, 8, 10, 8)
	lb_st.border_color = GOLD_ACCENT
	lb_st.set_border_width_all(1)
	_layer_box.add_theme_stylebox_override("panel", lb_st)
	_layer_box.visible = false
	dock_v.add_child(_layer_box)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	_layer_box.add_child(lv)

	var lhdr_row := HBoxContainer.new()
	lv.add_child(lhdr_row)
	_layer_title_lbl = Label.new()
	_layer_title_lbl.text = "Selected Item"
	_layer_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layer_title_lbl.add_theme_font_override("font", _bold_font)
	_layer_title_lbl.add_theme_font_size_override("font_size", 14)
	_layer_title_lbl.add_theme_color_override("font_color", WHITE_HDR)
	lhdr_row.add_child(_layer_title_lbl)

	var del_layer_btn := _make_bar_btn("Delete", Color(0.58, 0.18, 0.16, 0.95), Color.WHITE)
	del_layer_btn.custom_minimum_size = Vector2(64, 26)
	del_layer_btn.pressed.connect(func(): AudioManager.play_sfx("drop"); _surface.delete_selected_sticker())
	lhdr_row.add_child(del_layer_btn)

	_text_edit_row = VBoxContainer.new()
	_text_edit_row.add_theme_constant_override("separation", 6)
	lv.add_child(_text_edit_row)

	_text_input = LineEdit.new()
	_text_input.placeholder_text = "Type storefront text..."
	_text_input.add_theme_font_override("font", UIStyle.FONT_INDER)
	_text_input.add_theme_font_size_override("font_size", 15)
	_text_input.text_changed.connect(func(nt: String): _surface.update_selected_text(nt))
	_text_edit_row.add_child(_text_input)

	var t_opts := HBoxContainer.new()
	t_opts.add_theme_constant_override("separation", 6)
	_text_edit_row.add_child(t_opts)

	_text_bold_btn = _make_bar_btn("Bold: On", CARD_DARK, GOLD_BRIGHT)
	_text_bold_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_bold_btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_surface.toggle_selected_text_bold()
		_refresh_selected_layer_ui(_surface._selected_sticker)
	)
	t_opts.add_child(_text_bold_btn)

	var t_col_btn := _make_bar_btn("Use Color", CARD_DARK, GOLD_BRIGHT)
	t_col_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_col_btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_surface.update_selected_text_color(_active_color)
	)
	t_opts.add_child(t_col_btn)

	_layer_hint_lbl = Label.new()
	_layer_hint_lbl.text = "Drag corners to scale · Drag ↻ corner to rotate (Shift snaps 15°)"
	_layer_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layer_hint_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_layer_hint_lbl.add_theme_font_size_override("font_size", 12)
	_layer_hint_lbl.add_theme_color_override("font_color", MUTED_TEXT)
	lv.add_child(_layer_hint_lbl)

	# ── DOCK SECTION B2: LAYERS STACK ──
	var layers_hdr_row := HBoxContainer.new()
	dock_v.add_child(layers_hdr_row)
	var layers_hdr := _make_dock_hdr("Layers")
	layers_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layers_hdr_row.add_child(layers_hdr)
	_layers_count_lbl = Label.new()
	_layers_count_lbl.text = "Base only"
	_layers_count_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_layers_count_lbl.add_theme_font_size_override("font_size", 11)
	_layers_count_lbl.add_theme_color_override("font_color", MUTED_TEXT)
	layers_hdr_row.add_child(_layers_count_lbl)

	var layers_panel := PanelContainer.new()
	var lp_st := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.045, 0.95), 6, 6, 6)
	lp_st.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.35)
	lp_st.set_border_width_all(1)
	layers_panel.add_theme_stylebox_override("panel", lp_st)
	dock_v.add_child(layers_panel)

	var layers_scroll := ScrollContainer.new()
	layers_scroll.custom_minimum_size = Vector2(0, 118)
	layers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layers_panel.add_child(layers_scroll)

	_layers_list_vbox = VBoxContainer.new()
	_layers_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layers_list_vbox.add_theme_constant_override("separation", 4)
	layers_scroll.add_child(_layers_list_vbox)

	# ── DOCK SECTION C: COLOR PICKER ──
	dock_v.add_child(_make_dock_hdr("Color"))

	var color_top := HBoxContainer.new()
	color_top.add_theme_constant_override("separation", 10)
	dock_v.add_child(color_top)

	_wheel = ColorWheelScript.new()
	_wheel.custom_minimum_size = Vector2(126, 126)
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wheel.color_changed.connect(func(c: Color):
		if not _syncing_color:
			_set_active_color(c, false)
	)
	color_top.add_child(_wheel)

	var col_right := VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 4)
	color_top.add_child(col_right)

	var prev_row := HBoxContainer.new()
	prev_row.add_theme_constant_override("separation", 6)
	col_right.add_child(prev_row)
	_color_preview = ColorRect.new()
	_color_preview.custom_minimum_size = Vector2(36, 24)
	_color_preview.color = _active_color
	prev_row.add_child(_color_preview)

	_hex_label = Label.new()
	_hex_label.text = "#D62E29"
	_hex_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hex_label.add_theme_font_override("font", _bold_font)
	_hex_label.add_theme_font_size_override("font_size", 13)
	_hex_label.add_theme_color_override("font_color", WHITE_HDR)
	prev_row.add_child(_hex_label)

	var val_lbl := Label.new()
	val_lbl.text = "Brightness"
	val_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", MUTED_TEXT)
	col_right.add_child(val_lbl)

	_val_slider = HSlider.new()
	_val_slider.min_value = 0.0
	_val_slider.max_value = 1.0
	_val_slider.step = 0.01
	_val_slider.value = 1.0
	_val_slider.focus_mode = Control.FOCUS_NONE
	_val_slider.value_changed.connect(func(v: float):
		if not _syncing_color:
			_wheel.set_value_silent(v)
			_set_active_color(_wheel.get_color(), false)
	)
	col_right.add_child(_val_slider)

	var r_pair := _make_rgb_row("R", Color(1.0, 0.48, 0.45, 1.0))
	_r_slider = r_pair[0]; _r_spin = r_pair[1]; col_right.add_child(r_pair[2])
	var g_pair := _make_rgb_row("G", Color(0.55, 0.92, 0.56, 1.0))
	_g_slider = g_pair[0]; _g_spin = g_pair[1]; col_right.add_child(g_pair[2])
	var b_pair := _make_rgb_row("B", Color(0.52, 0.78, 1.0, 1.0))
	_b_slider = b_pair[0]; _b_spin = b_pair[1]; col_right.add_child(b_pair[2])

	# Basic Swatches (6x2)
	var basic_grid := GridContainer.new()
	basic_grid.columns = 6
	basic_grid.add_theme_constant_override("h_separation", 4)
	basic_grid.add_theme_constant_override("v_separation", 4)
	dock_v.add_child(basic_grid)
	for sw in BASIC_SWATCHES:
		basic_grid.add_child(_make_swatch_btn(sw))

	var rec_lbl := Label.new()
	rec_lbl.text = "Recent Colors"
	rec_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	rec_lbl.add_theme_font_size_override("font_size", 11)
	rec_lbl.add_theme_color_override("font_color", MUTED_TEXT)
	dock_v.add_child(rec_lbl)

	_recent_grid = GridContainer.new()
	_recent_grid.columns = 6
	_recent_grid.add_theme_constant_override("h_separation", 4)
	_recent_grid.add_theme_constant_override("v_separation", 4)
	dock_v.add_child(_recent_grid)

	# ── DOCK SECTION D: STORE PRODUCT STICKERS ──
	dock_v.add_child(_make_dock_hdr("Store Product Stickers"))

	_promo_banner = PanelContainer.new()
	var pb_st := UIStyle.create_flat_stylebox(Color(0.14, 0.12, 0.08, 0.96), 6, 8, 6)
	pb_st.border_color = GOLD_ACCENT
	pb_st.set_border_width_all(1)
	_promo_banner.add_theme_stylebox_override("panel", pb_st)
	dock_v.add_child(_promo_banner)

	_promo_lbl = Label.new()
	_promo_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promo_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_promo_lbl.add_theme_font_size_override("font_size", 12)
	_promo_lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
	_promo_banner.add_child(_promo_lbl)

	_cat_tabs_row = HFlowContainer.new()
	_cat_tabs_row.add_theme_constant_override("h_separation", 4)
	_cat_tabs_row.add_theme_constant_override("v_separation", 4)
	dock_v.add_child(_cat_tabs_row)

	_sticker_grid = GridContainer.new()
	_sticker_grid.columns = 3
	_sticker_grid.add_theme_constant_override("h_separation", 6)
	_sticker_grid.add_theme_constant_override("v_separation", 6)
	dock_v.add_child(_sticker_grid)


func _make_dock_hdr(txt: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", WHITE_HDR)
	vb.add_child(lbl)
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.30)
	vb.add_child(sep)
	return vb


func _make_bar_btn(txt: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 34)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(btn, bg, fg, 13.0, 6)
	return btn


func _make_rgb_row(letter: String, col: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = letter
	lbl.custom_minimum_size = Vector2(14, 0)
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", col)
	row.add_child(lbl)

	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 255
	sl.step = 1
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	row.add_child(sl)

	var sp := SpinBox.new()
	sp.min_value = 0
	sp.max_value = 255
	sp.step = 1
	sp.custom_minimum_size = Vector2(54, 24)
	sp.focus_mode = Control.FOCUS_CLICK
	row.add_child(sp)

	sl.value_changed.connect(func(_v: float):
		if not _syncing_color:
			_on_rgb_sliders_changed()
	)
	sp.value_changed.connect(func(_v: float):
		if not _syncing_color:
			_on_rgb_spins_changed()
	)
	return [sl, sp, row]


func _make_swatch_btn(col: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(40, 24)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := UIStyle.create_flat_stylebox(col, 4, 0, 0)
	st.border_color = Color(0.85, 0.72, 0.45, 0.55)
	st.set_border_width_all(1)
	var hov: StyleBoxFlat = st.duplicate()
	hov.border_color = Color.WHITE
	hov.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_set_active_color(col, true)
	)
	return btn


func _select_tool(t: int) -> void:
	_surface.active_tool = t
	for k in _tool_buttons.keys():
		var btn: Button = _tool_buttons[k]
		var is_cur: bool = (int(k) == t)
		UIStyle.style_button(
			btn,
			GOLD_ACCENT if is_cur else CARD_DARK,
			Color(0.08, 0.06, 0.04, 1.0) if is_cur else GOLD_TEXT,
			13.0,
			6
		)
	if is_instance_valid(_brush_section):
		_brush_section.visible = (t == CanvasDrawSurface.Tool.BRUSH or t == CanvasDrawSurface.Tool.ERASER)


func _set_active_color(col: Color, push_to_wheel: bool) -> void:
	_active_color = Color(col.r, col.g, col.b, 1.0)
	_surface.brush_color = _active_color
	# Live-update selected text color if a text layer is currently selected
	var sel := _surface.get_selected_layer()
	if not sel.is_empty() and str(sel.get("kind", "sticker")) == "text":
		_surface.update_selected_text_color(_active_color)

	_syncing_color = true
	if is_instance_valid(_color_preview):
		_color_preview.color = _active_color
	if is_instance_valid(_hex_label):
		_hex_label.text = "#" + _active_color.to_html(false).to_upper()
	if is_instance_valid(_val_slider):
		_val_slider.value = _active_color.v
	var r255 := int(roundf(_active_color.r * 255.0))
	var g255 := int(roundf(_active_color.g * 255.0))
	var b255 := int(roundf(_active_color.b * 255.0))
	if is_instance_valid(_r_slider):
		_r_slider.value = r255; _r_spin.value = r255
		_g_slider.value = g255; _g_spin.value = g255
		_b_slider.value = b255; _b_spin.value = b255
	if push_to_wheel and is_instance_valid(_wheel):
		_wheel.set_color_silent(_active_color)
	_syncing_color = false


func _on_rgb_sliders_changed() -> void:
	_set_active_color(Color(_r_slider.value / 255.0, _g_slider.value / 255.0, _b_slider.value / 255.0, 1.0), true)


func _on_rgb_spins_changed() -> void:
	_set_active_color(Color(_r_spin.value / 255.0, _g_spin.value / 255.0, _b_spin.value / 255.0, 1.0), true)


func _on_stroke_committed(col: Color) -> void:
	var hex := "#" + Color(col.r, col.g, col.b, 1.0).to_html(false).to_upper()
	if _recent_colors.has(hex):
		_recent_colors.erase(hex)
	_recent_colors.push_front(hex)
	if _recent_colors.size() > 12:
		_recent_colors.resize(12)
	_refresh_recent_swatches()


func _on_eyedropper_picked(col: Color) -> void:
	AudioManager.play_sfx("interact")
	_set_active_color(col, true)
	_select_tool(CanvasDrawSurface.Tool.BRUSH)


func _refresh_recent_swatches() -> void:
	if not is_instance_valid(_recent_grid):
		return
	for ch in _recent_grid.get_children():
		ch.queue_free()
	for hex in _recent_colors:
		_recent_grid.add_child(_make_swatch_btn(Color.html(hex)))


func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	if is_instance_valid(_undo_btn):
		_undo_btn.disabled = not can_undo
	if is_instance_valid(_redo_btn):
		_redo_btn.disabled = not can_redo


func _on_stickers_changed() -> void:
	_refresh_promo_status()
	_refresh_layers_panel()


func _on_zoom_changed(new_zoom: float) -> void:
	if is_instance_valid(_zoom_reset_btn):
		_zoom_reset_btn.text = "%d%%" % int(roundf(new_zoom * 100.0))


func _on_upload_image_pressed() -> void:
	AudioManager.play_sfx("interact")
	if is_instance_valid(_upload_dialog):
		_upload_dialog.queue_free()
	_upload_dialog = FileDialog.new()
	_upload_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_upload_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_upload_dialog.use_native_dialog = true
	_upload_dialog.title = "Upload Storefront Image"
	_upload_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files"])
	_upload_dialog.file_selected.connect(func(path: String):
		if _surface.add_uploaded_image(path):
			AudioManager.play_sfx("purchase")
			_select_tool(CanvasDrawSurface.Tool.SELECT)
			EventBus.show_notification.emit("Image Imported", "Added '%s' as a movable layer!" % path.get_file(), "interact")
		else:
			AudioManager.play_sfx("error")
			EventBus.show_notification.emit("Import Failed", "Could not load that image file.", "error")
	)
	add_child(_upload_dialog)
	_upload_dialog.popup_centered_ratio(0.65)


func _refresh_layers_panel() -> void:
	if not is_instance_valid(_layers_list_vbox):
		return
	for ch in _layers_list_vbox.get_children():
		ch.queue_free()

	var layers := _surface.get_layers()
	var sel_idx := _surface.get_selected_index()
	if is_instance_valid(_layers_count_lbl):
		_layers_count_lbl.text = "%d layer%s" % [layers.size(), "" if layers.size() == 1 else "s"] if not layers.is_empty() else "Base only"

	# Show top-most layer first (reverse array order, just like Figma / Krita)
	for i in range(layers.size() - 1, -1, -1):
		var s: Dictionary = layers[i]
		var kind := str(s.get("kind", "sticker"))
		var is_vis: bool = bool(s.get("visible", true))
		var is_sel: bool = (i == sel_idx)

		var row := PanelContainer.new()
		var r_bg := Color(0.24, 0.19, 0.11, 0.96) if is_sel else (CARD_DARK if is_vis else Color(0.08, 0.075, 0.07, 0.72))
		var rst := UIStyle.create_flat_stylebox(r_bg, 4, 5, 3)
		if is_sel:
			rst.border_color = GOLD_BRIGHT
			rst.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", rst)
		_layers_list_vbox.add_child(row)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 3)
		row.add_child(hb)

		var vis_btn := Button.new()
		vis_btn.text = "●" if is_vis else "○"
		vis_btn.custom_minimum_size = Vector2(22, 24)
		vis_btn.focus_mode = Control.FOCUS_NONE
		vis_btn.tooltip_text = "Hide Layer" if is_vis else "Show Layer"
		UIStyle.style_button(vis_btn, Color(0.14, 0.12, 0.10, 0.85), GOLD_BRIGHT if is_vis else MUTED_TEXT, 11.0, 3)
		vis_btn.pressed.connect(func():
			AudioManager.play_sfx("interact")
			_surface.toggle_layer_visible(i)
		)
		hb.add_child(vis_btn)

		var prefix := "[Txt] " if kind == "text" else ("[Img] " if kind == "image" else "[Stk] ")
		var raw_name := str(s.get("text", "Text")) if kind == "text" else (str(s.get("label", "Image")) if kind == "image" else str(s.get("item_name", "Sticker")))
		var name_btn := Button.new()
		name_btn.text = prefix + raw_name
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.clip_text = true
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.custom_minimum_size = Vector2(0, 24)
		name_btn.focus_mode = Control.FOCUS_NONE
		UIStyle.style_button(name_btn, Color(0, 0, 0, 0), WHITE_HDR if is_vis else MUTED_TEXT, 11.0, 3)
		name_btn.pressed.connect(func():
			AudioManager.play_sfx("interact")
			_surface.select_layer(i)
			_select_tool(CanvasDrawSurface.Tool.SELECT)
		)
		hb.add_child(name_btn)

		var up_btn := Button.new()
		up_btn.text = "↑"
		up_btn.custom_minimum_size = Vector2(22, 24)
		up_btn.focus_mode = Control.FOCUS_NONE
		up_btn.disabled = (i >= layers.size() - 1)
		up_btn.tooltip_text = "Bring Forward"
		UIStyle.style_button(up_btn, Color(0.14, 0.12, 0.10, 0.85), GOLD_TEXT, 11.0, 3)
		up_btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _surface.move_layer(i, 1))
		hb.add_child(up_btn)

		var dn_btn := Button.new()
		dn_btn.text = "↓"
		dn_btn.custom_minimum_size = Vector2(22, 24)
		dn_btn.focus_mode = Control.FOCUS_NONE
		dn_btn.disabled = (i <= 0)
		dn_btn.tooltip_text = "Send Backward"
		UIStyle.style_button(dn_btn, Color(0.14, 0.12, 0.10, 0.85), GOLD_TEXT, 11.0, 3)
		dn_btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _surface.move_layer(i, -1))
		hb.add_child(dn_btn)

		var rm_btn := Button.new()
		rm_btn.text = "×"
		rm_btn.custom_minimum_size = Vector2(22, 24)
		rm_btn.focus_mode = Control.FOCUS_NONE
		rm_btn.tooltip_text = "Delete Layer"
		UIStyle.style_button(rm_btn, Color(0.38, 0.13, 0.12, 0.90), Color.WHITE, 11.0, 3)
		rm_btn.pressed.connect(func(): AudioManager.play_sfx("drop"); _surface.delete_layer(i))
		hb.add_child(rm_btn)

	# Bottom base paint layer indicator
	var base_lbl := Label.new()
	base_lbl.text = "  Base · Paint Canvas"
	base_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	base_lbl.add_theme_font_size_override("font_size", 11)
	base_lbl.add_theme_color_override("font_color", MUTED_TEXT)
	_layers_list_vbox.add_child(base_lbl)


func _on_text_layer_placed(sel_idx: int) -> void:
	_refresh_selected_layer_ui(sel_idx)
	if is_instance_valid(_text_input):
		_text_input.grab_focus()
		_text_input.select_all()


func _refresh_selected_layer_ui(sel_idx: int) -> void:
	if not is_instance_valid(_layer_box):
		return
	if sel_idx < 0:
		_layer_box.visible = false
		_refresh_layers_panel()
		return
	var sel := _surface.get_selected_layer()
	if sel.is_empty():
		_layer_box.visible = false
		return
	_layer_box.visible = true
	var kind := str(sel.get("kind", "sticker"))
	var is_text := kind == "text"
	_text_edit_row.visible = is_text
	if is_text:
		_layer_title_lbl.text = "Selected Text"
		if _text_input.text != str(sel.get("text", "")):
			_text_input.text = str(sel.get("text", ""))
		_text_bold_btn.text = "Bold: On" if bool(sel.get("bold", true)) else "Bold: Off"
	elif kind == "image":
		_layer_title_lbl.text = str(sel.get("label", "Uploaded Image"))
	else:
		_layer_title_lbl.text = str(sel.get("item_name", "Selected Sticker"))
	_refresh_layers_panel()


func _refresh_reset_button_state() -> void:
	if not is_instance_valid(_reset_default_btn):
		return
	var has_custom := StoryManager.has_custom_poster if _slot_name == "poster" else StoryManager.has_custom_signage
	_reset_default_btn.disabled = not has_custom


func _refresh_sticker_palette() -> void:
	var unlocked: Array[ItemData] = []
	var cat_set: Dictionary = {}
	for item in InventoryManager.get_all_items():
		if item and item.can_be_sold and item.tier <= StoryManager.current_tier:
			unlocked.append(item)
			cat_set[item.category.to_lower()] = true

	if is_instance_valid(_cat_tabs_row):
		for ch in _cat_tabs_row.get_children():
			ch.queue_free()
		var cats: Array[String] = ["all"]
		for c in ["snack", "can", "bottle", "frozen", "candy", "sachet", "pack", "cigarette"]:
			if cat_set.has(c):
				cats.append(c)
		if _selected_sticker_category != "all" and not cat_set.has(_selected_sticker_category):
			_selected_sticker_category = "all"

		for c in cats:
			var tbtn := Button.new()
			tbtn.text = "All" if c == "all" else StoryManager.get_category_display_name(c)
			tbtn.focus_mode = Control.FOCUS_NONE
			var is_active: bool = (_selected_sticker_category == c)
			UIStyle.style_button(
				tbtn,
				GOLD_ACCENT if is_active else CARD_DARK,
				Color(0.10, 0.08, 0.06, 1.0) if is_active else GOLD_TEXT,
				11.0,
				4
			)
			tbtn.pressed.connect(func():
				AudioManager.play_sfx("interact")
				_selected_sticker_category = c
				_refresh_sticker_palette()
			)
			_cat_tabs_row.add_child(tbtn)

	if is_instance_valid(_sticker_grid):
		for ch in _sticker_grid.get_children():
			ch.queue_free()
		for item in unlocked:
			if _selected_sticker_category != "all" and item.category.to_lower() != _selected_sticker_category:
				continue
			_sticker_grid.add_child(_create_sticker_card(item))


func _create_sticker_card(item: ItemData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(88, 76)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "%s (%s)" % [item.item_name, StoryManager.get_category_display_name(item.category)]
	UIStyle.style_button(btn, CARD_DARK, GOLD_TEXT, 11.0, 6)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	if item.texture:
		var tr := TextureRect.new()
		tr.texture = item.texture
		tr.custom_minimum_size = Vector2(44, 44)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tr)

	var nl := Label.new()
	nl.text = item.item_name
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	nl.add_theme_font_override("font", UIStyle.FONT_INDER)
	nl.add_theme_font_size_override("font_size", 10)
	nl.add_theme_color_override("font_color", GOLD_TEXT)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)

	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_surface.add_sticker(item)
		_select_tool(CanvasDrawSurface.Tool.SELECT)
	)
	return btn


func _refresh_promo_status() -> void:
	var counts := _surface.get_sticker_category_counts()
	var qualifying: Array[String] = []
	for cat in counts.keys():
		if int(counts[cat]) >= 3:
			qualifying.append(str(cat))

	# 1. Right-dock Featured Category promo banner (both Signage & Poster)
	if is_instance_valid(_promo_lbl):
		if qualifying.size() == 1:
			var cname := StoryManager.get_category_display_name(qualifying[0])
			_promo_lbl.text = "✦ Featured Promo Ready: %s (+demand & +₱3 bonus!)" % cname
		elif qualifying.size() >= 2:
			_promo_lbl.text = "✦ %d categories reached 3/3! You'll pick 1 Featured Category on Save." % qualifying.size()
		else:
			_promo_lbl.text = "Place 3/3 stickers of one category to activate a Featured Category Promo!"

	# 2. Bottom-left canvas Category Sticker Counter HUD
	if not is_instance_valid(_cat_hud_panel) or not is_instance_valid(_cat_hud_vbox):
		return
	for ch in _cat_hud_vbox.get_children():
		ch.queue_free()

	var hdr := Label.new()
	hdr.text = "Promo Category Progress"
	hdr.add_theme_font_override("font", _bold_font)
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", GOLD_BRIGHT)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cat_hud_vbox.add_child(hdr)

	if counts.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "0/3 — Add 3 stickers of a category for Featured Promo"
		empty_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", MUTED_TEXT)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cat_hud_vbox.add_child(empty_lbl)
	else:
		var sorted_cats: Array[String] = []
		for c in counts.keys():
			sorted_cats.append(str(c))
		sorted_cats.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]))
		for cat in sorted_cats:
			var cnt: int = int(counts[cat])
			var cname := StoryManager.get_category_display_name(cat)
			var row_lbl := Label.new()
			var ready := cnt >= 3
			row_lbl.text = "%d/3 %s%s" % [cnt, cname, "  ✓ Featured Ready!" if ready else ""]
			row_lbl.add_theme_color_override("font_color", Color(0.56, 0.94, 0.58, 1.0) if ready else WHITE_HDR)
			row_lbl.add_theme_font_override("font", _bold_font if ready else UIStyle.FONT_INDER)
			row_lbl.add_theme_font_size_override("font_size", 13)
			row_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_cat_hud_vbox.add_child(row_lbl)


func _on_reset_to_default_pressed() -> void:
	AudioManager.play_sfx("drop")
	StoryManager.reset_storefront_artwork(_slot_name)
	if _slot_name == "signage":
		EventBus.show_notification.emit("Signage Reset", "Restored the default storefront signboard.", "interact")
	else:
		EventBus.show_notification.emit("Poster Removed", "Cleared your custom storefront poster.", "interact")
	_close_overlay(true)


func _on_save_pressed() -> void:
	var counts := _surface.get_sticker_category_counts()
	var qualifying: Array[String] = []
	for cat in counts.keys():
		if int(counts[cat]) >= 3:
			qualifying.append(str(cat))
	if qualifying.size() >= 2:
		_show_featured_category_modal(qualifying, counts)
		return
	var chosen := qualifying[0] if qualifying.size() == 1 else ""
	_show_save_confirm_modal(chosen, int(counts.get(chosen, 0)))


func _show_save_confirm_modal(chosen_cat: String, cat_count: int) -> void:
	if is_instance_valid(_featured_modal):
		_featured_modal.queue_free()

	_featured_modal = ColorRect.new()
	_featured_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_featured_modal.color = Color(0.02, 0.018, 0.015, 0.78)
	_featured_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_featured_modal)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -245
	card.offset_right = 245
	card.offset_top = -135
	card.offset_bottom = 135
	var st := UIStyle.create_flat_stylebox(BG_DOCK, 12, 22, 18)
	st.border_color = GOLD_BRIGHT
	st.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", st)
	_featured_modal.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", WHITE_HDR)
	vbox.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_font_override("font", UIStyle.FONT_INDER)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", GOLD_TEXT)
	vbox.add_child(body)

	if _slot_name == "poster":
		if chosen_cat != "":
			var cname := StoryManager.get_category_display_name(chosen_cat)
			title.text = "Mount Promo Poster?"
			body.text = "%s (%d/3) will be featured on your storefront — boosting customer demand and granting +₱3 bonus per cash sale.\n\nDo you confirm?" % [cname, cat_count]
		else:
			title.text = "Mount Poster Without Promo?"
			body.text = "No category has 3/3 stickers yet, so no Featured Category bonus will be active.\n\nMount this poster anyway?"
	else:
		var tip_pct := int(roundf(StoryManager.get_storefront_tip_chance() * 100.0))
		if chosen_cat != "":
			var cname := StoryManager.get_category_display_name(chosen_cat)
			title.text = "Mount Roof Signage?"
			body.text = "%s (%d/3) will be featured on your Roof Signage — boosting demand & granting +₱3 bonus per cash sale (plus +%d%% Appreciation Tips)!\n\nNote: Roof Signage can only be edited once per day. Do you confirm?" % [cname, cat_count, maxi(15, tip_pct)]
		else:
			title.text = "Mount Roof Signage?"
			body.text = "No category has 3/3 stickers yet, so no Featured Category bonus will be active (still grants +%d%% Appreciation Tips & relief).\n\nNote: Roof Signage can only be edited once per day. Do you confirm?" % maxi(15, tip_pct)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var no_btn := _make_bar_btn("No, Keep Editing", CARD_DARK, MUTED_TEXT)
	no_btn.custom_minimum_size = Vector2(150, 38)
	no_btn.pressed.connect(func():
		AudioManager.play_sfx("drop")
		_featured_modal.queue_free()
	)
	btn_row.add_child(no_btn)

	var yes_btn := _make_bar_btn("Yes, Save & Mount", Color(0.76, 0.56, 0.22, 1.0), Color(0.08, 0.06, 0.04, 1.0))
	yes_btn.custom_minimum_size = Vector2(165, 38)
	yes_btn.pressed.connect(func():
		_featured_modal.queue_free()
		_finalize_save(chosen_cat)
	)
	btn_row.add_child(yes_btn)


func _show_featured_category_modal(qualifying: Array[String], counts: Dictionary) -> void:
	if is_instance_valid(_featured_modal):
		_featured_modal.queue_free()

	_featured_modal = ColorRect.new()
	_featured_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_featured_modal.color = Color(0.02, 0.018, 0.015, 0.78)
	_featured_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_featured_modal)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -220
	card.offset_right = 220
	card.offset_top = -170
	card.offset_bottom = 170
	var st := UIStyle.create_flat_stylebox(BG_DOCK, 12, 20, 18)
	st.border_color = GOLD_BRIGHT
	st.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", st)
	_featured_modal.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "Choose Featured Category"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", WHITE_HDR)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Multiple categories have 3/3 stickers. Pick one to feature%s:" % (" (Roof Signage can only be edited once per day)" if _slot_name == "signage" else "")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", MUTED_TEXT)
	vbox.add_child(sub)

	_featured_modal_list = VBoxContainer.new()
	_featured_modal_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_featured_modal_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_featured_modal_list)

	for cat in qualifying:
		var pick_btn := Button.new()
		pick_btn.text = "%s (%d stickers)" % [StoryManager.get_category_display_name(cat), int(counts.get(cat, 3))]
		pick_btn.custom_minimum_size = Vector2(0, 42)
		pick_btn.focus_mode = Control.FOCUS_NONE
		UIStyle.style_button(pick_btn, CARD_DARK, GOLD_BRIGHT, 15.0, 8)
		pick_btn.pressed.connect(func():
			AudioManager.play_sfx("purchase")
			_featured_modal.queue_free()
			_finalize_save(cat)
		)
		_featured_modal_list.add_child(pick_btn)

	var back_btn := _make_bar_btn("Back to Edit", Color(0.28, 0.14, 0.13, 0.95), Color.WHITE)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("drop")
		_featured_modal.queue_free()
	)
	vbox.add_child(back_btn)


func _finalize_save(chosen_featured_cat: String) -> void:
	var paint_path := StoryManager.POSTER_PAINT_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_PAINT_PATH
	var final_path := StoryManager.POSTER_IMAGE_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_IMAGE_PATH

	var paint_img := _surface.get_paint_image()
	var composited_img: Image = await _surface.render_composited_image_async()
	paint_img.save_png(paint_path)
	composited_img.save_png(final_path)

	StoryManager.save_storefront_artwork(
		_slot_name,
		_surface.get_serialized_stickers(),
		chosen_featured_cat,
		_recent_colors
	)

	AudioManager.play_sfx("purchase")
	if _slot_name == "signage":
		if chosen_featured_cat != "":
			EventBus.show_notification.emit(
				"Roof Signage Mounted!",
				"Featuring %s (+demand & +₱3 promo bonus)! Signage can be edited again tomorrow." % StoryManager.get_category_display_name(chosen_featured_cat),
				"purchase"
			)
		else:
			EventBus.show_notification.emit("Roof Signage Mounted!", "Your custom signboard is live! Signage can be edited again tomorrow.", "purchase")
	elif chosen_featured_cat != "":
		EventBus.show_notification.emit(
			"Poster Mounted!",
			"Featuring %s (+demand & +₱3 promo bonus)!" % StoryManager.get_category_display_name(chosen_featured_cat),
			"purchase"
		)
	else:
		EventBus.show_notification.emit("Poster Mounted!", "Add 3+ stickers of one category anytime to activate a Featured Promo!", "purchase")

	_close_overlay(true)


func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("drop")
	_close_overlay(false)


func _close_overlay(saved: bool) -> void:
	Input.set_mouse_mode(_prev_mouse_mode)
	closed.emit(saved)
	queue_free()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	# Let LineEdit receive typing freely when editing a Text layer
	var typing_text := is_instance_valid(_text_input) and _text_input.has_focus()
	if event.keycode == KEY_ESCAPE and not event.echo:
		get_viewport().set_input_as_handled()
		if typing_text:
			_text_input.release_focus()
		elif is_instance_valid(_featured_modal):
			_featured_modal.queue_free()
		else:
			_on_cancel_pressed()
		return

	if typing_text or is_instance_valid(_featured_modal):
		return

	if event.ctrl_pressed and not event.echo:
		if event.keycode == KEY_Z:
			get_viewport().set_input_as_handled()
			if event.shift_pressed:
				_surface.redo()
			else:
				_surface.undo()
			return
		elif event.keycode == KEY_Y:
			get_viewport().set_input_as_handled()
			_surface.redo()
			return
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			get_viewport().set_input_as_handled()
			_surface.zoom_by(1.2)
			return
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			get_viewport().set_input_as_handled()
			_surface.zoom_by(1.0 / 1.2)
			return
		elif event.keycode == KEY_0 or event.keycode == KEY_KP_0:
			get_viewport().set_input_as_handled()
			_surface.reset_view()
			return

	if not event.echo and not event.ctrl_pressed and not event.alt_pressed:
		match event.keycode:
			KEY_B: _select_tool(CanvasDrawSurface.Tool.BRUSH)
			KEY_G: _select_tool(CanvasDrawSurface.Tool.BUCKET)
			KEY_E: _select_tool(CanvasDrawSurface.Tool.ERASER)
			KEY_I: _select_tool(CanvasDrawSurface.Tool.EYEDROPPER)
			KEY_T: _select_tool(CanvasDrawSurface.Tool.TEXT)
			KEY_V: _select_tool(CanvasDrawSurface.Tool.SELECT)
			KEY_DELETE, KEY_BACKSPACE:
				if _surface._selected_sticker >= 0:
					get_viewport().set_input_as_handled()
					AudioManager.play_sfx("drop")
					_surface.delete_selected_sticker()
