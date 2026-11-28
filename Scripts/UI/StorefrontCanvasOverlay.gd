class_name StorefrontCanvasOverlay
extends CanvasLayer

## Cozy skribbl.io-style storefront drawing studio for Roof Signage (Lv. 1) & Promo Poster (Lv. 2).
## Follows the Restock Menu's Dark Warm Espresso + Antique Gold design philosophy:
##   - 5% title-safe margins, crisp white canvas as focal point
##   - Single-glance skribbl.io bottom dock: 2-row color swatches, Brush/Fill/Eraser, 4 size dots, Undo/Redo/Clear
##   - Right-side Stickers & Stamp drawer with persistent "+ Upload" image stickers
##   - 3-Sticker Featured Category Promo active ONLY for Promo Poster (removed from Roof Signage)

signal closed(saved: bool)

const CanvasSurfaceScript = preload("res://Scripts/UI/CanvasDrawSurface.gd")

const SIGNAGE_CANVAS_SIZE := Vector2i(1024, 368)
const POSTER_CANVAS_SIZE := Vector2i(540, 780)

# Palette: matches RestockMenu Dark Warm Espresso + Antique Gold + Crisp Cream
const COL_BACKDROP := Color(0.052, 0.044, 0.038, 0.97)
const COL_SURFACE := Color(0.105, 0.090, 0.078, 0.96)
const COL_CARD := Color(0.132, 0.114, 0.098, 0.94)
const COL_CARD_HOVER := Color(0.168, 0.144, 0.122, 0.98)
const COL_CARD_ACTIVE := Color(0.220, 0.172, 0.105, 0.98)
const COL_DRAWER := Color(0.088, 0.075, 0.064, 0.98)
const COL_GOLD := Color(0.86, 0.67, 0.32, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.89, 0.58, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.86, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.76, 0.67, 0.88)
const COL_BORDER_SUBTLE := Color(0.42, 0.31, 0.18, 0.52)
const COL_POSITIVE := Color(0.56, 0.90, 0.56, 1.0)
const COL_CORAL := Color(0.94, 0.48, 0.44, 1.0)
const COL_BTN_DARK := Color(0.16, 0.135, 0.112, 1.0)

# Skribbl.io 2-row × 11-column palette (Row 1: light/vibrant, Row 2: dark/rich)
const SKRIBBL_SWATCHES: Array[Color] = [
	# Row 1
	Color(1.00, 1.00, 1.00, 1.0), # White
	Color(0.76, 0.76, 0.76, 1.0), # Light Gray
	Color(0.94, 0.24, 0.22, 1.0), # Red
	Color(0.98, 0.52, 0.14, 1.0), # Orange
	Color(1.00, 0.86, 0.22, 1.0), # Yellow
	Color(0.30, 0.80, 0.34, 1.0), # Bright Green
	Color(0.16, 0.76, 0.86, 1.0), # Sky Cyan
	Color(0.22, 0.46, 0.94, 1.0), # Royal Blue
	Color(0.64, 0.32, 0.88, 1.0), # Purple
	Color(0.96, 0.44, 0.68, 1.0), # Pink
	Color(0.98, 0.88, 0.70, 1.0), # Warm Cream / Peach
	# Row 2
	Color(0.08, 0.07, 0.06, 1.0), # Charcoal Black
	Color(0.38, 0.38, 0.40, 1.0), # Dark Gray
	Color(0.56, 0.09, 0.10, 1.0), # Maroon
	Color(0.72, 0.30, 0.06, 1.0), # Rust Orange
	Color(0.84, 0.64, 0.14, 1.0), # Sari-Sari Gold
	Color(0.12, 0.46, 0.20, 1.0), # Forest Green
	Color(0.08, 0.42, 0.54, 1.0), # Deep Teal
	Color(0.12, 0.20, 0.52, 1.0), # Navy Blue
	Color(0.36, 0.14, 0.52, 1.0), # Plum
	Color(0.66, 0.18, 0.40, 1.0), # Berry
	Color(0.46, 0.26, 0.14, 1.0), # Espresso Brown
]

const SIZE_DOT_RADII: Array[float] = [3.5, 6.0, 9.5, 13.5]

var _slot_name: String = "signage"
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _active_color: Color = Color(0.94, 0.24, 0.22, 1.0)
var _selected_sticker_category: String = "all"
var _active_stamp_key: String = "" # item_path or image_path of currently selected stamp
var _bold_font: FontVariation

