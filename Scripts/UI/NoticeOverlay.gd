extends CanvasLayer

## Unified top-center toast notification banner routed through TopBannerQueue (FIFO).
## Uses context-aware icons and accent colors with the shared warm espresso shell.

const ICON_JOURNAL: Texture2D = preload("res://Assets/ui/journal_ui.png")
const ICON_RADIO: Texture2D = preload("res://Assets/ui/Radio.png")
const ICON_PESO: Texture2D = preload("res://Assets/ui/peso_icon.png")
const ICON_TROPHY: Texture2D = preload("res://Assets/ui/trophy.png")
const ICON_STO_NINO: Texture2D = preload("res://Assets/ui/sto_nino2.png")
const ICON_REP: Texture2D = preload("res://Assets/ui/rep.png")

@onready var control: Control = $Control

var _bold_font: FontVariation
var _banner: PanelContainer
var _banner_style: StyleBoxFlat
var _icon_rect: TextureRect
var _sigil_lbl: Label
var _title_lbl: Label
var _msg_lbl: Label

var _last_key: String = ""
var _last_enqueue_time: float = 0.0
var _toast_session: int = 0
var _anim_tween: Tween = null


func _ready() -> void:
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


func _exit_tree() -> void:
	TopBannerQueue.clear()


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.custom_minimum_size = Vector2(400, 0)
	_banner_style = TopBannerQueue.create_banner_style(Color(0.90, 0.74, 0.38, 1.0), 24, 14)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	control.add_child(_banner)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(hbox)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(36, 36)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_icon_rect)

	_sigil_lbl = Label.new()
	_sigil_lbl.text = "!"
	_sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sigil_lbl.custom_minimum_size = Vector2(32, 32)
	_sigil_lbl.add_theme_font_override("font", _bold_font)
	_sigil_lbl.add_theme_font_size_override("font_size", 28)
	_sigil_lbl.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	_sigil_lbl.add_theme_constant_override("outline_size", 4)
	_sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sigil_lbl.visible = false
	hbox.add_child(_sigil_lbl)

	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(col)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", _bold_font)
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 4)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title_lbl)

	_msg_lbl = Label.new()
	_msg_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_msg_lbl.add_theme_font_size_override("font_size", 16)
	_msg_lbl.add_theme_color_override("font_color", TopBannerQueue.COL_CREAM_MUTED)
	_msg_lbl.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	_msg_lbl.add_theme_constant_override("outline_size", 3)
	_msg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_msg_lbl)


func _on_show_notification(title: String, message: String, sfx_name: String = "") -> void:
	var key := "%s|%s" % [title, message]
	var now := Time.get_ticks_msec() / 1000.0
	if key == _last_key and (now - _last_enqueue_time) < 2.0:
		return
	_last_key = key
	_last_enqueue_time = now
	TopBannerQueue.enqueue(_play_toast.bind(title, message, sfx_name))


