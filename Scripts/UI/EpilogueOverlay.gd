class_name EpilogueOverlay
extends CanvasLayer

## Modernized New Vegas-Style Epilogue Chronicle Overlay (game-ui-design compliant).
## Features 90% title-safe Espresso & Antique Gold framing, framed character portraits,
## icon+label Outcome Seals, keyboard/gamepad/mouse navigation (Left/Right/Space/Enter/Esc),
## progress dots, and a clean Endless Mode handoff.

signal completed(action: String)

const EpilogueCatalogScript = preload("res://Scripts/Progression/EpilogueCatalog.gd")

const COL_BACKDROP := Color(0.025, 0.020, 0.017, 0.94)
const COL_FRAME_BG := Color(0.062, 0.052, 0.044, 0.98)
const COL_PORTRAIT_BG := Color(0.095, 0.080, 0.068, 0.98)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.885, 0.58, 1.0)
const COL_CREAM := Color(1.0, 0.945, 0.855, 1.0)
const COL_CREAM_MUTED := Color(0.86, 0.79, 0.69, 0.86)
const COL_ALLY := Color(1.0, 0.86, 0.44, 1.0)
const COL_STEADY := Color(0.58, 0.92, 0.60, 1.0)
const COL_DISTANT := Color(0.70, 0.78, 0.88, 1.0)
const COL_UNFOLDING := Color(0.84, 0.76, 0.66, 0.85)

var _slides: Array[Dictionary] = []
var _index: int = 0
var _closing: bool = false
var _slide_tween: Tween = null

var _root: Control
var _counter_lbl: Label
var _eyebrow_lbl: Label
var _portrait_rect: TextureRect
var _portrait_frame: PanelContainer
var _seal_panel: PanelContainer
var _seal_lbl: Label
var _name_lbl: Label
var _title_lbl: Label
var _body_lbl: Label
var _stats_lbl: Label
var _content_box: HBoxContainer
var _thank_you_box: VBoxContainer
var _ty_title_lbl: Label
var _ty_sub_lbl: Label
var _ty_body_lbl: Label
var _ty_stats_row: HBoxContainer
var _ty_teaser_lbl: Label
var _menu_btn: Button
var _dots_row: HBoxContainer
var _prev_btn: Button
var _next_btn: Button
var _skip_btn: Button

var _sfx_click: AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_player: AudioStreamPlayer


func setup(custom_slides: Array[Dictionary] = []) -> void:
	if not custom_slides.is_empty():
		_slides = custom_slides
	else:
		_slides = EpilogueCatalogScript.build_chronicle_slides()


func _ready() -> void:
	layer = 66
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _slides.is_empty():
		_slides = EpilogueCatalogScript.build_chronicle_slides()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

	_build_ui()
	_render_slide(0, false)

	_root.modulate.a = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if not _closing and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT, KEY_D]:
			get_viewport().set_input_as_handled()
			_on_next_pressed()
		elif event.keycode in [KEY_LEFT, KEY_A]:
			get_viewport().set_input_as_handled()
			_on_prev_pressed()
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _index < _slides.size() - 1:
				_play_click()
				_render_slide(_slides.size() - 1, true)
			else:
				_finish_epilogue()


