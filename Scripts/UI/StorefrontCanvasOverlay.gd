class_name StorefrontCanvasOverlay
extends CanvasLayer

## Universal drawing studio overlay for custom Storefront Roof Signage (1024x368)
## and Storefront Promo Poster (540x780). Styled with the game's dark charcoal &
## warm gold palette, white canvas board, Color Wheel + RGB controls, Recent Colors,
## and Unlocked Store Product Stickers (3+ matching stickers feature a category on Posters).

signal closed(saved: bool)

const CanvasDrawSurfaceScript = preload("res://Scripts/UI/CanvasDrawSurface.gd")
const ColorWheelControlScript = preload("res://Scripts/UI/ColorWheelControl.gd")

const SIGNAGE_CANVAS_SIZE := Vector2i(1024, 368)
const POSTER_CANVAS_SIZE := Vector2i(540, 780)
const PROMO_THRESHOLD := 3

const BG_DARK := Color(0.082, 0.078, 0.071, 0.97)
const PANEL_DARK := Color(0.125, 0.114, 0.098, 0.98)
const CARD_DARK := Color(0.175, 0.157, 0.132, 1.0)
const GOLD_ACCENT := Color("#D59F47")
const GOLD_LIGHT := Color("#F5C97B")
const GOLD_TEXT := Color(1.0, 0.922, 0.792, 1.0)

const BASIC_SWATCHES: Array[Color] = [
	Color("#1A1714"), Color("#FFFFFF"), Color("#B92B27"), Color("#E67E22"),
	Color("#F1C40F"), Color("#2E8B57"), Color("#2980B9"), Color("#7D3C98"),
	Color("#E84393"), Color("#795548"), Color("#7EC292"), Color("#F5C97B"),
]

var _slot_name: String = "signage"
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _active_color: Color = Color("#1A1714")
var _recent_colors: Array[String] = []
var _syncing_color: bool = false
var _selected_sticker_category: String = "all"

var _surface: CanvasDrawSurfaceScript = null
var _wheel: ColorWheelControlScript = null
var _val_slider: HSlider = null
var _rgb_sliders: Array[HSlider] = []
var _rgb_spins: Array[SpinBox] = []
var _color_swatch_preview: ColorRect = null
var _hex_label: Label = null
var _brush_size_lbl: Label = null
var _brush_slider: HSlider = null

var _tool_buttons: Dictionary = {} # Tool enum -> Button
var _undo_btn: Button = null
var _redo_btn: Button = null
var _promo_banner_lbl: Label = null
var _promo_tracker_box: VBoxContainer = null
var _promo_tracker_panel: PanelContainer = null
var _cat_tabs_row: HFlowContainer = null
var _sticker_grid: GridContainer = null
var _recent_colors_grid: GridContainer = null

var _sticker_edit_bar: PanelContainer = null
var _sticker_edit_title: Label = null
var _sticker_action_btns: Array[Button] = []

var _featured_modal: Control = null
var _featured_modal_list: VBoxContainer = null


func _ready() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("storefront_canvas_active")


func open_editor(slot_name: String) -> void:
	_slot_name = "poster" if slot_name == "poster" else "signage"
	_prev_mouse_mode = Input.mouse_mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_recent_colors.clear()
	for hex_col in StoryManager.custom_recent_colors:
		var s := str(hex_col)
		if s != "" and _recent_colors.size() < 12:
			_recent_colors.append(s)

	_build_ui()
	_load_existing_artwork()
	_set_active_color(_active_color, true)
	_set_tool(CanvasDrawSurfaceScript.Tool.BRUSH)
	_refresh_sticker_palette()
	_refresh_promo_status()
	_refresh_recent_colors()
	_on_sticker_selection_changed(-1)