var _surface: CanvasDrawSurface
var _title_lbl: Label
var _subtitle_lbl: Label
var _color_preview: PanelContainer
var _color_preview_style: StyleBoxFlat
var _tool_buttons: Dictionary = {} # Tool enum -> Button
var _size_buttons: Array[Button] = []
var _undo_btn: Button
var _redo_btn: Button
var _reset_default_btn: Button
var _upload_dialog: FileDialog = null

# Stickers Drawer
var _promo_card: PanelContainer
var _promo_vbox: VBoxContainer
var _stamp_hint_lbl: Label
var _cat_tabs_row: HFlowContainer
var _sticker_grid: GridContainer
var _sticker_cards: Dictionary = {} # key -> Button

# Save / Tie-breaker Modal
var _modal: ColorRect = null


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("storefront_canvas_active")
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.58


func open_editor(slot_name: String) -> void:
	_slot_name = "poster" if slot_name == "poster" else "signage"
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_build_ui()

	var target_sz := POSTER_CANVAS_SIZE if _slot_name == "poster" else SIGNAGE_CANVAS_SIZE
	var final_path := StoryManager.POSTER_IMAGE_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_IMAGE_PATH
	var paint_path := StoryManager.POSTER_PAINT_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_PAINT_PATH
	var saved_stamps: Array = StoryManager.custom_poster_stickers if _slot_name == "poster" else []

	# Prefer composited PNG so any previously saved art/stickers/text remain intact on the canvas
	var loaded_img: Image = null
	if FileAccess.file_exists(final_path):
		loaded_img = Image.load_from_file(final_path)
	elif FileAccess.file_exists(paint_path):
		loaded_img = Image.load_from_file(paint_path)

	_surface.setup_canvas(target_sz, loaded_img, saved_stamps)
	_set_active_color(_active_color)
	_select_size(1)
	_select_tool(CanvasDrawSurface.Tool.BRUSH)
	_refresh_sticker_palette()
	_refresh_promo_status()
	_refresh_reset_button_state()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Full-screen borderless Dark Warm Espresso backdrop (matches RestockMenu)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BACKDROP
	root.add_child(bg)

	# 5% Title-safe outer margin container
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 28)
	safe_margin.add_theme_constant_override("margin_right", 28)
	safe_margin.add_theme_constant_override("margin_top", 18)
	safe_margin.add_theme_constant_override("margin_bottom", 18)
	root.add_child(safe_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	safe_margin.add_child(main_vbox)

	# ── 1. CALM HEADER BAR ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	header.add_child(title_col)

	_title_lbl = Label.new()
	_title_lbl.text = "Promo Poster" if _slot_name == "poster" else "Roof Signage"
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", COL_CREAM)
	title_col.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.text = "Paint your poster & stamp 3 product stickers of one category for a Featured Promo." if _slot_name == "poster" else "Hand-paint your sari-sari signboard and decorate it with stickers."
	_subtitle_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_subtitle_lbl.add_theme_font_size_override("font_size", 13)
	_subtitle_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	title_col.add_child(_subtitle_lbl)

	_reset_default_btn = _make_btn("Reset Default", COL_BTN_DARK, COL_GOLD_BRIGHT, 14)
	_reset_default_btn.custom_minimum_size = Vector2(126, 38)
	_reset_default_btn.tooltip_text = "Remove custom art and restore the default look"
	_reset_default_btn.pressed.connect(_on_reset_to_default_pressed)
	header.add_child(_reset_default_btn)

	var cancel_btn := _make_btn("Cancel", COL_BTN_DARK, COL_CREAM_MUTED, 14)
	cancel_btn.custom_minimum_size = Vector2(92, 38)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	header.add_child(cancel_btn)

	var save_btn := _make_btn("Save & Mount", COL_GOLD, Color(0.08, 0.06, 0.04, 1.0), 15)
	save_btn.custom_minimum_size = Vector2(148, 38)
	save_btn.pressed.connect(_on_save_pressed)
	header.add_child(save_btn)

	# ── 2. MAIN WORKSPACE: CANVAS + SKRIBBL BOTTOM BAR (LEFT) | STICKERS DRAWER (RIGHT) ──
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	main_vbox.add_child(body)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 12)
	body.add_child(left_col)

	# Canvas Stage
	_surface = CanvasSurfaceScript.new()
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_surface.stamps_changed.connect(_refresh_promo_status)
	_surface.tool_changed.connect(_on_surface_tool_changed)
	_surface.history_changed.connect(_on_history_changed)
	left_col.add_child(_surface)

	# ── SKRIBBL.IO BOTTOM TOOL DOCK ──
	var dock_center := CenterContainer.new()
	dock_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_child(dock_center)

	var dock_panel := PanelContainer.new()
	var dock_st := UIStyle.create_flat_stylebox(COL_SURFACE, 12, 14, 10)
	dock_st.border_color = COL_BORDER_SUBTLE
	dock_st.set_border_width_all(1)
	dock_panel.add_theme_stylebox_override("panel", dock_st)
	dock_center.add_child(dock_panel)

	var dock_row := HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 12)
	dock_panel.add_child(dock_row)

	# Active color preview tile
	_color_preview = PanelContainer.new()
	_color_preview.custom_minimum_size = Vector2(44, 44)
	_color_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_color_preview_style = UIStyle.create_flat_stylebox(_active_color, 8, 0, 0)
	_color_preview_style.border_color = COL_GOLD_BRIGHT
	_color_preview_style.set_border_width_all(2)
	_color_preview.add_theme_stylebox_override("panel", _color_preview_style)
	dock_row.add_child(_color_preview)

	# 2-row × 11-column Skribbl.io Swatches
	var swatch_grid := GridContainer.new()
	swatch_grid.columns = 11
	swatch_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch_grid.add_theme_constant_override("h_separation", 4)
	swatch_grid.add_theme_constant_override("v_separation", 4)
	dock_row.add_child(swatch_grid)
	for sw in SKRIBBL_SWATCHES:
		swatch_grid.add_child(_make_swatch_btn(sw))

	dock_row.add_child(_make_vsep())

	# Core 3 Tools: Brush, Fill, Eraser
	var tools_box := HBoxContainer.new()
	tools_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools_box.add_theme_constant_override("separation", 6)
	dock_row.add_child(tools_box)

	var tool_defs: Array[Array] = [
		[CanvasDrawSurface.Tool.BRUSH, "Brush", "Brush (B)"],
		[CanvasDrawSurface.Tool.BUCKET, "Fill", "Fill Bucket (G)"],
		[CanvasDrawSurface.Tool.ERASER, "Eraser", "Eraser (E)"],
	]
	for td in tool_defs:
		var t_enum: int = td[0]
		var btn := _make_btn(str(td[1]), COL_BTN_DARK, COL_CREAM, 13)
		btn.custom_minimum_size = Vector2(64, 40)
		btn.tooltip_text = str(td[2])
		btn.pressed.connect(func():
			AudioManager.play_sfx("interact")
			_select_tool(t_enum)
		)
		tools_box.add_child(btn)
		_tool_buttons[t_enum] = btn

	dock_row.add_child(_make_vsep())

	# 4 Fixed Size Dots (controls Brush, Eraser, and Stamp scale)
	var sizes_box := HBoxContainer.new()
	sizes_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sizes_box.add_theme_constant_override("separation", 6)
	dock_row.add_child(sizes_box)

	var size_names: Array[String] = ["Small", "Medium", "Large", "Extra Large"]
	_size_buttons.clear()
	for idx in range(SIZE_DOT_RADII.size()):
		var sbtn := _make_size_dot_btn(idx, SIZE_DOT_RADII[idx], size_names[idx])
		sizes_box.add_child(sbtn)
		_size_buttons.append(sbtn)

	dock_row.add_child(_make_vsep())

	# Undo / Redo / Clear
	var act_box := HBoxContainer.new()
	act_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act_box.add_theme_constant_override("separation", 6)
	dock_row.add_child(act_box)

	_undo_btn = _make_btn("↶", COL_BTN_DARK, COL_CREAM, 18)
	_undo_btn.custom_minimum_size = Vector2(40, 40)
	_undo_btn.tooltip_text = "Undo (Ctrl+Z)"
	_undo_btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _surface.undo())
	act_box.add_child(_undo_btn)

	_redo_btn = _make_btn("↷", COL_BTN_DARK, COL_CREAM, 18)
	_redo_btn.custom_minimum_size = Vector2(40, 40)
	_redo_btn.tooltip_text = "Redo (Ctrl+Y)"
	_redo_btn.pressed.connect(func(): AudioManager.play_sfx("interact"); _surface.redo())
	act_box.add_child(_redo_btn)

	var clear_btn := _make_btn("Clear", Color(0.32, 0.14, 0.13, 0.96), Color(1.0, 0.88, 0.86, 1.0), 13)
	clear_btn.custom_minimum_size = Vector2(58, 40)
	clear_btn.tooltip_text = "Clear Canvas"
	clear_btn.pressed.connect(func(): AudioManager.play_sfx("drop"); _surface.clear_canvas())
	act_box.add_child(clear_btn)

	# ── 3. RIGHT STICKERS & UPLOAD DRAWER ──
	var drawer := PanelContainer.new()
	drawer.custom_minimum_size = Vector2(292, 0)
	drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dr_st := UIStyle.create_flat_stylebox(COL_DRAWER, 12, 14, 14)
	dr_st.border_color = COL_BORDER_SUBTLE
	dr_st.set_border_width_all(1)
	drawer.add_theme_stylebox_override("panel", dr_st)
	body.add_child(drawer)

	var drawer_v := VBoxContainer.new()
	drawer_v.add_theme_constant_override("separation", 10)
	drawer.add_child(drawer_v)

	# Drawer Header + Upload Sticker Button
	var dr_hdr := HBoxContainer.new()
	dr_hdr.add_theme_constant_override("separation", 8)
	drawer_v.add_child(dr_hdr)

	var dr_title := Label.new()
	dr_title.text = "Stickers"
	dr_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dr_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dr_title.add_theme_font_override("font", _bold_font)
	dr_title.add_theme_font_size_override("font_size", 18)
	dr_title.add_theme_color_override("font_color", COL_CREAM)
	dr_hdr.add_child(dr_title)

	var upload_btn := _make_btn("+ Upload", Color(0.18, 0.24, 0.30, 0.96), Color(0.88, 0.95, 1.0, 1.0), 12)
	upload_btn.custom_minimum_size = Vector2(92, 30)
	upload_btn.tooltip_text = "Upload PNG, JPG, or WEBP and save it as a reusable sticker"
	upload_btn.pressed.connect(_on_upload_image_pressed)
	dr_hdr.add_child(upload_btn)

	# Stamp mode status hint
	_stamp_hint_lbl = Label.new()
	_stamp_hint_lbl.text = "Click a sticker to stamp it onto your canvas."
	_stamp_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stamp_hint_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_stamp_hint_lbl.add_theme_font_size_override("font_size", 12)
	_stamp_hint_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	drawer_v.add_child(_stamp_hint_lbl)

	# Promo Poster Featured Category Tracker (ONLY shown for Promo Poster)
	_promo_card = PanelContainer.new()
	var pc_st := UIStyle.create_flat_stylebox(COL_CARD, 8, 10, 8)
	pc_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.65)
	pc_st.set_border_width_all(1)
	_promo_card.add_theme_stylebox_override("panel", pc_st)
	_promo_card.visible = (_slot_name == "poster")
	drawer_v.add_child(_promo_card)

	_promo_vbox = VBoxContainer.new()
	_promo_vbox.add_theme_constant_override("separation", 3)
	_promo_card.add_child(_promo_vbox)

	# Category filter pills
	_cat_tabs_row = HFlowContainer.new()
	_cat_tabs_row.add_theme_constant_override("h_separation", 4)
	_cat_tabs_row.add_theme_constant_override("v_separation", 4)
	drawer_v.add_child(_cat_tabs_row)

	# Scrollable Sticker Grid
	var stk_scroll := ScrollContainer.new()
	stk_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stk_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stk_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	drawer_v.add_child(stk_scroll)

	_sticker_grid = GridContainer.new()
	_sticker_grid.columns = 3
	_sticker_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sticker_grid.add_theme_constant_override("h_separation", 6)
	_sticker_grid.add_theme_constant_override("v_separation", 6)
	stk_scroll.add_child(_sticker_grid)


