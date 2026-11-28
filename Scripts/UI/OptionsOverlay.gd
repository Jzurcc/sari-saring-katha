extends ColorRect

## Modernized, standardized Settings overlay matching Sari-Saring Katha's
## dark espresso + warm gold/yellow UI design with sidebar categories:
## Audio, Display, and Controls (grouped into Movement, Store & Pricing, Dialogue).

signal closed

@export var default_master_volume : float = 0.8
@export var default_bgm_volume    : float = 0.6
@export var default_sfx_volume    : float = 0.9
@export var default_voices_volume : float = 0.9

const SETTINGS_PATH := "user://settings.cfg"
const AccessibilityPaletteScript = preload("res://Scripts/UI/AccessibilityPalette.gd")

# Shared Sari-Saring Katha dark & warm gold palette
const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_CARD_BG := Color(0.085, 0.075, 0.065, 0.94)
const COL_SIDEBAR_BG := Color(0.068, 0.060, 0.052, 0.95)
const COL_WHITE_HDR := Color(0.98, 0.97, 0.94, 1.0)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_GOLD_LABEL := Color(0.96, 0.84, 0.52, 1.0)
const COL_CREAM_MUTED := Color(0.86, 0.78, 0.65, 0.86)
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.90)
const COL_POS := Color(0.56, 0.92, 0.52, 1.0)

const REMAPPABLE_ACTIONS := {
	"look_front": "Move Forward",
	"look_back": "Move Backward",
	"look_left": "Move Left",
	"look_right": "Move Right",
	"crouch": "Crouch",
	"sprint": "Sprint",
	"pricing_lens": "Pricing Lens",
	"toggle_ledger": "Price Ledger",
	"toggle_journal": "Folklore Journal",
	"toggle_upgrades": "Store Upgrades",
	"price_up": "Increase Price",
	"price_down": "Decrease Price",
	"dialogic_default_action": "Advance Dialogue",
	"dialogue_confirm_choice": "Confirm Choice",
}

const CONTROL_GROUPS: Array[Dictionary] = [
	{"title": "Movement", "actions": ["look_front", "look_back", "look_left", "look_right", "crouch", "sprint"]},
	{"title": "Store & Menus", "actions": ["pricing_lens", "toggle_ledger", "toggle_journal", "toggle_upgrades", "price_up", "price_down"]},
	{"title": "Dialogue", "actions": ["dialogic_default_action", "dialogue_confirm_choice"]},
]

var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _ui_player   : AudioStreamPlayer
var _bold_font   : FontVariation

# Dynamic UI references
var _tab_buttons: Dictionary = {} # tab_id -> Button
var _tab_pages: Dictionary = {}   # tab_id -> Control
var _active_tab: String = "audio"

var _slider_master: HSlider
var _slider_bgm: HSlider
var _slider_sfx: HSlider
var _slider_voices: HSlider
var _pct_labels: Dictionary = {} # key -> Label
var _mute_bg_btn: Button
var _fs_btn: Button
var _win_btn: Button
var _vsync_btn: Button
var _minigame_tut_btn: Button
var _colorblind_btn: Button
var _cb_preview_dots: Array[Panel] = []
var _binding_buttons: Dictionary = {} # action -> Button

var _is_fullscreen: bool = true
var _mute_in_bg: bool = false
var _vsync_enabled: bool = true
var _minigame_tutorials_enabled: bool = true
var _colorblind_mode: String = "off"

var _is_remapping: bool = false
var _remapping_action: String = ""
var _remapping_button: Button = null
var _custom_bindings: Dictionary = {}


func _ready() -> void:
	# Clear legacy OptionsOverlay.tscn children cleanly so we render the modernized UI
	for ch in get_children():
		ch.queue_free()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(0.030, 0.024, 0.020, 0.80)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)

	_ensure_actions_initialized()
	_build_ui()
	_load_settings()
	_select_tab("audio", false)
	_update_all_binding_buttons()