func _load_existing_artwork() -> void:
	var target_sz := POSTER_CANVAS_SIZE if _slot_name == "poster" else SIGNAGE_CANVAS_SIZE
	var paint_path := StoryManager.POSTER_PAINT_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_PAINT_PATH
	var final_path := StoryManager.POSTER_IMAGE_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_IMAGE_PATH
	var saved_stickers: Array = StoryManager.custom_poster_stickers if _slot_name == "poster" else StoryManager.custom_signage_stickers

	var loaded_img: Image = null
	if FileAccess.file_exists(paint_path):
		loaded_img = Image.load_from_file(paint_path)
	elif FileAccess.file_exists(final_path):
		loaded_img = Image.load_from_file(final_path)

	_surface.setup_canvas(target_sz, loaded_img, saved_stickers)


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(backdrop)

	var frame_margin := MarginContainer.new()
	frame_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.add_theme_constant_override("margin_left", 24)
	frame_margin.add_theme_constant_override("margin_right", 24)
	frame_margin.add_theme_constant_override("margin_top", 20)
	frame_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(frame_margin)

	var root_panel := PanelContainer.new()
	var root_style := UIStyle.create_card_style(BG_DARK, GOLD_ACCENT, 2)
	root_style.set_corner_radius_all(12)
	root_style.content_margin_left = 14
	root_style.content_margin_right = 14
	root_style.content_margin_top = 12
	root_style.content_margin_bottom = 12
	root_panel.add_theme_stylebox_override("panel", root_style)
	frame_margin.add_child(root_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	root_panel.add_child(main_vbox)

	# ── 1. Top Toolbar ────────────────────────────────────────────────────────
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 44)
	top_bar.add_theme_constant_override("separation", 10)
	main_vbox.add_child(top_bar)

	var title_lbl := Label.new()
	title_lbl.text = "STOREFRONT POSTER STUDIO" if _slot_name == "poster" else "ROOF SIGNAGE STUDIO"
	title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	top_bar.add_child(title_lbl)

	var dim_pill := _make_badge_label(
		"%d × %d" % [
			POSTER_CANVAS_SIZE.x if _slot_name == "poster" else SIGNAGE_CANVAS_SIZE.x,
			POSTER_CANVAS_SIZE.y if _slot_name == "poster" else SIGNAGE_CANVAS_SIZE.y
		],
		Color(0.20, 0.17, 0.14, 1.0),
		GOLD_LIGHT
	)
	top_bar.add_child(dim_pill)

	if _slot_name == "poster":
		var promo_badge := PanelContainer.new()
		promo_badge.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.22, 0.17, 0.10, 0.95), 6, 10, 4))
		_promo_banner_lbl = Label.new()
		_promo_banner_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		_promo_banner_lbl.add_theme_font_size_override("font_size", 13)
		_promo_banner_lbl.add_theme_color_override("font_color", GOLD_LIGHT)
		promo_badge.add_child(_promo_banner_lbl)
		top_bar.add_child(promo_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_undo_btn = Button.new()
	_undo_btn.text = "Undo"
	_undo_btn.focus_mode = Control.FOCUS_NONE
	_undo_btn.tooltip_text = "Undo (Ctrl+Z)"
	UIStyle.style_button(_undo_btn, CARD_DARK, GOLD_TEXT, 14.0, 6)
	_undo_btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_surface.undo()
	)
	top_bar.add_child(_undo_btn)

	_redo_btn = Button.new()
	_redo_btn.text = "Redo"
	_redo_btn.focus_mode = Control.FOCUS_NONE
	_redo_btn.tooltip_text = "Redo (Ctrl+Y)"
	UIStyle.style_button(_redo_btn, CARD_DARK, GOLD_TEXT, 14.0, 6)
	_redo_btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_surface.redo()
	)
	top_bar.add_child(_redo_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(clear_btn, Color(0.36, 0.20, 0.16, 1.0), GOLD_TEXT, 14.0, 6)
	clear_btn.pressed.connect(func():
		AudioManager.play_sfx("drop")
		_surface.clear_canvas()
	)
	top_bar.add_child(clear_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(cancel_btn, UIStyle.COLOR_CANCEL, Color.WHITE, 14.0, 6)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	top_bar.add_child(cancel_btn)

	var save_btn := Button.new()
	save_btn.text = "Save & Mount"
	save_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(save_btn, GOLD_ACCENT, Color(0.10, 0.08, 0.06, 1.0), 15.0, 6)
	save_btn.pressed.connect(_on_save_pressed)
	top_bar.add_child(save_btn)

	# ── 2. Body Split (Tools | White Board | Product Stickers) ───────────────
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	main_vbox.add_child(body)

	body.add_child(_build_left_tools_panel())
	body.add_child(_build_center_canvas_panel())
	body.add_child(_build_right_stickers_panel())

	_surface.history_changed.connect(_on_history_changed)
	_surface.stroke_committed.connect(_on_stroke_committed)
	_surface.eyedropper_picked.connect(_on_eyedropper_picked)
	_surface.stickers_changed.connect(_on_stickers_changed)
	_surface.sticker_selection_changed.connect(_on_sticker_selection_changed)


func _build_left_tools_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.create_card_style(PANEL_DARK, Color(0.32, 0.26, 0.18, 1.0), 1))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Tools grid
	vbox.add_child(_make_section_heading("TOOLS"))
	var tool_grid := GridContainer.new()
	tool_grid.columns = 2
	tool_grid.add_theme_constant_override("h_separation", 6)
	tool_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(tool_grid)

	var tool_defs: Array = [
		[CanvasDrawSurfaceScript.Tool.BRUSH, "Brush [B]"],
		[CanvasDrawSurfaceScript.Tool.ERASER, "Eraser [E]"],
		[CanvasDrawSurfaceScript.Tool.BUCKET, "Bucket [G]"],
		[CanvasDrawSurfaceScript.Tool.EYEDROPPER, "Picker [I]"],
		[CanvasDrawSurfaceScript.Tool.SELECT, "Move Sticker [V]"],
	]
	for td in tool_defs:
		var t_enum: int = td[0]
		var btn := Button.new()
		btn.text = str(td[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func():
			AudioManager.play_sfx("interact")
			_set_tool(t_enum)
		)
		_tool_buttons[t_enum] = btn
		tool_grid.add_child(btn)

	# Brush Size
	var sz_row := HBoxContainer.new()
	var sz_hdr := _make_section_heading("BRUSH SIZE")
	sz_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sz_row.add_child(sz_hdr)
	_brush_size_lbl = Label.new()
	_brush_size_lbl.text = "12 px"
	_brush_size_lbl.add_theme_font_size_override("font_size", 13)
	_brush_size_lbl.add_theme_color_override("font_color", GOLD_LIGHT)
	sz_row.add_child(_brush_size_lbl)
	vbox.add_child(sz_row)

	_brush_slider = HSlider.new()
	_brush_slider.min_value = 2.0
	_brush_slider.max_value = 60.0
	_brush_slider.step = 1.0
	_brush_slider.value = 12.0
	_brush_slider.focus_mode = Control.FOCUS_NONE
	_brush_slider.value_changed.connect(func(v: float):
		_brush_size_lbl.text = "%d px" % int(roundf(v))
		if _surface:
			_surface.brush_radius = v
	)
	vbox.add_child(_brush_slider)

	# Color Wheel & Brightness
	vbox.add_child(_make_section_heading("COLOR WHEEL"))
	var wheel_center := CenterContainer.new()
	_wheel = ColorWheelControlScript.new()
	_wheel.color_changed.connect(func(col: Color):
		_set_active_color(col, true)
	)
	wheel_center.add_child(_wheel)
	vbox.add_child(wheel_center)

	var val_row := HBoxContainer.new()
	val_row.add_theme_constant_override("separation", 6)
	var val_lbl := Label.new()
	val_lbl.text = "Bright"
	val_lbl.custom_minimum_size = Vector2(46, 0)
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	val_row.add_child(val_lbl)

	_val_slider = HSlider.new()
	_val_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_val_slider.min_value = 0.0
	_val_slider.max_value = 1.0
	_val_slider.step = 0.01
	_val_slider.value = 0.15
	_val_slider.focus_mode = Control.FOCUS_NONE
	_val_slider.value_changed.connect(func(v: float):
		if _syncing_color:
			return
		_wheel.set_value_silent(v)
		_set_active_color(_wheel.get_color(), true)
	)
	val_row.add_child(_val_slider)
	vbox.add_child(val_row)

	# RGB Sliders + Active Swatch / Hex
	var rgb_hdr_row := HBoxContainer.new()
	rgb_hdr_row.add_theme_constant_override("separation", 8)
	var rgb_title := _make_section_heading("RGB & HEX")
	rgb_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rgb_hdr_row.add_child(rgb_title)
	_hex_label = Label.new()
	_hex_label.text = "#1A1714"
	_hex_label.add_theme_font_size_override("font_size", 12)
	_hex_label.add_theme_color_override("font_color", GOLD_LIGHT)
	rgb_hdr_row.add_child(_hex_label)

	var swatch_border := PanelContainer.new()
	swatch_border.add_theme_stylebox_override("panel", UIStyle.create_card_style(Color.BLACK, GOLD_LIGHT, 1))
	_color_swatch_preview = ColorRect.new()
	_color_swatch_preview.custom_minimum_size = Vector2(28, 18)
	swatch_border.add_child(_color_swatch_preview)
	rgb_hdr_row.add_child(swatch_border)
	vbox.add_child(rgb_hdr_row)

	var ch_names := ["R", "G", "B"]
	var ch_cols := [Color("#FF7875"), Color("#8CE69B"), Color("#7EC8FF")]
	_rgb_sliders.clear()
	_rgb_spins.clear()
	for ci in range(3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var clbl := Label.new()
		clbl.text = ch_names[ci]
		clbl.custom_minimum_size = Vector2(14, 0)
		clbl.add_theme_font_size_override("font_size", 13)
		clbl.add_theme_color_override("font_color", ch_cols[ci])
		row.add_child(clbl)

		var sl := HSlider.new()
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.min_value = 0.0
		sl.max_value = 255.0
		sl.step = 1.0
		sl.focus_mode = Control.FOCUS_NONE
		sl.value_changed.connect(func(_v: float):
			_on_rgb_control_changed(false)
		)
		row.add_child(sl)
		_rgb_sliders.append(sl)

		var sp := SpinBox.new()
		sp.custom_minimum_size = Vector2(62, 0)
		sp.min_value = 0
		sp.max_value = 255
		sp.step = 1
		sp.value_changed.connect(func(_v: float):
			_on_rgb_control_changed(true)
		)
		row.add_child(sp)
		_rgb_spins.append(sp)
		vbox.add_child(row)

	# Basic Palette Swatches
	vbox.add_child(_make_section_heading("BASIC SWATCHES"))
	var basic_grid := GridContainer.new()
	basic_grid.columns = 6
	basic_grid.add_theme_constant_override("h_separation", 5)
	basic_grid.add_theme_constant_override("v_separation", 5)
	for sw_col in BASIC_SWATCHES:
		basic_grid.add_child(_create_color_swatch_button(sw_col))
	vbox.add_child(basic_grid)

	# Saved / Recent Colors
	var rec_row := HBoxContainer.new()
	var rec_hdr := _make_section_heading("SAVED / RECENT")
	rec_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_row.add_child(rec_hdr)
	var save_col_btn := Button.new()
	save_col_btn.text = "+ Save"
	save_col_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(save_col_btn, CARD_DARK, GOLD_LIGHT, 11.0, 4)
	save_col_btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_push_recent_color(_active_color)
	)
	rec_row.add_child(save_col_btn)
	vbox.add_child(rec_row)

	_recent_colors_grid = GridContainer.new()
	_recent_colors_grid.columns = 6
	_recent_colors_grid.add_theme_constant_override("h_separation", 5)
	_recent_colors_grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(_recent_colors_grid)

	return panel


func _build_center_canvas_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIStyle.create_card_style(Color(0.09, 0.085, 0.078, 1.0), Color(0.28, 0.23, 0.16, 1.0), 1))

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_surface = CanvasDrawSurfaceScript.new()
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_surface)

	var hint_lbl := Label.new()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.text = "Paint on the white board • Click products on the right to add Stickers • Select Sticker: drag to move, Scroll to scale, Q/E to rotate"
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68, 0.78))
	var hint_m := MarginContainer.new()
	hint_m.add_theme_constant_override("margin_bottom", 6)
	hint_m.add_child(hint_lbl)
	vbox.add_child(hint_m)

	return panel