func _make_vsep() -> ColorRect:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 34)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sep.color = COL_BORDER_SUBTLE
	return sep


func _make_btn(txt: String, bg: Color, fg: Color, font_sz: int = 14) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(btn, bg, fg, float(font_sz), 8)
	return btn


func _make_swatch_btn(col: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(26, 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := UIStyle.create_flat_stylebox(col, 4, 0, 0)
	st.border_color = Color(0.0, 0.0, 0.0, 0.35)
	st.set_border_width_all(1)
	var hov: StyleBoxFlat = st.duplicate()
	hov.border_color = COL_GOLD_BRIGHT
	hov.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_set_active_color(col)
		if _surface.active_tool == CanvasDrawSurface.Tool.ERASER or _surface.active_tool == CanvasDrawSurface.Tool.STAMP:
			_select_tool(CanvasDrawSurface.Tool.BRUSH)
	)
	return btn


func _make_size_dot_btn(idx: int, dot_radius: float, tooltip_lbl: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(36, 40)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "%s Size (%d)" % [tooltip_lbl, idx + 1]
	var dot := _SizeDotControl.new()
	dot.dot_radius = dot_radius
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(dot)
	btn.set_meta("dot_ctrl", dot)
	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_select_size(idx)
	)
	return btn


func _select_size(idx: int) -> void:
	_surface.size_index = idx
	for i in range(_size_buttons.size()):
		var btn := _size_buttons[i]
		var is_cur := (i == idx)
		UIStyle.style_button(btn, COL_GOLD if is_cur else COL_BTN_DARK, Color(0.08, 0.06, 0.04, 1.0) if is_cur else COL_CREAM, 12.0, 8)
		var dot: _SizeDotControl = btn.get_meta("dot_ctrl", null)
		if is_instance_valid(dot):
			dot.dot_color = Color(0.08, 0.06, 0.04, 1.0) if is_cur else COL_CREAM
			dot.queue_redraw()


func _select_tool(t: int) -> void:
	if t != CanvasDrawSurface.Tool.STAMP:
		_active_stamp_key = ""
		_surface.clear_active_stamp()
	_surface.active_tool = t
	_sync_tool_ui(t)


func _on_surface_tool_changed(t: int) -> void:
	if t != CanvasDrawSurface.Tool.STAMP:
		_active_stamp_key = ""
	_sync_tool_ui(t)


func _sync_tool_ui(t: int) -> void:
	for k in _tool_buttons.keys():
		var btn: Button = _tool_buttons[k]
		var is_cur: bool = (int(k) == t)
		UIStyle.style_button(
			btn,
			COL_GOLD if is_cur else COL_BTN_DARK,
			Color(0.08, 0.06, 0.04, 1.0) if is_cur else COL_CREAM,
			13.0,
			8
		)
	_refresh_sticker_selection_highlight()
	if is_instance_valid(_stamp_hint_lbl):
		if t == CanvasDrawSurface.Tool.STAMP and _active_stamp_key != "":
			_stamp_hint_lbl.text = "Stamp Mode · Click to stamp · Scroll to rotate · Right-click to paint"
			_stamp_hint_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		else:
			_stamp_hint_lbl.text = "Click a sticker to stamp it onto your canvas."
			_stamp_hint_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)