func _build_ui() -> void:
	# Click dimmed backdrop outside frame to close
	gui_input.connect(func(ev: InputEvent):
		if not _is_remapping and ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close()
	)

	# ── TOP HEADER BANNER ──
	var banner := PanelContainer.new()
	banner.anchor_left = 0.17
	banner.anchor_right = 0.83
	banner.anchor_top = 0.042
	banner.anchor_bottom = 0.146
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	var b_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_DEEP, 8, 28, 10)
	b_style.border_color = COL_GOLD
	b_style.set_border_width_all(2)
	b_style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	b_style.shadow_size = 16
	banner.add_theme_stylebox_override("panel", b_style)
	add_child(banner)

	var b_hbox := HBoxContainer.new()
	b_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(b_hbox)

	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(44, 0)
	b_hbox.add_child(left_pad)

	var bv := VBoxContainer.new()
	bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 2)
	b_hbox.add_child(bv)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 14)
	bv.add_child(title_row)

	for s_orn in ["◈", "Settings", "◈"]:
		var lbl := Label.new()
		lbl.text = s_orn
		if s_orn == "◈":
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", COL_GOLD)
		else:
			lbl.add_theme_font_override("font", _bold_font)
			lbl.add_theme_font_size_override("font_size", 30)
			lbl.add_theme_color_override("font_color", COL_WHITE_HDR)
			lbl.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
			lbl.add_theme_constant_override("outline_size", 3)
		title_row.add_child(lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Configure audio, display, and store keybinds"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
	bv.add_child(sub_lbl)

	var close_x := Button.new()
	close_x.text = "✕"
	close_x.custom_minimum_size = Vector2(42, 42)
	close_x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var xs := UIStyle.create_flat_stylebox(Color(0.11, 0.095, 0.082, 0.94), 10, 0, 0)
	xs.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.72)
	xs.set_border_width_all(1)
	var xh: StyleBoxFlat = xs.duplicate()
	xh.bg_color = Color(0.28, 0.14, 0.12, 0.98)
	xh.border_color = COL_GOLD_BRIGHT
	close_x.add_theme_stylebox_override("normal", xs)
	close_x.add_theme_stylebox_override("hover", xh)
	close_x.add_theme_stylebox_override("pressed", xs)
	close_x.add_theme_font_override("font", _bold_font)
	close_x.add_theme_font_size_override("font_size", 20)
	close_x.add_theme_color_override("font_color", COL_WHITE_HDR)
	close_x.pressed.connect(close)
	b_hbox.add_child(close_x)

	# ── MAIN SETTINGS FRAME ──
	var frame := PanelContainer.new()
	frame.anchor_left = 0.17
	frame.anchor_right = 0.83
	frame.anchor_top = 0.168
	frame.anchor_bottom = 0.885
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var f_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_DEEP, 10, 20, 18)
	f_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.82)
	f_style.set_border_width_all(2)
	f_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	f_style.shadow_size = 24
	frame.add_theme_stylebox_override("panel", f_style)
	add_child(frame)

	var frame_vbox := VBoxContainer.new()
	frame_vbox.add_theme_constant_override("separation", 14)
	frame.add_child(frame_vbox)

	# Body: Left Category Sidebar + Right Active Page
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 18)
	frame_vbox.add_child(body_hbox)

	# Left Sidebar
	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(210, 0)
	sidebar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_style := UIStyle.create_flat_stylebox(COL_SIDEBAR_BG, 8, 12, 12)
	sb_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.40)
	sb_style.set_border_width_all(1)
	sidebar_panel.add_theme_stylebox_override("panel", sb_style)
	body_hbox.add_child(sidebar_panel)

	var sb_vbox := VBoxContainer.new()
	sb_vbox.add_theme_constant_override("separation", 8)
	sidebar_panel.add_child(sb_vbox)

	var nav_hdr := Label.new()
	nav_hdr.text = "Categories"
	nav_hdr.add_theme_font_override("font", _bold_font)
	nav_hdr.add_theme_font_size_override("font_size", 15)
	nav_hdr.add_theme_color_override("font_color", COL_CREAM_MUTED)
	sb_vbox.add_child(nav_hdr)

	var tabs: Array[Dictionary] = [
		{"id": "audio", "label": "Audio"},
		{"id": "display", "label": "Display"},
		{"id": "controls", "label": "Controls"},
	]
	for t in tabs:
		var tbtn := Button.new()
		tbtn.text = str(t["label"])
		tbtn.custom_minimum_size = Vector2(0, 48)
		tbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tbtn.focus_mode = Control.FOCUS_NONE
		tbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tbtn.add_theme_font_override("font", _bold_font)
		tbtn.add_theme_font_size_override("font_size", 19)
		tbtn.pressed.connect(_select_tab.bind(str(t["id"]), true))
		sb_vbox.add_child(tbtn)
		_tab_buttons[str(t["id"])] = tbtn

	# Right Content Scroll Area
	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cp_style := UIStyle.create_flat_stylebox(COL_CARD_BG, 8, 22, 16)
	cp_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.42)
	cp_style.border_width_left = 4
	cp_style.border_width_top = 1
	cp_style.border_width_right = 1
	cp_style.border_width_bottom = 1
	content_panel.add_theme_stylebox_override("panel", cp_style)
	body_hbox.add_child(content_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_panel.add_child(scroll)

	var pages_holder := VBoxContainer.new()
	pages_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages_holder)

	_tab_pages["audio"] = _build_audio_page()
	_tab_pages["display"] = _build_display_page()
	_tab_pages["controls"] = _build_controls_page()
	for k in _tab_pages.keys():
		var pg: Control = _tab_pages[k]
		pg.visible = false
		pages_holder.add_child(pg)

	# Bottom Footer Bar
	var footer_sep := ColorRect.new()
	footer_sep.custom_minimum_size = Vector2(0, 1)
	footer_sep.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.30)
	frame_vbox.add_child(footer_sep)

	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	frame_vbox.add_child(footer_hbox)

	var auto_lbl := Label.new()
	auto_lbl.text = "Changes apply immediately and are saved automatically."
	auto_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	auto_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	auto_lbl.add_theme_font_size_override("font_size", 14)
	auto_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	footer_hbox.add_child(auto_lbl)

	var done_btn := Button.new()
	done_btn.text = "Save & Close"
	done_btn.custom_minimum_size = Vector2(180, 44)
	done_btn.focus_mode = Control.FOCUS_NONE
	done_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ds := UIStyle.create_flat_stylebox(Color(0.38, 0.29, 0.14, 0.98), 8, 18, 8)
	ds.border_color = COL_GOLD_BRIGHT
	ds.set_border_width_all(2)
	var dh: StyleBoxFlat = ds.duplicate()
	dh.bg_color = Color(0.48, 0.37, 0.18, 0.98)
	dh.border_color = COL_WHITE_HDR
	done_btn.add_theme_stylebox_override("normal", ds)
	done_btn.add_theme_stylebox_override("hover", dh)
	done_btn.add_theme_stylebox_override("pressed", ds)
	done_btn.add_theme_font_override("font", _bold_font)
	done_btn.add_theme_font_size_override("font_size", 18)
	done_btn.add_theme_color_override("font_color", COL_WHITE_HDR)
	done_btn.pressed.connect(close)
	footer_hbox.add_child(done_btn)