func _play_click() -> void:
	if is_instance_valid(_sfx_player):
		_sfx_player.stream = _sfx_click
		_sfx_player.play()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COL_BACKDROP
	_root.add_child(backdrop)

	# 90% Title-Safe Main Chronicle Frame
	var frame := PanelContainer.new()
	frame.anchor_left = 0.08
	frame.anchor_right = 0.92
	frame.anchor_top = 0.09
	frame.anchor_bottom = 0.91
	var f_st := UIStyle.create_flat_stylebox(COL_FRAME_BG, 14, 34, 26)
	f_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.88)
	f_st.set_border_width_all(2)
	f_st.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	f_st.shadow_size = 32
	frame.add_theme_stylebox_override("panel", f_st)
	_root.add_child(frame)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	frame.add_child(vb)

	# ── Header Row ────────────────────────────────────────────────────────
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	_eyebrow_lbl = Label.new()
	_eyebrow_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_eyebrow_lbl.add_theme_font_size_override("font_size", 16)
	_eyebrow_lbl.add_theme_color_override("font_color", COL_GOLD)
	hdr.add_child(_eyebrow_lbl)

	_counter_lbl = Label.new()
	_counter_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_counter_lbl.add_theme_font_size_override("font_size", 15)
	_counter_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	hdr.add_child(_counter_lbl)

	var sep_top := ColorRect.new()
	sep_top.custom_minimum_size = Vector2(0, 1)
	sep_top.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.38)
	vb.add_child(sep_top)

	# ── Main Content Split (Framed Portrait Left | Chronicle Copy Right) ──
	_content_box = HBoxContainer.new()
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 34)
	vb.add_child(_content_box)

	# Portrait Frame
	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(280, 0)
	_portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pf_st := UIStyle.create_flat_stylebox(COL_PORTRAIT_BG, 12, 16, 16)
	pf_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.72)
	pf_st.set_border_width_all(2)
	_portrait_frame.add_theme_stylebox_override("panel", pf_st)
	_content_box.add_child(_portrait_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_frame.add_child(_portrait_rect)

	# Story Column
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 12)
	_content_box.add_child(text_col)

	var seal_row := HBoxContainer.new()
	text_col.add_child(seal_row)

	_seal_panel = PanelContainer.new()
	var sp_st := UIStyle.create_flat_stylebox(Color(0.16, 0.13, 0.08, 0.96), 8, 14, 5)
	sp_st.border_color = COL_GOLD_BRIGHT
	sp_st.set_border_width_all(1)
	_seal_panel.add_theme_stylebox_override("panel", sp_st)
	seal_row.add_child(_seal_panel)

	_seal_lbl = Label.new()
	_seal_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_seal_lbl.add_theme_font_size_override("font_size", 13)
	_seal_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_seal_panel.add_child(_seal_lbl)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_name_lbl.add_theme_font_size_override("font_size", 36)
	_name_lbl.add_theme_color_override("font_color", COL_CREAM)
	text_col.add_child(_name_lbl)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	text_col.add_child(_title_lbl)

	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_body_lbl.add_theme_font_size_override("font_size", 21)
	_body_lbl.add_theme_color_override("font_color", COL_CREAM)
	_body_lbl.add_theme_constant_override("line_spacing", 6)
	text_col.add_child(_body_lbl)

	_stats_lbl = Label.new()
	_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_stats_lbl.add_theme_font_size_override("font_size", 15)
	_stats_lbl.add_theme_color_override("font_color", COL_GOLD)
	text_col.add_child(_stats_lbl)

	# ── Dedicated Centered "Thank You for Playing" View (Final Slide) ─────
	_thank_you_box = VBoxContainer.new()
	_thank_you_box.visible = false
	_thank_you_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_thank_you_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_thank_you_box.add_theme_constant_override("separation", 18)
	vb.add_child(_thank_you_box)

	_ty_title_lbl = Label.new()
	_ty_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty_title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_ty_title_lbl.add_theme_font_size_override("font_size", 46)
	_ty_title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_thank_you_box.add_child(_ty_title_lbl)

	_ty_sub_lbl = Label.new()
	_ty_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty_sub_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_ty_sub_lbl.add_theme_font_size_override("font_size", 22)
	_ty_sub_lbl.add_theme_color_override("font_color", COL_CREAM)
	_thank_you_box.add_child(_ty_sub_lbl)

	_ty_body_lbl = Label.new()
	_ty_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ty_body_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_ty_body_lbl.add_theme_font_size_override("font_size", 19)
	_ty_body_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_ty_body_lbl.add_theme_constant_override("line_spacing", 5)
	_thank_you_box.add_child(_ty_body_lbl)

	_ty_stats_row = HBoxContainer.new()
	_ty_stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_ty_stats_row.add_theme_constant_override("separation", 18)
	_thank_you_box.add_child(_ty_stats_row)

	var teaser_panel := PanelContainer.new()
	var tp_st := UIStyle.create_flat_stylebox(Color(0.10, 0.085, 0.070, 0.94), 10, 22, 14)
	tp_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.45)
	tp_st.set_border_width_all(1)
	teaser_panel.add_theme_stylebox_override("panel", tp_st)
	_thank_you_box.add_child(teaser_panel)

	_ty_teaser_lbl = Label.new()
	_ty_teaser_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ty_teaser_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ty_teaser_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_ty_teaser_lbl.add_theme_font_size_override("font_size", 16)
	_ty_teaser_lbl.add_theme_color_override("font_color", COL_CREAM)
	_ty_teaser_lbl.add_theme_constant_override("line_spacing", 4)
	teaser_panel.add_child(_ty_teaser_lbl)

	var sep_bot := ColorRect.new()
	sep_bot.custom_minimum_size = Vector2(0, 1)
	sep_bot.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.30)
	vb.add_child(sep_bot)

	# ── Footer Row (Progress Dots + Controls) ─────────────────────────────
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	vb.add_child(foot)

	_dots_row = HBoxContainer.new()
	_dots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots_row.add_theme_constant_override("separation", 6)
	foot.add_child(_dots_row)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip  [Esc]"
	_skip_btn.custom_minimum_size = Vector2(118, 42)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_skip_btn, Color(0.13, 0.11, 0.09, 0.90), COL_CREAM_MUTED, 15.0, 8)
	_skip_btn.pressed.connect(func():
		_play_click()
		_render_slide(_slides.size() - 1, true)
	)
	foot.add_child(_skip_btn)

	_prev_btn = Button.new()
	_prev_btn.text = "◀ Prev"
	_prev_btn.custom_minimum_size = Vector2(110, 42)
	_prev_btn.focus_mode = Control.FOCUS_NONE
	_prev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_prev_btn, Color(0.16, 0.13, 0.10, 0.96), COL_CREAM, 16.0, 8)
	_prev_btn.pressed.connect(_on_prev_pressed)
	foot.add_child(_prev_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "Main Menu"
	_menu_btn.visible = false
	_menu_btn.custom_minimum_size = Vector2(142, 44)
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_menu_btn, Color(0.16, 0.13, 0.10, 0.96), COL_CREAM, 16.0, 8)
	_menu_btn.pressed.connect(func():
		_play_click()
		_finish_epilogue("main_menu")
	)
	foot.add_child(_menu_btn)

	_next_btn = Button.new()
	_next_btn.text = "Next ▶"
	_next_btn.custom_minimum_size = Vector2(160, 42)
	_next_btn.focus_mode = Control.FOCUS_NONE
	_next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIStyle.style_button(_next_btn, Color(0.42, 0.31, 0.14, 0.98), COL_GOLD_BRIGHT, 17.0, 8)
	_next_btn.pressed.connect(_on_next_pressed)
	foot.add_child(_next_btn)