func _set_active_color(col: Color) -> void:
	_active_color = Color(col.r, col.g, col.b, 1.0)
	_surface.brush_color = _active_color
	if _color_preview_style:
		_color_preview_style.bg_color = _active_color


func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	if is_instance_valid(_undo_btn):
		_undo_btn.disabled = not can_undo
	if is_instance_valid(_redo_btn):
		_redo_btn.disabled = not can_redo


func _refresh_reset_button_state() -> void:
	if not is_instance_valid(_reset_default_btn):
		return
	var has_custom := StoryManager.has_custom_poster if _slot_name == "poster" else StoryManager.has_custom_signage
	_reset_default_btn.disabled = not has_custom


func _on_upload_image_pressed() -> void:
	AudioManager.play_sfx("interact")
	if is_instance_valid(_upload_dialog):
		_upload_dialog.queue_free()
	_upload_dialog = FileDialog.new()
	_upload_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_upload_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_upload_dialog.use_native_dialog = true
	_upload_dialog.title = "Upload Sticker Image"
	_upload_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Image Files"])
	_upload_dialog.file_selected.connect(func(path: String):
		var saved := CanvasDrawSurface.import_uploaded_sticker(path)
		if not saved.is_empty():
			AudioManager.play_sfx("purchase")
			var img_path := str(saved["image_path"])
			var lbl := str(saved["label"])
			_selected_sticker_category = "uploads"
			_active_stamp_key = img_path
			_surface.set_active_stamp_upload(img_path, lbl)
			_refresh_sticker_palette()
			EventBus.show_notification.emit("Sticker Saved!", "'%s' added to your Stickers — click the canvas to stamp it!" % lbl, "interact")
		else:
			AudioManager.play_sfx("error")
			EventBus.show_notification.emit("Upload Failed", "Could not load that image file.", "error")
	)
	add_child(_upload_dialog)
	_upload_dialog.popup_centered_ratio(0.65)