func _make_section_header(title: String, desc: String = "") -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 21)
	lbl.add_theme_color_override("font_color", COL_WHITE_HDR)
	vb.add_child(lbl)
	if desc != "":
		var dl := Label.new()
		dl.text = desc
		dl.add_theme_font_override("font", UIStyle.FONT_INDER)
		dl.add_theme_font_size_override("font_size", 14)
		dl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		vb.add_child(dl)
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.28)
	vb.add_child(sep)
	return vb


func _make_volume_row(key: String, label_txt: String, default_val: float, cb: Callable) -> Array:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_constant_override("separation", 16)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var track_bg := UIStyle.create_flat_stylebox(Color(0.04, 0.035, 0.03, 0.96), 5, 0, 4)
	track_bg.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.45)
	track_bg.set_border_width_all(1)
	var fill_bg := UIStyle.create_flat_stylebox(COL_GOLD_BRIGHT, 5, 0, 4)
	var fill_hl := UIStyle.create_flat_stylebox(Color(1.0, 0.93, 0.72, 1.0), 5, 0, 4)
	slider.add_theme_stylebox_override("slider", track_bg)
	slider.add_theme_stylebox_override("grabber_area", fill_bg)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hl)
	row.add_child(slider)

	var pct := Label.new()
	pct.custom_minimum_size = Vector2(56, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.text = "%d%%" % int(roundf(default_val * 100.0))
	pct.add_theme_font_override("font", _bold_font)
	pct.add_theme_font_size_override("font_size", 18)
	pct.add_theme_color_override("font_color", COL_WHITE_HDR)
	row.add_child(pct)
	_pct_labels[key] = pct

	slider.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(roundf(v * 100.0))
		cb.call(v)
	)
	slider.drag_ended.connect(func(_vc: bool): _play_confirm())
	return [row, slider]