func _build_right_stickers_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(292, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.create_card_style(PANEL_DARK, Color(0.32, 0.26, 0.18, 1.0), 1))

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(_make_section_heading("PRODUCT STICKERS"))
	var sub := Label.new()
	sub.text = "Tap any unlocked item to stamp it as a movable sticker."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.90, 0.85, 0.76, 0.82))
	vbox.add_child(sub)

	if _slot_name == "poster":
		_promo_tracker_panel = PanelContainer.new()
		_promo_tracker_panel.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.18, 0.14, 0.09, 0.95), 6, 8, 6))
		_promo_tracker_box = VBoxContainer.new()
		_promo_tracker_box.add_theme_constant_override("separation", 3)
		_promo_tracker_panel.add_child(_promo_tracker_box)
		vbox.add_child(_promo_tracker_panel)

	_cat_tabs_row = HFlowContainer.new()
	_cat_tabs_row.add_theme_constant_override("h_separation", 4)
	_cat_tabs_row.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_cat_tabs_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_sticker_grid = GridContainer.new()
	_sticker_grid.columns = 3
	_sticker_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sticker_grid.add_theme_constant_override("h_separation", 6)
	_sticker_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_sticker_grid)

	# Selected Sticker quick transform controls
	_sticker_edit_bar = PanelContainer.new()
	_sticker_edit_bar.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(CARD_DARK, 6, 8, 8))
	var edit_vbox := VBoxContainer.new()
	edit_vbox.add_theme_constant_override("separation", 6)
	_sticker_edit_bar.add_child(edit_vbox)

	_sticker_edit_title = Label.new()
	_sticker_edit_title.text = "No sticker selected"
	_sticker_edit_title.add_theme_font_size_override("font_size", 12)
	_sticker_edit_title.add_theme_color_override("font_color", GOLD_LIGHT)
	edit_vbox.add_child(_sticker_edit_title)

	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 4)
	edit_vbox.add_child(edit_row)

	_sticker_action_btns.clear()
	var actions := [
		["Size-", func(): _surface.adjust_selected_scale(-0.12)],
		["Size+", func(): _surface.adjust_selected_scale(0.12)],
		["↺15°", func(): _surface.adjust_selected_rotation(-15.0)],
		["↻15°", func(): _surface.adjust_selected_rotation(15.0)],
		["Top", func(): _surface.bring_selected_to_front()],
		["Del", func(): _surface.delete_selected_sticker()],
	]
	for act in actions:
		var abtn := Button.new()
		abtn.text = str(act[0])
		abtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		abtn.focus_mode = Control.FOCUS_NONE
		var is_del := str(act[0]) == "Del"
		UIStyle.style_button(abtn, UIStyle.COLOR_CANCEL if is_del else Color(0.24, 0.21, 0.17, 1.0), Color.WHITE if is_del else GOLD_TEXT, 11.0, 4)
		var cb: Callable = act[1]
		abtn.pressed.connect(func():
			AudioManager.play_sfx("interact")
			cb.call()
		)
		_sticker_action_btns.append(abtn)
		edit_row.add_child(abtn)

	vbox.add_child(_sticker_edit_bar)
	return panel