func _render_slide(idx: int, animate: bool) -> void:
	if _slides.is_empty():
		return
	_index = clampi(idx, 0, _slides.size() - 1)
	var s: Dictionary = _slides[_index]

	_eyebrow_lbl.text = str(s.get("eyebrow", "KARIMLAN CHRONICLE"))
	_counter_lbl.text = "Slide %d / %d" % [_index + 1, _slides.size()]

	var is_thank_you: bool = str(s.get("kind", "")) == "thank_you"
	_content_box.visible = not is_thank_you
	_thank_you_box.visible = is_thank_you

	if is_thank_you:
		_ty_title_lbl.text = str(s.get("name", "Thank You for Playing!"))
		_ty_sub_lbl.text = str(s.get("title", ""))
		_ty_body_lbl.text = str(s.get("body", ""))
		_ty_teaser_lbl.text = str(s.get("teaser", ""))
		for child in _ty_stats_row.get_children():
			child.queue_free()
		_add_stat_pill("DAYS OPEN", "Day %d" % int(s.get("day_n", 1)))
		_add_stat_pill("STORY CHAPTERS", "%d / %d" % [int(s.get("done_chapters", 0)), int(s.get("total_chapters", 66))])
		_add_stat_pill("STORIES FINISHED", "%d / %d" % [int(s.get("finished_arcs", 0)), int(s.get("total_cast", 11))])
	else:
		_name_lbl.text = str(s.get("name", ""))
		_title_lbl.text = str(s.get("title", ""))
		_body_lbl.text = str(s.get("body", ""))

		var stats_txt := str(s.get("stats_line", ""))
		_stats_lbl.text = stats_txt
		_stats_lbl.visible = not stats_txt.is_empty()

		var pkey := str(s.get("portrait_key", "reynamayari"))
		var tex: Texture2D = UIStyle.get_customer_portrait(pkey)
		_portrait_rect.texture = tex
		_portrait_frame.visible = tex != null

		# Style Outcome Seal color by tier
		var tier := str(s.get("tier", "unfolding"))
		var seal_col := COL_UNFOLDING
		var seal_icon := "◇ "
		match tier:
			"ally":
				seal_col = COL_ALLY
				seal_icon = "★ "
			"steady":
				seal_col = COL_STEADY
				seal_icon = "◆ "
			"distant":
				seal_col = COL_DISTANT
				seal_icon = "○ "
		_seal_lbl.text = seal_icon + str(s.get("seal", ""))
		_seal_lbl.add_theme_color_override("font_color", seal_col)
		var sp_st := _seal_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sp_st:
			sp_st.border_color = seal_col

	# Update buttons
	var is_last := (_index >= _slides.size() - 1)
	_prev_btn.disabled = (_index == 0)
	_skip_btn.visible = not is_last
	_menu_btn.visible = is_last
	if is_last:
		_next_btn.text = "Keep the Shutters Open"
		_next_btn.custom_minimum_size = Vector2(246, 44)
	else:
		_next_btn.text = "Next  [Space]"
		_next_btn.custom_minimum_size = Vector2(168, 42)

	# Rebuild progress dots
	for child in _dots_row.get_children():
		child.queue_free()
	for i in range(_slides.size()):
		var dot := Label.new()
		dot.text = "●" if i == _index else ("•" if i < _index else "○")
		dot.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
		dot.add_theme_font_size_override("font_size", 16 if i == _index else 13)
		dot.add_theme_color_override("font_color", COL_GOLD_BRIGHT if i == _index else Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.45))
		_dots_row.add_child(dot)

	var active_view: Control = _thank_you_box if is_thank_you else _content_box
	if animate and is_instance_valid(active_view):
		if _slide_tween and _slide_tween.is_valid():
			_slide_tween.kill()
		active_view.modulate.a = 0.0
		_slide_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_slide_tween.tween_property(active_view, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _add_stat_pill(caption: String, val_text: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 0)
	var st := UIStyle.create_flat_stylebox(Color(0.095, 0.082, 0.070, 0.96), 10, 18, 12)
	st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.55)
	st.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", st)
	_ty_stats_row.add_child(card)

	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)

	var cap_lbl := Label.new()
	cap_lbl.text = caption
	cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	cap_lbl.add_theme_font_size_override("font_size", 12)
	cap_lbl.add_theme_color_override("font_color", COL_GOLD)
	cv.add_child(cap_lbl)

	var val_lbl := Label.new()
	val_lbl.text = val_text
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	val_lbl.add_theme_font_size_override("font_size", 24)
	val_lbl.add_theme_color_override("font_color", COL_CREAM)
	cv.add_child(val_lbl)


func _on_prev_pressed() -> void:
	if _index > 0:
		_play_click()
		_render_slide(_index - 1, true)


func _on_next_pressed() -> void:
	_play_click()
	if _index < _slides.size() - 1:
		_render_slide(_index + 1, true)
	else:
		_finish_epilogue()


func _finish_epilogue(action: String = "continue") -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		completed.emit(action)
		queue_free()
	)