func _build_audio_page() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 14)

	vb.add_child(_make_section_header("Volume Mixer", "Balance overall sound, background music, effects, and character voices."))

	var m := _make_volume_row("master", "Master Volume", default_master_volume, _on_master_changed)
	_slider_master = m[1]
	vb.add_child(m[0])

	var b := _make_volume_row("bgm", "Music (BGM)", default_bgm_volume, _on_bgm_changed)
	_slider_bgm = b[1]
	vb.add_child(b[0])

	var s := _make_volume_row("sfx", "Sound Effects", default_sfx_volume, _on_sfx_changed)
	_slider_sfx = s[1]
	vb.add_child(s[0])

	var v := _make_volume_row("voices", "Voices & Dialogue", default_voices_volume, _on_voices_changed)
	_slider_voices = v[1]
	vb.add_child(v[0])

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sp)

	vb.add_child(_make_section_header("Focus Behavior"))

	var bg_row := HBoxContainer.new()
	bg_row.custom_minimum_size = Vector2(0, 44)
	bg_row.add_theme_constant_override("separation", 12)
	vb.add_child(bg_row)

	var bg_lbl := Label.new()
	bg_lbl.text = "Mute Audio When Window Unfocused"
	bg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	bg_lbl.add_theme_font_size_override("font_size", 18)
	bg_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
	bg_row.add_child(bg_lbl)

	_mute_bg_btn = _make_toggle_pill_btn("Off")
	_mute_bg_btn.pressed.connect(func():
		_play_click()
		_mute_in_bg = not _mute_in_bg
		_sync_toggle_pill(_mute_bg_btn, _mute_in_bg, "On", "Off")
		if has_node("/root/AudioManager"):
			AudioManager.update_mute_in_background(_mute_in_bg)
	)
	bg_row.add_child(_mute_bg_btn)
	return vb


func _build_display_page() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 14)

	vb.add_child(_make_section_header("Screen & Window", "Choose how Sari-Saring Katha displays on your monitor."))

	var wm_row := HBoxContainer.new()
	wm_row.custom_minimum_size = Vector2(0, 48)
	wm_row.add_theme_constant_override("separation", 12)
	vb.add_child(wm_row)

	var wm_lbl := Label.new()
	wm_lbl.text = "Window Mode"
	wm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wm_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wm_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	wm_lbl.add_theme_font_size_override("font_size", 18)
	wm_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
	wm_row.add_child(wm_lbl)

	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 8)
	wm_row.add_child(seg)

	_fs_btn = _make_toggle_pill_btn("Fullscreen", 130)
	_fs_btn.pressed.connect(func(): _set_fullscreen(true))
	seg.add_child(_fs_btn)

	_win_btn = _make_toggle_pill_btn("Windowed", 130)
	_win_btn.pressed.connect(func(): _set_fullscreen(false))
	seg.add_child(_win_btn)

	var vs_row := HBoxContainer.new()
	vs_row.custom_minimum_size = Vector2(0, 48)
	vs_row.add_theme_constant_override("separation", 12)
	vb.add_child(vs_row)

	var vs_lbl := Label.new()
	vs_lbl.text = "Vertical Sync (VSync)"
	vs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	vs_lbl.add_theme_font_size_override("font_size", 18)
	vs_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
	vs_row.add_child(vs_lbl)

	_vsync_btn = _make_toggle_pill_btn("On")
	_vsync_btn.pressed.connect(func():
		_play_click()
		_vsync_enabled = not _vsync_enabled
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED)
		_sync_toggle_pill(_vsync_btn, _vsync_enabled, "On", "Off")
		_save_settings()
	)
	vs_row.add_child(_vsync_btn)

	var mt_row := HBoxContainer.new()
	mt_row.custom_minimum_size = Vector2(0, 48)
	mt_row.add_theme_constant_override("separation", 12)
	vb.add_child(mt_row)

	var mt_lbl := Label.new()
	mt_lbl.text = "Minigame Tutorials"
	mt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mt_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	mt_lbl.add_theme_font_size_override("font_size", 18)
	mt_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
	mt_row.add_child(mt_lbl)

	_minigame_tut_btn = _make_toggle_pill_btn("On")
	_minigame_tut_btn.pressed.connect(func():
		_play_click()
		_minigame_tutorials_enabled = not _minigame_tutorials_enabled
		_sync_toggle_pill(_minigame_tut_btn, _minigame_tutorials_enabled, "On", "Off")
		_save_settings()
	)
	mt_row.add_child(_minigame_tut_btn)

	var cb_sp := Control.new()
	cb_sp.custom_minimum_size = Vector2(0, 6)
	vb.add_child(cb_sp)

	vb.add_child(_make_section_header("Accessibility", "Adapt Talisman inks, Price Lens gauges, and HUD indicators for color vision."))

	var cb_row := HBoxContainer.new()
	cb_row.custom_minimum_size = Vector2(0, 48)
	cb_row.add_theme_constant_override("separation", 12)
	vb.add_child(cb_row)

	var cb_lbl := Label.new()
	cb_lbl.text = "Colorblind Mode"
	cb_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cb_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	cb_lbl.add_theme_font_size_override("font_size", 18)
	cb_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
	cb_row.add_child(cb_lbl)

	var cb_preview := HBoxContainer.new()
	cb_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	cb_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cb_preview.add_theme_constant_override("separation", 5)
	cb_row.add_child(cb_preview)
	_cb_preview_dots.clear()
	for _i in range(4):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dst := StyleBoxFlat.new()
		dst.set_corner_radius_all(99)
		dst.border_color = Color(0.95, 0.90, 0.80, 0.55)
		dst.set_border_width_all(1)
		dot.add_theme_stylebox_override("panel", dst)
		cb_preview.add_child(dot)
		_cb_preview_dots.append(dot)

	_colorblind_btn = _make_toggle_pill_btn("Off", 148)
	_colorblind_btn.pressed.connect(func():
		_play_click()
		_colorblind_mode = AccessibilityPaletteScript.next_mode(_colorblind_mode)
		AccessibilityPaletteScript.set_mode(_colorblind_mode)
		_sync_colorblind_ui()
		_save_settings()
	)
	cb_row.add_child(_colorblind_btn)
	_sync_colorblind_ui()
	return vb