func _make_section_heading(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GOLD_LIGHT)
	return lbl


func _make_badge_label(txt: String, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(bg, 6, 8, 3))
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", fg)
	p.add_child(l)
	return p


func _create_color_swatch_button(col: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(36, 26)
	btn.focus_mode = Control.FOCUS_NONE
	var st := UIStyle.create_card_style(col, Color(0.45, 0.38, 0.30, 1.0), 1)
	st.set_corner_radius_all(4)
	var h_st := st.duplicate() as StyleBoxFlat
	h_st.border_color = GOLD_LIGHT
	h_st.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", h_st)
	btn.add_theme_stylebox_override("pressed", h_st)
	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_set_active_color(col, true)
		if _surface and _surface.active_tool == CanvasDrawSurfaceScript.Tool.ERASER:
			_set_tool(CanvasDrawSurfaceScript.Tool.BRUSH)
	)
	return btn


func _set_tool(t: int) -> void:
	if _surface:
		_surface.active_tool = t
	for k in _tool_buttons.keys():
		var btn: Button = _tool_buttons[k]
		if int(k) == t:
			UIStyle.style_button(btn, GOLD_ACCENT, Color(0.10, 0.08, 0.06, 1.0), 12.0, 5)
		else:
			UIStyle.style_button(btn, CARD_DARK, GOLD_TEXT, 12.0, 5)


