extends CanvasLayer

## Unified top-center toast notification banner routed through TopBannerQueue (FIFO).
## Modernized with Dark Warm Espresso + 4px semantic left accent bar, Fredoka weights,
## tinted Lucide icon medallions, smart queue pacing, and a draining hold timer bar.

const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

const ICON_PACKAGE := "res://Assets/ui/icons/package.png"
const ICON_RADIO := "res://Assets/ui/icons/radio.png"
const ICON_BANKNOTE := "res://Assets/ui/icons/banknote.png"
const ICON_TROPHY := "res://Assets/ui/icons/trophy.png"
const ICON_SPARKLES := "res://Assets/ui/icons/sparkles.png"
const ICON_HEART := "res://Assets/ui/icons/heart-handshake.png"
const ICON_BOOK := "res://Assets/ui/icons/book-bookmark.png"
const ICON_AWARD := "res://Assets/ui/icons/award.png"
const ICON_WIND := "res://Assets/ui/icons/wind.png"

@onready var control: Control = $Control

var _banner: PanelContainer
var _banner_style: StyleBoxFlat
var _icon_medallion: PanelContainer
var _icon_medallion_style: StyleBoxFlat
var _icon_rect: TextureRect
var _sigil_lbl: Label
var _title_lbl: Label
var _msg_lbl: Label
var _queue_pill: PanelContainer
var _queue_lbl: Label
var _timer_bar: TopBannerQueue.BannerTimerBar

var _last_key: String = ""
var _last_enqueue_time: float = 0.0
var _toast_session: int = 0
var _anim_tween: Tween = null
var _timer_tween: Tween = null