func _sync_colorblind_ui() -> void:
	if is_instance_valid(_colorblind_btn):
		var is_on := _colorblind_mode != "off"
		var lbl := AccessibilityPaletteScript.get_mode_label(_colorblind_mode)
		_sync_toggle_pill(_colorblind_btn, is_on, lbl, lbl)
	var swatches := AccessibilityPaletteScript.get_talisman_swatches()
	for i in range(mini(_cb_preview_dots.size(), swatches.size())):
		var dot := _cb_preview_dots[i]
		if is_instance_valid(dot):
			var st := dot.get_theme_stylebox("panel") as StyleBoxFlat
			if st:
				st.bg_color = swatches[i]["color"]


func _build_controls_page() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 14)

	var top_bar := HBoxContainer.new()
	vb.add_child(top_bar)

	var hdr_wrap := VBoxContainer.new()
	hdr_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_wrap.add_theme_constant_override("separation", 2)
	var h_lbl := Label.new()
	h_lbl.text = "Keybindings"
	h_lbl.add_theme_font_override("font", _bold_font)
	h_lbl.add_theme_font_size_override("font_size", 21)
	h_lbl.add_theme_color_override("font_color", COL_WHITE_HDR)
	hdr_wrap.add_child(h_lbl)
	var h_sub := Label.new()
	h_sub.text = "Click any keycap to rebind, or press Esc to cancel."
	h_sub.add_theme_font_override("font", UIStyle.FONT_INDER)
	h_sub.add_theme_font_size_override("font_size", 14)
	h_sub.add_theme_color_override("font_color", COL_CREAM_MUTED)
	hdr_wrap.add_child(h_sub)
	top_bar.add_child(hdr_wrap)

	var reset_btn := _make_toggle_pill_btn("Reset Defaults", 150)
	reset_btn.pressed.connect(_on_reset_controls_pressed)
	top_bar.add_child(reset_btn)

	for grp in CONTROL_GROUPS:
		vb.add_child(_make_section_header(str(grp["title"])))
		var actions: Array = grp["actions"]
		for act in actions:
			var action_name := str(act)
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 42)
			row.add_theme_constant_override("separation", 12)
			vb.add_child(row)

			var act_lbl := Label.new()
			act_lbl.text = str(REMAPPABLE_ACTIONS.get(action_name, action_name))
			act_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			act_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			act_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
			act_lbl.add_theme_font_size_override("font_size", 18)
			act_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
			row.add_child(act_lbl)

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(180, 38)
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.add_theme_font_override("font", _bold_font)
			btn.add_theme_font_size_override("font_size", 16)
			_apply_keycap_style(btn, false)
			btn.pressed.connect(_start_remapping.bind(action_name, btn))
			row.add_child(btn)
			_binding_buttons[action_name] = btn

	return vb