func _set_active_color(col: Color, update_wheel: bool) -> void:
	_active_color = Color(col.r, col.g, col.b, 1.0)
	if _surface:
		_surface.brush_color = _active_color
	_syncing_color = true
	if _color_swatch_preview:
		_color_swatch_preview.color = _active_color
	if _hex_label:
		_hex_label.text = "#" + _active_color.to_html(false).to_upper()
	if _val_slider:
		_val_slider.value = _active_color.v
	if update_wheel and _wheel:
		_wheel.set_color_silent(_active_color)
	var comps := [int(roundf(_active_color.r * 255.0)), int(roundf(_active_color.g * 255.0)), int(roundf(_active_color.b * 255.0))]
	for i in range(3):
		if i < _rgb_sliders.size():
			_rgb_sliders[i].value = float(comps[i])
		if i < _rgb_spins.size():
			_rgb_spins[i].value = float(comps[i])
	_syncing_color = false


func _on_rgb_control_changed(from_spin: bool) -> void:
	if _syncing_color:
		return
	var r := (_rgb_spins[0].value if from_spin else _rgb_sliders[0].value) / 255.0
	var g := (_rgb_spins[1].value if from_spin else _rgb_sliders[1].value) / 255.0
	var b := (_rgb_spins[2].value if from_spin else _rgb_sliders[2].value) / 255.0
	_set_active_color(Color(r, g, b, 1.0), true)


