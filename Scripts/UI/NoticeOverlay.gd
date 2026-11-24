extends CanvasLayer

## Hades-inspired toast notification banner for level-ups, store upgrades, and alerts.

const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

const COL_BG := Color(0.065, 0.056, 0.048, 0.96)
const COL_CREAM := Color(1.0, 0.94, 0.82, 1.0)
const COL_CREAM_MUTED := Color(0.84, 0.78, 0.68, 0.92)
const COL_OUTLINE := Color(0.06, 0.045, 0.03, 0.95)

@onready var control: Control = $Control

var _bold_font: FontVariation
var _banner: PanelContainer
var _banner_style: StyleBoxFlat
var _emblem: Control
var _sigil_lbl: Label
var _title_lbl: Label
var _msg_lbl: Label

var _last_message: String = ""
var _last_show_time: float = 0.0
var _toast_session: int = 0
var _anim_tween: Tween = null

func _ready() -> void:
	print("[NoticeOverlay] Ready and listening for notifications...")
	layer = 100
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65

	for child in control.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
	control.visible = false
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_banner()
	EventBus.show_notification.connect(_on_show_notification)

func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.custom_minimum_size = Vector2(380, 74)
	_banner_style = UIStyle.create_flat_stylebox(COL_BG, 8, 16, 10)
	_banner_style.border_width_left = 4
	_banner_style.border_width_top = 1
	_banner_style.border_width_right = 1
	_banner_style.border_width_bottom = 1
	_banner_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_banner_style.shadow_size = 14
	_banner_style.shadow_offset = Vector2(0, 5)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	control.add_child(_banner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(hbox)

	_emblem = HadesEmblem.new()
	_emblem.custom_minimum_size = Vector2(62, 62)
	_emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_emblem)

	_sigil_lbl = Label.new()
	_sigil_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sigil_lbl.text = "✦"
	_sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sigil_lbl.add_theme_font_size_override("font_size", 24)
	_sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.add_child(_sigil_lbl)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(col)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title_lbl)

	_msg_lbl = Label.new()
	_msg_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_msg_lbl.add_theme_font_size_override("font_size", 15)
	_msg_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_msg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_msg_lbl)

func _on_show_notification(title: String, message: String, sfx_name: String = "") -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	if message == _last_message and (current_time - _last_show_time) < 2.0:
		return

	_last_message = message
	_last_show_time = current_time
	_toast_session += 1
	var my_session := _toast_session

	# Style by tone: error = crimson-coral, purchase/level-up = gold, info/chill = light blue
	var is_err := sfx_name == "error"
	var is_pos := sfx_name == "purchase" or title.to_lower().contains("level") or title.to_lower().contains("upgraded")
	var accent: Color
	var accent_bright: Color
	var sigil: String
	if is_err:
		accent = Color(0.88, 0.34, 0.32, 1.0)
		accent_bright = Color(1.0, 0.62, 0.58, 1.0)
		sigil = "!"
	elif is_pos:
		var pal: Dictionary = HadesEmblem.palette("favor")
		accent = pal["accent"]
		accent_bright = pal["bright"]
		sigil = "★"
	else:
		var pal: Dictionary = HadesEmblem.palette("event")
		accent = pal["accent"]
		accent_bright = pal["bright"]
		sigil = "✦"

	_banner_style.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	_emblem.accent = accent
	_emblem.accent_bright = accent_bright
	_emblem.queue_redraw()
	if _emblem.has_method("_sync_triangle_rect"):
		_emblem.call("_sync_triangle_rect")
	_sigil_lbl.text = sigil
	_sigil_lbl.add_theme_color_override("font_color", accent_bright)

	_title_lbl.text = title.to_upper()
	_title_lbl.add_theme_color_override("font_color", accent_bright)
	_msg_lbl.text = message
	_msg_lbl.visible = not message.strip_edges().is_empty()

	if sfx_name != "":
		AudioManager.play_sfx(sfx_name)

	_animate_in(my_session)

func _animate_in(my_session: int) -> void:
	layer = 100
	control.visible = true
	_banner.modulate.a = 0.0
	_banner.size = Vector2.ZERO

	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or my_session != _toast_session:
		return

	var vp_size := get_viewport().get_visible_rect().size
	_banner.position = Vector2((vp_size.x - _banner.size.x) * 0.5, -_banner.size.y - 10.0)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.88, 0.88)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_banner, "position:y", 26.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(2.6).timeout
	if is_inside_tree() and my_session == _toast_session:
		_animate_out(my_session)

func _animate_out(my_session: int) -> void:
	if not control.visible or my_session != _toast_session:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "position:y", -_banner.size.y - 14.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _anim_tween.finished
	if is_inside_tree() and my_session == _toast_session:
		control.visible = false