func _make_toggle_pill_btn(txt: String, min_w: float = 104.0) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(min_w, 38)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", 16)
	_apply_keycap_style(btn, false)
	return btn


func _apply_keycap_style(btn: Button, active: bool) -> void:
	var bg := Color(0.36, 0.28, 0.14, 0.98) if active else Color(0.11, 0.095, 0.082, 0.95)
	var border := COL_GOLD_BRIGHT if active else Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.52)
	var st := UIStyle.create_flat_stylebox(bg, 8, 14, 6)
	st.border_color = border
	st.set_border_width_all(2 if active else 1)
	var hov: StyleBoxFlat = st.duplicate()
	hov.bg_color = bg.lightened(0.10)
	hov.border_color = COL_GOLD_BRIGHT
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_color_override("font_color", COL_WHITE_HDR if active else COL_GOLD_BRIGHT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


func _sync_toggle_pill(btn: Button, is_on: bool, on_txt: String, off_txt: String) -> void:
	if not is_instance_valid(btn):
		return
	btn.text = on_txt if is_on else off_txt
	_apply_keycap_style(btn, is_on)


func _select_tab(tab_id: String, with_sfx: bool = true) -> void:
	if with_sfx:
		_play_click()
	_active_tab = tab_id
	for k in _tab_pages.keys():
		(_tab_pages[k] as Control).visible = (k == tab_id)
	for k in _tab_buttons.keys():
		var btn: Button = _tab_buttons[k]
		var is_sel: bool = (str(k) == tab_id)
		var st := UIStyle.create_flat_stylebox(
			Color(0.28, 0.21, 0.11, 0.96) if is_sel else Color(0.09, 0.08, 0.07, 0.65),
			8, 16, 8
		)
		st.border_color = COL_GOLD_BRIGHT if is_sel else Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.22)
		st.border_width_left = 4 if is_sel else 1
		st.border_width_top = 1
		st.border_width_right = 1
		st.border_width_bottom = 1
		var hov: StyleBoxFlat = st.duplicate()
		hov.bg_color = Color(0.22, 0.17, 0.10, 0.92)
		hov.border_color = COL_GOLD
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", hov)
		btn.add_theme_stylebox_override("pressed", st)
		btn.add_theme_color_override("font_color", COL_WHITE_HDR if is_sel else COL_GOLD_LABEL)
		btn.add_theme_color_override("font_hover_color", COL_WHITE_HDR)


func _set_fullscreen(enable_fs: bool) -> void:
	_play_click()
	_is_fullscreen = enable_fs
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_sync_display_buttons()


func _sync_display_buttons() -> void:
	_apply_keycap_style(_fs_btn, _is_fullscreen)
	_apply_keycap_style(_win_btn, not _is_fullscreen)
	_sync_toggle_pill(_vsync_btn, _vsync_enabled, "On", "Off")
	_sync_toggle_pill(_mute_bg_btn, _mute_in_bg, "On", "Off")


func _ensure_actions_initialized() -> void:
	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_set_default_for_action(action)

	if InputMap.has_action("dialogic_default_action"):
		var events = InputMap.action_get_events("dialogic_default_action")
		var space_idx = -1
		for i in range(events.size()):
			if events[i] is InputEventKey and (events[i].physical_keycode == KEY_SPACE or events[i].keycode == KEY_SPACE):
				space_idx = i
				break
		if space_idx > 0:
			var space_event = events[space_idx]
			events.remove_at(space_idx)
			events.insert(0, space_event)
			InputMap.action_erase_events("dialogic_default_action")
			for e in events:
				InputMap.action_add_event("dialogic_default_action", e)