func _refresh_sticker_palette() -> void:
	var unlocked: Array[ItemData] = []
	var cat_set: Dictionary = {}
	for item in InventoryManager.get_all_items():
		if item and item.can_be_sold and item.tier <= StoryManager.current_tier:
			unlocked.append(item)
			cat_set[item.category.to_lower()] = true

	var uploads := CanvasDrawSurface.list_uploaded_stickers()

	if is_instance_valid(_cat_tabs_row):
		for ch in _cat_tabs_row.get_children():
			ch.queue_free()
		var cats: Array[String] = ["all"]
		if not uploads.is_empty():
			cats.append("uploads")
		for c in ["snack", "can", "bottle", "frozen", "candy", "sachet", "pack", "cigarette"]:
			if cat_set.has(c):
				cats.append(c)
		if _selected_sticker_category != "all" and not cats.has(_selected_sticker_category):
			_selected_sticker_category = "all"

		for c in cats:
			var tbtn := Button.new()
			tbtn.text = "All" if c == "all" else ("Uploads" if c == "uploads" else StoryManager.get_category_display_name(c))
			tbtn.focus_mode = Control.FOCUS_NONE
			tbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var is_active: bool = (_selected_sticker_category == c)
			UIStyle.style_button(
				tbtn,
				COL_GOLD if is_active else COL_CARD,
				Color(0.08, 0.06, 0.04, 1.0) if is_active else COL_CREAM_MUTED,
				11.0,
				5
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
		_sticker_cards.clear()

		# Show uploaded stickers first in "all" or "uploads"
		if _selected_sticker_category == "all" or _selected_sticker_category == "uploads":
			for up in uploads:
				var card := _create_upload_sticker_card(str(up["image_path"]), str(up["label"]))
				_sticker_grid.add_child(card)
				_sticker_cards[str(up["image_path"])] = card

		# Store product stickers
		if _selected_sticker_category != "uploads":
			for item in unlocked:
				if _selected_sticker_category != "all" and item.category.to_lower() != _selected_sticker_category:
					continue
				var card := _create_product_sticker_card(item)
				_sticker_grid.add_child(card)
				_sticker_cards[item.resource_path] = card

		_refresh_sticker_selection_highlight()


func _create_product_sticker_card(item: ItemData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 74)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "%s (%s)" % [item.item_name, StoryManager.get_category_display_name(item.category)]
	_apply_sticker_card_style(btn, false)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	if item.texture:
		var tr := TextureRect.new()
		tr.texture = item.texture
		tr.custom_minimum_size = Vector2(42, 42)
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
	nl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)

	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		if _active_stamp_key == item.resource_path and _surface.active_tool == CanvasDrawSurface.Tool.STAMP:
			_select_tool(CanvasDrawSurface.Tool.BRUSH)
		else:
			_active_stamp_key = item.resource_path
			_surface.set_active_stamp_item(item)
	)
	return btn