func _on_stroke_committed(col: Color) -> void:
	_push_recent_color(col)


func _on_eyedropper_picked(col: Color) -> void:
	AudioManager.play_sfx("interact")
	_set_active_color(col, true)
	_set_tool(CanvasDrawSurfaceScript.Tool.BRUSH)


func _push_recent_color(col: Color) -> void:
	var hex := "#" + Color(col.r, col.g, col.b, 1.0).to_html(false).to_upper()
	_recent_colors.erase(hex)
	_recent_colors.push_front(hex)
	if _recent_colors.size() > 12:
		_recent_colors.resize(12)
	_refresh_recent_colors()


func _refresh_recent_colors() -> void:
	if not is_instance_valid(_recent_colors_grid):
		return
	for ch in _recent_colors_grid.get_children():
		ch.queue_free()
	if _recent_colors.is_empty():
		var empty := Label.new()
		empty.text = "Colors you use appear here."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62, 0.65))
		_recent_colors_grid.add_child(empty)
		return
	for hex in _recent_colors:
		_recent_colors_grid.add_child(_create_color_swatch_button(Color(hex)))


func _get_unlocked_sellable_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item and item.can_be_sold and item.tier <= StoryManager.current_tier:
			out.append(item)
	return out


func _refresh_sticker_palette() -> void:
	var unlocked := _get_unlocked_sellable_items()
	var cat_set := {}
	for it in unlocked:
		cat_set[it.category] = true

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
			if _selected_sticker_category != "all" and item.category != _selected_sticker_category:
				continue
			_sticker_grid.add_child(_create_sticker_card(item))


func _create_sticker_card(item: ItemData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(78, 74)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "%s (%s)" % [item.item_name, StoryManager.get_category_display_name(item.category)]
	UIStyle.style_button(btn, CARD_DARK, GOLD_TEXT, 11.0, 6)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	btn.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.texture:
		icon.texture = item.texture
	vbox.add_child(icon)

	var lbl := Label.new()
	lbl.text = item.item_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", GOLD_TEXT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	btn.pressed.connect(func():
		AudioManager.play_sfx("interact")
		_surface.add_sticker(item)
		_set_tool(CanvasDrawSurfaceScript.Tool.SELECT)
	)
	return btn