func _set_default_for_action(action: String) -> void:
	var events: Array[InputEvent] = []
	match action:
		"look_front":
			var e = InputEventKey.new(); e.physical_keycode = KEY_W; events.append(e)
		"look_back":
			var e = InputEventKey.new(); e.physical_keycode = KEY_S; events.append(e)
		"look_left":
			var e = InputEventKey.new(); e.physical_keycode = KEY_A; events.append(e)
		"look_right":
			var e = InputEventKey.new(); e.physical_keycode = KEY_D; events.append(e)
		"crouch":
			var e = InputEventKey.new(); e.physical_keycode = KEY_CTRL; events.append(e)
		"sprint":
			var e = InputEventKey.new(); e.physical_keycode = KEY_SHIFT; events.append(e)
		"pricing_lens":
			var e = InputEventKey.new(); e.physical_keycode = KEY_ALT; events.append(e)
		"toggle_ledger":
			var e = InputEventKey.new(); e.physical_keycode = KEY_L; events.append(e)
		"toggle_journal":
			var e = InputEventKey.new(); e.physical_keycode = KEY_J; events.append(e)
		"toggle_upgrades":
			var e = InputEventKey.new(); e.physical_keycode = KEY_U; events.append(e)
		"price_up":
			var e1 = InputEventKey.new(); e1.physical_keycode = KEY_PERIOD; events.append(e1)
			var e2 = InputEventMouseButton.new(); e2.button_index = MOUSE_BUTTON_WHEEL_UP; events.append(e2)
		"price_down":
			var e1 = InputEventKey.new(); e1.physical_keycode = KEY_COMMA; events.append(e1)
			var e2 = InputEventMouseButton.new(); e2.button_index = MOUSE_BUTTON_WHEEL_DOWN; events.append(e2)
		"dialogic_default_action":
			var e1 = InputEventKey.new(); e1.physical_keycode = KEY_SPACE; events.append(e1)
			var e2 = InputEventKey.new(); e2.physical_keycode = KEY_ENTER; events.append(e2)
			var e3 = InputEventMouseButton.new(); e3.button_index = MOUSE_BUTTON_LEFT; events.append(e3)
		"dialogue_confirm_choice":
			var e1 = InputEventKey.new(); e1.physical_keycode = KEY_F; events.append(e1)

	for e in events:
		InputMap.action_add_event(action, e)


func _on_reset_controls_pressed() -> void:
	_play_confirm()
	_custom_bindings.clear()
	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		_set_default_for_action(action)
	_save_settings()
	_update_all_binding_buttons()
	EventBus.keybinds_changed.emit()


func close() -> void:
	_stop_remapping()
	_play_confirm()
	_save_settings()
	hide()
	closed.emit()


func open() -> void:
	show()
	_ensure_actions_initialized()
	_load_settings()
	_sync_display_buttons()
	_update_all_binding_buttons()


func _play_click() -> void:
	if is_instance_valid(_ui_player):
		_ui_player.stream = _sfx_click
		_ui_player.play()


func _play_confirm() -> void:
	if is_instance_valid(_ui_player):
		_ui_player.stream = _sfx_confirm
		_ui_player.play()


func _set_audio_bus_volume(bus_name: String, value: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)


func _on_master_changed(value: float) -> void:
	_set_audio_bus_volume("Master", value)
	if has_node("/root/AudioManager"):
		AudioManager.update_master_muted_by_user(value <= 0.0)


func _on_bgm_changed(value: float) -> void:
	_set_audio_bus_volume("Music", value)


func _on_sfx_changed(value: float) -> void:
	_set_audio_bus_volume("SFX", value)


func _on_voices_changed(value: float) -> void:
	_set_audio_bus_volume("Voices", value)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if not _is_remapping:
		if event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return

	if not event.is_pressed():
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return

	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_stop_remapping()
		get_viewport().set_input_as_handled()
		return

	_update_binding(_remapping_action, event)
	_stop_remapping()
	get_viewport().set_input_as_handled()


func _start_remapping(action: String, button: Button) -> void:
	if _is_remapping:
		_stop_remapping()
	_is_remapping = true
	_remapping_action = action
	_remapping_button = button
	_remapping_button.text = "Press any key..."
	_apply_keycap_style(_remapping_button, true)
	_play_click()


func _stop_remapping() -> void:
	_is_remapping = false
	if is_instance_valid(_remapping_button):
		_apply_keycap_style(_remapping_button, false)
		_update_button_text(_remapping_button, _remapping_action)
		_remapping_button = null
	_remapping_action = ""