func _ready() -> void:
	layer = 100
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
	_banner.custom_minimum_size = Vector2(430, 0)
	_banner_style = TopBannerQueue.create_banner_style(TopBannerQueue.COL_GOLD, 20, 13)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	control.add_child(_banner)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(hbox)

	# Tinted Lucide icon medallion
	_icon_medallion = PanelContainer.new()
	_icon_medallion.custom_minimum_size = Vector2(44, 44)
	_icon_medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_medallion_style = UIStyle.create_flat_stylebox(Color(0.12, 0.10, 0.08, 0.92), 10, 8, 8)
	_icon_medallion_style.border_color = Color(TopBannerQueue.COL_GOLD.r, TopBannerQueue.COL_GOLD.g, TopBannerQueue.COL_GOLD.b, 0.55)
	_icon_medallion_style.set_border_width_all(1)
	_icon_medallion.add_theme_stylebox_override("panel", _icon_medallion_style)
	hbox.add_child(_icon_medallion)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_medallion.add_child(icon_center)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(24, 24)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(_icon_rect)

	_sigil_lbl = Label.new()
	_sigil_lbl.text = "!"
	_sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sigil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sigil_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_sigil_lbl.add_theme_font_size_override("font_size", 24)
	_sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sigil_lbl.visible = false
	icon_center.add_child(_sigil_lbl)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(col)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_title_lbl.add_theme_font_size_override("font_size", 21)
	_title_lbl.add_theme_color_override("font_outline_color", TopBannerQueue.COL_OUTLINE)
	_title_lbl.add_theme_constant_override("outline_size", 3)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title_lbl)

	_msg_lbl = Label.new()
	_msg_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_msg_lbl.add_theme_font_size_override("font_size", 16)
	_msg_lbl.add_theme_color_override("font_color", TopBannerQueue.COL_CREAM_MUTED)
	_msg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_msg_lbl)

	# Compact [+N] queue indicator (visible only when more banners are queued behind this one)
	_queue_pill = PanelContainer.new()
	_queue_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_queue_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var q_st := UIStyle.create_flat_stylebox(Color(0.14, 0.11, 0.085, 0.92), 7, 8, 3)
	q_st.border_color = Color(TopBannerQueue.COL_GOLD.r, TopBannerQueue.COL_GOLD.g, TopBannerQueue.COL_GOLD.b, 0.55)
	q_st.set_border_width_all(1)
	_queue_pill.add_theme_stylebox_override("panel", q_st)
	_queue_pill.visible = false
	hbox.add_child(_queue_pill)

	_queue_lbl = Label.new()
	_queue_lbl.text = "+1"
	_queue_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_queue_lbl.add_theme_font_size_override("font_size", 14)
	_queue_lbl.add_theme_color_override("font_color", TopBannerQueue.COL_CREAM_MUTED)
	_queue_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue_pill.add_child(_queue_lbl)

	_timer_bar = TopBannerQueue.attach_timer_bar(_banner, TopBannerQueue.COL_GOLD)


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
	if sfx_name == "error" or hay.contains("not enough") or hay.contains("cannot") or hay.contains("failed") or hay.contains("warning") or hay.contains("low funds"):
		return {
			"icon_path": "",
			"sigil": "!",
			"accent": Color(0.92, 0.44, 0.40, 1.0),
			"bright": Color(1.0, 0.72, 0.68, 1.0),
		}
	if hay.contains("wind") or hay.contains("fridge door") or hay.contains("gust"):
		return {
			"icon_path": ICON_WIND,
			"sigil": "",
			"accent": Color(0.48, 0.82, 0.98, 1.0),
			"bright": Color(0.76, 0.93, 1.0, 1.0),
		}
	if hay.contains("radio") or hay.contains("radyo") or hay.contains("broadcast") or hay.contains("event"):
		return {
			"icon_path": ICON_RADIO,
			"sigil": "",
			"accent": Color(0.95, 0.66, 0.28, 1.0),
			"bright": Color(1.0, 0.86, 0.54, 1.0),
		}
	if hay.contains("journal") or hay.contains("folklore") or hay.contains("entry") or hay.contains("story"):
		return {
			"icon_path": ICON_BOOK,
			"sigil": "",
			"accent": Color(0.90, 0.74, 0.38, 1.0),
			"bright": Color(1.0, 0.91, 0.64, 1.0),
		}
	if hay.contains("omen") or hay.contains("favor") or hay.contains("blessing") or hay.contains("mayari") or hay.contains("sto. ni"):
		return {
			"icon_path": ICON_SPARKLES,
			"sigil": "",
			"accent": Color(0.56, 0.78, 0.98, 1.0),
			"bright": Color(0.80, 0.92, 1.0, 1.0),
		}
	if hay.contains("record") or hay.contains("minigame") or hay.contains("sipa") or hay.contains("teks") or hay.contains("mosquito") or hay.contains("trophy") or hay.contains("victory"):
		return {
			"icon_path": ICON_TROPHY,
			"sigil": "",
			"accent": Color(0.96, 0.78, 0.34, 1.0),
			"bright": Color(1.0, 0.92, 0.66, 1.0),
		}
	if hay.contains("milestone") or hay.contains("level "):
		return {
			"icon_path": ICON_AWARD,
			"sigil": "",
			"accent": Color(0.96, 0.78, 0.34, 1.0),
			"bright": Color(1.0, 0.92, 0.66, 1.0),
		}
	if hay.contains("reputation") or hay.contains("rep ") or hay.contains("favorite"):
		return {
			"icon_path": ICON_HEART,
			"sigil": "",
			"accent": Color(0.62, 0.88, 0.56, 1.0),
			"bright": Color(0.84, 0.98, 0.78, 1.0),
		}
	if hay.contains("recycl") or hay.contains("refund") or hay.contains("bonus") or hay.contains("wholesale") or hay.contains("peso") or hay.contains("₱"):
		return {
			"icon_path": ICON_BANKNOTE,
			"sigil": "",
			"accent": Color(0.46, 0.86, 0.54, 1.0),
			"bright": Color(0.76, 0.96, 0.80, 1.0),
		}
	if sfx_name == "purchase" or hay.contains("upgrade") or hay.contains("deliver") or hay.contains("unlock") or hay.contains("mounted") or hay.contains("placed") or hay.contains("stocked") or hay.contains("sticker") or hay.contains("signage") or hay.contains("poster"):
		return {
			"icon_path": ICON_PACKAGE,
			"sigil": "",
			"accent": Color(0.46, 0.86, 0.54, 1.0),
			"bright": Color(0.76, 0.96, 0.80, 1.0),
		}
	return {
		"icon_path": ICON_SPARKLES,
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
	var icon_path: String = str(vis["icon_path"])
	var icon_tex: Texture2D = HadesEmblem.load_lucide_icon(icon_path) if icon_path != "" else null

	_banner_style.border_color = Color(accent.r, accent.g, accent.b, 0.88)
	_icon_medallion_style.bg_color = Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.92)
	_icon_medallion_style.border_color = Color(accent.r, accent.g, accent.b, 0.58)
	if is_instance_valid(_timer_bar):
		_timer_bar.bar_color = Color(accent.r, accent.g, accent.b, 0.80)
		_timer_bar.queue_redraw()

	if icon_tex != null:
		_icon_rect.texture = icon_tex
		_icon_rect.modulate = bright
		_icon_rect.visible = true
		_sigil_lbl.visible = false
	else:
		_icon_rect.visible = false
		_sigil_lbl.text = str(vis["sigil"]) if str(vis["sigil"]) != "" else "!"
		_sigil_lbl.add_theme_color_override("font_color", bright)
		_sigil_lbl.visible = true

	_title_lbl.text = title
	_title_lbl.add_theme_color_override("font_color", bright)
	_msg_lbl.text = message
	_msg_lbl.visible = not message.strip_edges().is_empty()

	var pending := TopBannerQueue.get_pending_count()
	_queue_pill.visible = pending > 0
	if pending > 0:
		_queue_lbl.text = "+%d" % pending

	if sfx_name != "":
		AudioManager.play_sfx(sfx_name)

	_animate_in(my_session, pending)


func _animate_in(my_session: int, pending_behind: int) -> void:
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
	var target_y := TopBannerQueue.get_safe_top_y(vp_size.y)
	_banner.position = Vector2((vp_size.x - _banner.size.x) * 0.5, -_banner.size.y - 12.0)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.92, 0.92)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	if _timer_tween and _timer_tween.is_valid():
		_timer_tween.kill()

	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(_banner, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "scale", Vector2(1.02, 1.02), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_banner, "position:y", target_y, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.chain().tween_property(_banner, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Smart queue pacing: compress hold time slightly when more toasts are waiting
	var hold_sec := 1.95 if pending_behind >= 2 else (2.35 if pending_behind == 1 else 2.85)
	_timer_tween = TopBannerQueue.start_timer_bar(self, _timer_bar, hold_sec)

	await get_tree().create_timer(hold_sec).timeout
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
	_anim_tween.tween_property(_banner, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_banner, "position:y", -_banner.size.y - 14.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _anim_tween.finished
	if is_inside_tree() and my_session == _toast_session:
		control.visible = false
	TopBannerQueue.complete()