func _resolve_context_visuals(title: String, message: String, sfx_name: String) -> Dictionary:
	var hay := (title + " " + message).to_lower()
	if sfx_name == "error" or hay.contains("not enough") or hay.contains("cannot") or hay.contains("failed") or hay.contains("warning"):
		return {
			"icon": null,
			"sigil": "!",
			"accent": Color(0.89, 0.50, 0.48, 1.0),
			"bright": Color(0.98, 0.74, 0.72, 1.0),
		}
	if hay.contains("journal") or hay.contains("folklore") or hay.contains("entry") or hay.contains("story"):
		return {
			"icon": ICON_JOURNAL,
			"sigil": "",
			"accent": Color(0.90, 0.74, 0.38, 1.0),
			"bright": Color(1.0, 0.91, 0.64, 1.0),
		}
	if hay.contains("radio") or hay.contains("event") or hay.contains("broadcast") or hay.contains("regular"):
		return {
			"icon": ICON_RADIO,
			"sigil": "",
			"accent": Color(0.94, 0.68, 0.32, 1.0),
			"bright": Color(1.0, 0.86, 0.56, 1.0),
		}
	if hay.contains("omen") or hay.contains("favor") or hay.contains("blessing") or hay.contains("mayari") or hay.contains("sto. ni"):
		return {
			"icon": ICON_STO_NINO,
			"sigil": "",
			"accent": Color(0.56, 0.76, 0.96, 1.0),
			"bright": Color(0.78, 0.90, 1.0, 1.0),
		}
	if hay.contains("record") or hay.contains("minigame") or hay.contains("sipa") or hay.contains("teks") or hay.contains("mosquito") or hay.contains("trophy"):
		return {
			"icon": ICON_TROPHY,
			"sigil": "",
			"accent": Color(0.94, 0.78, 0.36, 1.0),
			"bright": Color(1.0, 0.92, 0.66, 1.0),
		}
	if hay.contains("reputation") or hay.contains("rep ") or hay.contains("favorite"):
		return {
			"icon": ICON_REP,
			"sigil": "",
			"accent": Color(0.62, 0.88, 0.56, 1.0),
			"bright": Color(0.84, 0.98, 0.78, 1.0),
		}
	if sfx_name == "purchase" or hay.contains("upgrade") or hay.contains("deliver") or hay.contains("bonus") or hay.contains("level") or hay.contains("peso") or hay.contains("₱"):
		return {
			"icon": ICON_PESO,
			"sigil": "",
			"accent": Color(0.56, 0.86, 0.62, 1.0),
			"bright": Color(0.80, 0.96, 0.84, 1.0),
		}
	return {
		"icon": ICON_JOURNAL,
		"sigil": "",
		"accent": Color(0.90, 0.74, 0.38, 1.0),
		"bright": Color(1.0, 0.91, 0.64, 1.0),
	}


func _play_toast(title: String, message: String, sfx_name: String) -> void:
	if not is_inside_tree():
		TopBannerQueue.complete()
		return

	_toast_session += 1
	var my_session := _toast_session

	var vis := _resolve_context_visuals(title, message, sfx_name)
	var accent: Color = vis["accent"]
	var bright: Color = vis["bright"]
	var icon_tex: Texture2D = vis["icon"]

	_banner_style.border_color = Color(accent.r, accent.g, accent.b, 0.84)
	if icon_tex != null:
		_icon_rect.texture = icon_tex
		_icon_rect.visible = true
		_sigil_lbl.visible = false
	else:
		_icon_rect.visible = false
		_sigil_lbl.text = str(vis["sigil"])
		_sigil_lbl.add_theme_color_override("font_color", bright)
		_sigil_lbl.visible = true

	_title_lbl.text = title
	_title_lbl.add_theme_color_override("font_color", bright)
	_msg_lbl.text = message
	_msg_lbl.visible = not message.strip_edges().is_empty()

	if sfx_name != "":
		AudioManager.play_sfx(sfx_name)

	_animate_in(my_session)


func _animate_in(my_session: int) -> void:
	layer = 100
	control.visible = true
	_banner.modulate.a = 0.0
	_banner.reset_size()

	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or my_session != _toast_session:
		TopBannerQueue.complete()
		return
	_banner.reset_size()

	var vp_size := get_viewport().get_visible_rect().size
	_banner.position = Vector2((vp_size.x - _banner.size.x) * 0.5, -_banner.size.y - 12.0)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.88, 0.88)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "scale", Vector2(1.03, 1.03), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_banner, "position:y", 24.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.chain().tween_property(_banner, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(2.9).timeout
	if is_inside_tree() and my_session == _toast_session:
		_animate_out(my_session)
	else:
		TopBannerQueue.complete()


func _animate_out(my_session: int) -> void:
	if not control.visible or my_session != _toast_session:
		TopBannerQueue.complete()
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "position:y", -_banner.size.y - 14.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _anim_tween.finished
	if is_inside_tree() and my_session == _toast_session:
		control.visible = false
	TopBannerQueue.complete()