func _update_binding(action: String, event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	_custom_bindings[action] = event
	_update_input_map(action, event)
	_save_settings()
	_update_all_binding_buttons()
	EventBus.keybinds_changed.emit()


func _update_input_map(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		_set_default_for_action(action)

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event.duplicate())

	if action == "price_up":
		var wheel = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		InputMap.action_add_event(action, wheel)
	elif action == "price_down":
		var wheel = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		InputMap.action_add_event(action, wheel)


func _update_button_text(button: Button, action: String) -> void:
	if action == "":
		action = _remapping_action
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		var raw_text = events[0].as_text()
		for lbl in [" (Physical)", " (physical)", " - Physical", " - physical", " (Physical Key)"]:
			raw_text = raw_text.replace(lbl, "")
		button.text = raw_text
	else:
		button.text = "None"


func _update_all_binding_buttons() -> void:
	for action in _binding_buttons.keys():
		var btn: Button = _binding_buttons[action]
		if is_instance_valid(btn):
			_update_button_text(btn, str(action))


func _save_settings() -> void:
	var cfg = ConfigFile.new()
	if is_instance_valid(_slider_master):
		cfg.set_value("audio", "master", _slider_master.value)
	if is_instance_valid(_slider_bgm):
		cfg.set_value("audio", "bgm", _slider_bgm.value)
	if is_instance_valid(_slider_sfx):
		cfg.set_value("audio", "sfx", _slider_sfx.value)
	if is_instance_valid(_slider_voices):
		cfg.set_value("audio", "voices", _slider_voices.value)
	cfg.set_value("accessibility", "mute_in_background", _mute_in_bg)
	cfg.set_value("accessibility", "colorblind_mode", _colorblind_mode)
	cfg.set_value("display", "fullscreen", _is_fullscreen)
	cfg.set_value("display", "vsync", _vsync_enabled)
	cfg.set_value("gameplay", "minigame_tutorials", _minigame_tutorials_enabled)

	for action in _custom_bindings:
		var event = _custom_bindings[action]
		if event is InputEventKey:
			cfg.set_value("controls", action, {"type": "key", "keycode": event.keycode, "physical": event.physical_keycode})
		elif event is InputEventMouseButton:
			cfg.set_value("controls", action, {"type": "mouse", "button_index": event.button_index})

	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_on_master_changed(default_master_volume)
		_on_bgm_changed(default_bgm_volume)
		_on_sfx_changed(default_sfx_volume)
		_on_voices_changed(default_voices_volume)
		_sync_display_buttons()
		return

	if cfg.has_section("controls"):
		for action in cfg.get_section_keys("controls"):
			var data = cfg.get_value("controls", action)
			var event: InputEvent
			if data is Dictionary:
				if data.get("type") == "key":
					event = InputEventKey.new()
					event.keycode = data.get("keycode", 0)
					event.physical_keycode = data.get("physical", 0)
				elif data.get("type") == "mouse":
					event = InputEventMouseButton.new()
					event.button_index = data.get("button_index", 0)
			if event:
				_custom_bindings[action] = event
				_update_input_map(action, event)

	var master_val: float = cfg.get_value("audio", "master", default_master_volume)
	var bgm_val: float    = cfg.get_value("audio", "bgm", default_bgm_volume)
	var sfx_val: float    = cfg.get_value("audio", "sfx", default_sfx_volume)
	var voices_val: float = cfg.get_value("audio", "voices", default_voices_volume)
	_minigame_tutorials_enabled = bool(cfg.get_value("gameplay", "minigame_tutorials", true))
	if is_instance_valid(_minigame_tut_btn):
		_sync_toggle_pill(_minigame_tut_btn, _minigame_tutorials_enabled, "On", "Off")
	_slider_master.set_value_no_signal(master_val)
	_slider_bgm.set_value_no_signal(bgm_val)
	_slider_sfx.set_value_no_signal(sfx_val)
	_slider_voices.set_value_no_signal(voices_val)
	_pct_labels["master"].text = "%d%%" % int(roundf(master_val * 100.0))
	_pct_labels["bgm"].text = "%d%%" % int(roundf(bgm_val * 100.0))
	_pct_labels["sfx"].text = "%d%%" % int(roundf(sfx_val * 100.0))
	_pct_labels["voices"].text = "%d%%" % int(roundf(voices_val * 100.0))
	_on_master_changed(master_val)
	_on_bgm_changed(bgm_val)
	_on_sfx_changed(sfx_val)
	_on_voices_changed(voices_val)

	_mute_in_bg = bool(cfg.get_value("accessibility", "mute_in_background", false))
	_colorblind_mode = str(cfg.get_value("accessibility", "colorblind_mode", "off"))
	AccessibilityPaletteScript.set_mode(_colorblind_mode)
	_sync_colorblind_ui()
	if has_node("/root/AudioManager"):
		AudioManager.update_mute_in_background(_mute_in_bg)
	_is_fullscreen = bool(cfg.get_value("display", "fullscreen", true))
	_vsync_enabled = bool(cfg.get_value("display", "vsync", true))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync_enabled else DisplayServer.VSYNC_DISABLED)
	_sync_display_buttons()