func _create_upload_sticker_card(image_path: String, label_txt: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 74)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "%s (Uploaded Sticker)" % label_txt
	_apply_sticker_card_style(btn, false)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var img := Image.load_from_file(image_path)
	if img != null and not img.is_empty():
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.custom_minimum_size = Vector2(42, 42)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(tr)

	var nl := Label.new()
	nl.text = label_txt
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	nl.add_theme_font_override("font", UIStyle.FONT_INDER)
	nl.add_theme_font_size_override("font_size", 10)
	nl.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.92))
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)

	# Small top-right delete button to remove saved uploaded sticker
	var del_btn := Button.new()
	del_btn.text = "×"
	del_btn.anchor_left = 1.0
	del_btn.anchor_right = 1.0
	del_btn.anchor_top = 0.0
	del_btn.anchor_bottom = 0.0
	del_btn.offset_left = -20.0
	del_btn.offset_top = 2.0
	del_btn.offset_right = -2.0
	del_btn.offset_bottom = 20.0
	del_btn.focus_mode = Control.FOCUS_NONE
	del_btn.tooltip_text = "Delete Uploaded Sticker"
	UIStyle.style_button(del_btn, Color(0.45, 0.14, 0.13, 0.90), Color.WHITE, 11.0, 4)
	del_btn.pressed.connect(func():
		AudioManager.play_sfx("drop")
		if _active_stamp_key == image_path:
			_select_tool(CanvasDrawSurface.Tool.BRUSH)
		CanvasDrawSurface.delete_uploaded_sticker(image_path)
		_refresh_sticker_palette()
	)
	btn.add_child(del_btn)

	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		if _active_stamp_key == image_path and _surface.active_tool == CanvasDrawSurface.Tool.STAMP:
			_select_tool(CanvasDrawSurface.Tool.BRUSH)
		else:
			_active_stamp_key = image_path
			_surface.set_active_stamp_upload(image_path, label_txt)
	)
	return btn