func _on_history_changed(can_u: bool, can_r: bool) -> void:
	if _undo_btn:
		_undo_btn.disabled = not can_u
	if _redo_btn:
		_redo_btn.disabled = not can_r


func _on_stickers_changed() -> void:
	_refresh_promo_status()


func _on_sticker_selection_changed(sel_idx: int) -> void:
	var has_sel := sel_idx >= 0
	for b in _sticker_action_btns:
		b.disabled = not has_sel
	if _sticker_edit_title:
		if has_sel:
			var s := _surface.get_selected_sticker()
			_sticker_edit_title.text = "Selected: %s" % str(s.get("item_name", "Sticker"))
		else:
			_sticker_edit_title.text = "No sticker selected"


func _refresh_promo_status() -> void:
	if _slot_name != "poster" or not _surface:
		return
	var counts := _surface.get_sticker_category_counts()
	var eligible: Array[String] = []
	for cat in counts.keys():
		if int(counts[cat]) >= PROMO_THRESHOLD:
			eligible.append(str(cat))

	if is_instance_valid(_promo_banner_lbl):
		if eligible.is_empty():
			_promo_banner_lbl.text = "Promo: Add 3+ matching stickers to feature a category"
		elif eligible.size() == 1:
			_promo_banner_lbl.text = "Promo Ready: ★ %s (+Demand & +₱3)" % StoryManager.get_category_display_name(eligible[0])
		else:
			_promo_banner_lbl.text = "Promo Ready: %d categories eligible (pick 1 on Save!)" % eligible.size()

	if is_instance_valid(_promo_tracker_box):
		for ch in _promo_tracker_box.get_children():
			ch.queue_free()
		var hdr := Label.new()
		hdr.text = "FEATURED CATEGORY PROMO (3+ Same Category)"
		hdr.add_theme_font_size_override("font_size", 11)
		hdr.add_theme_color_override("font_color", GOLD_LIGHT)
		_promo_tracker_box.add_child(hdr)

		if counts.is_empty():
			var hint := Label.new()
			hint.text = "Place 3+ product stickers from one category to boost its customer demand & earn +₱3 per sale!"
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 11)
			hint.add_theme_color_override("font_color", Color(0.86, 0.80, 0.70, 0.85))
			_promo_tracker_box.add_child(hint)
		else:
			var sorted_cats := counts.keys()
			sorted_cats.sort_custom(func(a, b) -> bool: return int(counts[a]) > int(counts[b]))
			for cat in sorted_cats:
				var c_cnt := int(counts[cat])
				var ready := c_cnt >= PROMO_THRESHOLD
				var row_lbl := Label.new()
				row_lbl.text = "• %s: %d / %d %s" % [
					StoryManager.get_category_display_name(str(cat)),
					c_cnt,
					PROMO_THRESHOLD,
					"★ READY!" if ready else ""
				]
				row_lbl.add_theme_font_size_override("font_size", 12)
				row_lbl.add_theme_color_override("font_color", Color("#8BF08E") if ready else GOLD_TEXT)
				_promo_tracker_box.add_child(row_lbl)


func _on_save_pressed() -> void:
	if _slot_name == "poster":
		var counts := _surface.get_sticker_category_counts()
		var eligible: Array[String] = []
		for cat in counts.keys():
			if int(counts[cat]) >= PROMO_THRESHOLD:
				eligible.append(str(cat))
		if eligible.size() >= 2:
			AudioManager.play_sfx("interact")
			_show_featured_category_modal(eligible, counts)
			return
		elif eligible.size() == 1:
			_finalize_save(eligible[0])
			return
		else:
			_finalize_save("")
			return

	_finalize_save("")


