extends CanvasLayer

## Sleek, minimal rounded-pill toast notification banner for store alerts,
## active lunar omens/favors, and purchase confirmations (no boxes/triangles).

const COL_BG := Color(0.068, 0.058, 0.050, 0.94)
const COL_CREAM := Color(1.0, 0.94, 0.82, 1.0)
const COL_CREAM_MUTED := Color(0.84, 0.78, 0.68, 0.90)
const COL_OUTLINE := Color(0.06, 0.045, 0.03, 0.95)

@onready var control: Control = $Control

var _bold_font: FontVariation
var _banner: PanelContainer
var _banner_style: StyleBoxFlat
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
	_banner.custom_minimum_size = Vector2(320, 0)
	_banner_style = UIStyle.create_flat_stylebox(COL_BG, 14, 22, 11)
	_banner_style.set_border_width_all(1)
	_banner_style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	_banner_style.shadow_size = 16
	_banner_style.shadow_offset = Vector2(0, 6)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	control.add_child(_banner)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(hbox)

	_sigil_lbl = Label.new()
	_sigil_lbl.text = "✦"
	_sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sigil_lbl.add_theme_font_size_override("font_size", 22)
	_sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_sigil_lbl)

	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(col)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 17)
	_title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title_lbl)

	_msg_lbl = Label.new()
	_msg_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_msg_lbl.add_theme_font_size_override("font_size", 13)
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

	var is_err := sfx_name == "error"
	var is_omen := title.to_lower().contains("omen")
	var is_pos := sfx_name == "purchase" or title.to_lower().contains("level") or title.to_lower().contains("upgraded") or title.to_lower().contains("favor")
	var accent: Color
	var accent_bright: Color
	var sigil: String
	if is_err:
		accent = Color(0.89, 0.52, 0.50, 1.0)
		accent_bright = Color(0.98, 0.74, 0.72, 1.0)
		sigil = "!"
	elif is_omen:
		accent = Color(0.52, 0.72, 0.94, 1.0)
		accent_bright = Color(0.76, 0.88, 1.0, 1.0)
		sigil = "☽"
	elif is_pos:
		accent = Color(0.92, 0.78, 0.44, 1.0)
		accent_bright = Color(1.0, 0.92, 0.68, 1.0)
		sigil = "★"
	else:
		accent = Color(0.62, 0.85, 0.70, 1.0)
		accent_bright = Color(0.82, 0.96, 0.86, 1.0)
		sigil = "✦"

	_banner_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
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
	_banner.scale = Vector2(0.92, 0.92)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_banner, "position:y", 24.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(2.6).timeout
	if is_inside_tree() and my_session == _toast_session:
		_animate_out(my_session)

func _animate_out(my_session: int) -> void:
	if not control.visible or my_session != _toast_session:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "position:y", -_banner.size.y - 14.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _anim_tween.finished
	if is_inside_tree() and my_session == _toast_session:
		control.visible = false