func _apply_sticker_card_style(btn: Button, selected: bool) -> void:
	var st := UIStyle.create_flat_stylebox(COL_CARD_ACTIVE if selected else COL_CARD, 8, 4, 4)
	st.border_color = COL_GOLD_BRIGHT if selected else COL_BORDER_SUBTLE
	st.set_border_width_all(2 if selected else 1)
	var hov := UIStyle.create_flat_stylebox(COL_CARD_ACTIVE if selected else COL_CARD_HOVER, 8, 4, 4)
	hov.border_color = COL_GOLD_BRIGHT
	hov.set_border_width_all(2 if selected else 1)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)


func _refresh_sticker_selection_highlight() -> void:
	var stamping := (_surface.active_tool == CanvasDrawSurface.Tool.STAMP and _active_stamp_key != "")
	for key in _sticker_cards.keys():
		var btn: Button = _sticker_cards[key]
		if is_instance_valid(btn):
			_apply_sticker_card_style(btn, stamping and str(key) == _active_stamp_key)


func _refresh_promo_status() -> void:
	if _slot_name != "poster" or not is_instance_valid(_promo_vbox):
		return
	for ch in _promo_vbox.get_children():
		ch.queue_free()

	var counts := _surface.get_sticker_category_counts()
	var qualifying: Array[String] = []
	for cat in counts.keys():
		if int(counts[cat]) >= 3:
			qualifying.append(str(cat))

	var hdr := Label.new()
	hdr.add_theme_font_override("font", _bold_font)
	hdr.add_theme_font_size_override("font_size", 12)
	if qualifying.size() == 1:
		hdr.text = "✦ Featured Ready: %s (+₱3)" % StoryManager.get_category_display_name(qualifying[0])
		hdr.add_theme_color_override("font_color", COL_POSITIVE)
	elif qualifying.size() >= 2:
		hdr.text = "✦ %d categories ready! Pick 1 on Save." % qualifying.size()
		hdr.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	else:
		hdr.text = "Featured Promo (3 of 1 category)"
		hdr.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promo_vbox.add_child(hdr)

	if counts.is_empty():
		var sub := Label.new()
		sub.text = "Stamp 3 product stickers of one category for +demand & +₱3 bonus."
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_override("font", UIStyle.FONT_INDER)
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_promo_vbox.add_child(sub)
	else:
		var sorted_cats: Array[String] = []
		for c in counts.keys():
			sorted_cats.append(str(c))
		sorted_cats.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]))
		for cat in sorted_cats:
			var cnt := int(counts[cat])
			var ready := cnt >= 3
			var row := Label.new()
			row.text = "%d/3 %s%s" % [cnt, StoryManager.get_category_display_name(cat), "  ✓" if ready else ""]
			row.add_theme_font_override("font", _bold_font if ready else UIStyle.FONT_INDER)
			row.add_theme_font_size_override("font_size", 12)
			row.add_theme_color_override("font_color", COL_POSITIVE if ready else COL_CREAM)
			_promo_vbox.add_child(row)


func _on_reset_to_default_pressed() -> void:
	AudioManager.play_sfx("drop")
	StoryManager.reset_storefront_artwork(_slot_name)
	if _slot_name == "signage":
		EventBus.show_notification.emit("Signage Reset", "Restored the default storefront signboard.", "interact")
	else:
		EventBus.show_notification.emit("Poster Removed", "Cleared your custom storefront poster.", "interact")
	_close_overlay(true)


func _on_save_pressed() -> void:
	if _slot_name == "signage":
		_show_save_confirm_modal("", 0)
		return

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
	if is_instance_valid(_modal):
		_modal.queue_free()

	_modal = ColorRect.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.color = Color(0.02, 0.018, 0.015, 0.78)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -240
	card.offset_right = 240
	card.offset_top = -125
	card.offset_bottom = 125
	var st := UIStyle.create_flat_stylebox(COL_SURFACE, 12, 22, 18)
	st.border_color = COL_GOLD_BRIGHT
	st.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", st)
	_modal.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_CREAM)
	vbox.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_font_override("font", UIStyle.FONT_INDER)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", COL_CREAM_MUTED)
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
		title.text = "Mount Roof Signage?"
		body.text = "Your custom signboard will be displayed on your store & Main Menu (+%d%% Appreciation Tip chance & price relief).\n\nNote: Roof Signage can only be edited once per day." % maxi(15, tip_pct)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var no_btn := _make_btn("Keep Editing", COL_BTN_DARK, COL_CREAM_MUTED, 14)
	no_btn.custom_minimum_size = Vector2(140, 38)
	no_btn.pressed.connect(func():
		AudioManager.play_sfx("drop")
		_modal.queue_free()
	)
	btn_row.add_child(no_btn)

	var yes_btn := _make_btn("Save & Mount", COL_GOLD, Color(0.08, 0.06, 0.04, 1.0), 14)
	yes_btn.custom_minimum_size = Vector2(150, 38)
	yes_btn.pressed.connect(func():
		_modal.queue_free()
		_finalize_save(chosen_cat)
	)
	btn_row.add_child(yes_btn)