func _show_featured_category_modal(eligible: Array[String], counts: Dictionary) -> void:
	if is_instance_valid(_featured_modal):
		_featured_modal.queue_free()

	_featured_modal = Control.new()
	_featured_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_featured_modal)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_featured_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_featured_modal.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 0)
	var style := UIStyle.create_card_style(BG_DARK, GOLD_ACCENT, 2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE FEATURED CATEGORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", GOLD_LIGHT)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Your poster qualifies for multiple categories! Pick ONE Featured Category to promote on your storefront (+customer demand & +₱3 promo bonus per sale):"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", GOLD_TEXT)
	vbox.add_child(desc)

	_featured_modal_list = VBoxContainer.new()
	_featured_modal_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_featured_modal_list)

	var stickers := _surface.get_serialized_stickers()
	for cat in eligible:
		var pick_btn := Button.new()
		pick_btn.custom_minimum_size = Vector2(0, 52)
		pick_btn.focus_mode = Control.FOCUS_NONE
		UIStyle.style_button(pick_btn, CARD_DARK, GOLD_TEXT, 16.0, 8)

		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		pick_btn.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s (%d stickers)" % [StoryManager.get_category_display_name(cat), int(counts[cat])]
		lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", GOLD_LIGHT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)

		var shown_icons := 0
		for st in stickers:
			if str(st.get("category", "")) == cat and ResourceLoader.exists(str(st.get("item_path", ""))):
				var it := load(str(st.get("item_path", ""))) as ItemData
				if it and it.texture:
					var ic := TextureRect.new()
					ic.custom_minimum_size = Vector2(28, 28)
					ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					ic.texture = it.texture
					ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
					row.add_child(ic)
					shown_icons += 1
					if shown_icons >= 3:
						break

		pick_btn.pressed.connect(func():
			AudioManager.play_sfx("purchase")
			_featured_modal.queue_free()
			_finalize_save(cat)
		)
		_featured_modal_list.add_child(pick_btn)

	var back_btn := Button.new()
	back_btn.text = "Back to Edit"
	back_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(back_btn, UIStyle.COLOR_CANCEL, Color.WHITE, 14.0, 6)
	back_btn.pressed.connect(func():
		AudioManager.play_sfx("drop")
		_featured_modal.queue_free()
	)
	vbox.add_child(back_btn)


func _finalize_save(chosen_featured_cat: String) -> void:
	var paint_path := StoryManager.POSTER_PAINT_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_PAINT_PATH
	var final_path := StoryManager.POSTER_IMAGE_PATH if _slot_name == "poster" else StoryManager.SIGNAGE_IMAGE_PATH

	var paint_img := _surface.get_paint_image()
	var composited_img := _surface.render_composited_image()
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
		EventBus.show_notification.emit("Roof Signage Mounted!", "Your custom signboard is now live on your store and Main Menu!", "purchase")
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

	if event.keycode == KEY_ESCAPE and not event.echo:
		get_viewport().set_input_as_handled()
		if is_instance_valid(_featured_modal):
			_featured_modal.queue_free()
		else:
			_on_cancel_pressed()
		return

	if is_instance_valid(_featured_modal):
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

	# Don't steal keystrokes if typing in RGB SpinBoxes
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit:
		return

	if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		if _surface and _surface.get_selected_sticker_index() >= 0:
			get_viewport().set_input_as_handled()
			_surface.delete_selected_sticker()
			return

	if event.echo:
		return

	match event.keycode:
		KEY_B:
			_set_tool(CanvasDrawSurfaceScript.Tool.BRUSH)
		KEY_G:
			_set_tool(CanvasDrawSurfaceScript.Tool.BUCKET)
		KEY_I:
			_set_tool(CanvasDrawSurfaceScript.Tool.EYEDROPPER)
		KEY_V:
			_set_tool(CanvasDrawSurfaceScript.Tool.SELECT)
		KEY_Q:
			if _surface and _surface.get_selected_sticker_index() >= 0:
				_surface.adjust_selected_rotation(-15.0)
		KEY_E:
			if _surface and _surface.active_tool == CanvasDrawSurfaceScript.Tool.SELECT and _surface.get_selected_sticker_index() >= 0:
				_surface.adjust_selected_rotation(15.0)
			else:
				_set_tool(CanvasDrawSurfaceScript.Tool.ERASER)