func _show_featured_category_modal(qualifying: Array[String], counts: Dictionary) -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()

	_modal = ColorRect.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.color = Color(0.02, 0.018, 0.015, 0.78)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -220
	card.offset_right = 220
	card.offset_top = -170
	card.offset_bottom = 170
	var st := UIStyle.create_flat_stylebox(COL_SURFACE, 12, 20, 18)
	st.border_color = COL_GOLD_BRIGHT
	st.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", st)
	_modal.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "Choose Featured Category"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _bold_font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_CREAM)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Multiple categories have 3/3 stickers. Pick one to feature on your Promo Poster:"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", COL_CREAM_MUTED)
	vbox.add_child(sub)

	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	vbox.add_child(list)

	for cat in qualifying:
		var pick_btn := _make_btn("%s (%d stickers)" % [StoryManager.get_category_display_name(cat), int(counts.get(cat, 3))], COL_CARD, COL_GOLD_BRIGHT, 15)
		pick_btn.custom_minimum_size = Vector2(0, 42)
		pick_btn.pressed.connect(func():
			AudioManager.play_sfx("purchase")
			_modal.queue_free()
			_finalize_save(cat)
		)
		list.add_child(pick_btn)

	var back_btn := _make_btn("Back to Edit", Color(0.32, 0.14, 0.13, 0.95), Color.WHITE, 14)
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("drop")
		_modal.queue_free()
	)
	vbox.add_child(back_btn)


func _finalize_save(chosen_featured_cat: String) -> void:
	var paint_path := StoryManager.POSTER_PAINT_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_PAINT_PATH
	var final_path := StoryManager.POSTER_IMAGE_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_IMAGE_PATH

	var img := _surface.get_paint_image()
	img.save_png(paint_path)
	img.save_png(final_path)

	var stamps_to_save: Array[Dictionary] = []
	if _slot_name == "poster":
		stamps_to_save.assign(_surface.get_serialized_stamps())
	StoryManager.save_storefront_artwork(
		_slot_name,
		stamps_to_save,
		chosen_featured_cat if _slot_name == "poster" else "",
		[]
	)

	AudioManager.play_sfx("purchase")
	if _slot_name == "signage":
		EventBus.show_notification.emit("Roof Signage Mounted!", "Your custom signboard is live! Signage can be edited again tomorrow.", "purchase")
	elif chosen_featured_cat != "":
		EventBus.show_notification.emit(
			"Poster Mounted!",
			"Featuring %s (+demand & +₱3 promo bonus)!" % StoryManager.get_category_display_name(chosen_featured_cat),
			"purchase"
		)
	else:
		EventBus.show_notification.emit("Poster Mounted!", "Stamp 3+ stickers of one category anytime to activate a Featured Promo!", "purchase")

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

	if event.keycode == KEY_ESCAPE and not event.echo:
		get_viewport().set_input_as_handled()
		if is_instance_valid(_modal):
			_modal.queue_free()
		elif _surface.active_tool == CanvasDrawSurface.Tool.STAMP:
			_select_tool(CanvasDrawSurface.Tool.BRUSH)
		else:
			_on_cancel_pressed()
		return

	if is_instance_valid(_modal):
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

	if not event.echo and not event.ctrl_pressed and not event.alt_pressed:
		match event.keycode:
			KEY_B: _select_tool(CanvasDrawSurface.Tool.BRUSH)
			KEY_G: _select_tool(CanvasDrawSurface.Tool.BUCKET)
			KEY_E: _select_tool(CanvasDrawSurface.Tool.ERASER)
			KEY_1: _select_size(0)
			KEY_2: _select_size(1)
			KEY_3: _select_size(2)
			KEY_4: _select_size(3)


class _SizeDotControl extends Control:
	var dot_radius: float = 6.0
	var dot_color: Color = Color.WHITE

	func _draw() -> void:
		draw_circle(size * 0.5, dot_radius, dot_color)
